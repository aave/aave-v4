// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ERC20Upgradeable} from 'src/dependencies/openzeppelin-upgradeable/ERC20Upgradeable.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {IERC4626, IERC20Metadata} from 'src/dependencies/openzeppelin/IERC4626.sol';
import {ECDSA} from 'src/dependencies/openzeppelin/ECDSA.sol';
import {EIP712Hash} from 'src/spoke/libraries/EIP712Hash.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {IntentConsumer} from 'src/utils/IntentConsumer.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

/// @title TokenizationSpoke
/// @author Aave Labs
/// @notice ERC4626 compliant vault for hub's listed asset position management.
/// @dev Connects to one listed asset, only responsible for tokenizing positions.
/// @dev Share price accounting is maintained solely on the Hub.
abstract contract TokenizationSpoke is ITokenizationSpoke, ERC20Upgradeable, IntentConsumer {
  using SafeERC20 for IERC20;
  using MathUtils for uint256;
  using EIP712Hash for *;

  IHub internal immutable HUB;
  uint256 internal immutable ASSET_ID;
  address internal immutable ASSET;
  uint8 internal immutable DECIMALS;
  uint256 internal immutable ASSET_UNITS;

  /// @inheritdoc ITokenizationSpoke
  uint40 public immutable MAX_ALLOWED_SPOKE_CAP;

  /// @inheritdoc ITokenizationSpoke
  uint192 public constant PERMIT_NONCE_NAMESPACE = 0;
  /// @inheritdoc ITokenizationSpoke
  bytes32 public constant PERMIT_TYPEHASH = EIP712Hash.PERMIT_TYPEHASH;
  /// @inheritdoc ITokenizationSpoke
  bytes32 public constant DEPOSIT_TYPEHASH = EIP712Hash.VAULT_DEPOSIT_TYPEHASH;
  /// @inheritdoc ITokenizationSpoke
  bytes32 public constant MINT_TYPEHASH = EIP712Hash.VAULT_MINT_TYPEHASH;
  /// @inheritdoc ITokenizationSpoke
  bytes32 public constant WITHDRAW_TYPEHASH = EIP712Hash.VAULT_WITHDRAW_TYPEHASH;
  /// @inheritdoc ITokenizationSpoke
  bytes32 public constant REDEEM_TYPEHASH = EIP712Hash.VAULT_REDEEM_TYPEHASH;

  constructor(address hub_, uint256 assetId_) {
    require(assetId_ < IHub(hub_).getAssetCount());
    HUB = IHub(hub_);
    ASSET_ID = assetId_;
    (ASSET, DECIMALS) = HUB.getAssetUnderlyingAndDecimals(ASSET_ID);
    ASSET_UNITS = MathUtils.uncheckedExp(10, DECIMALS);
    MAX_ALLOWED_SPOKE_CAP = HUB.MAX_ALLOWED_SPOKE_CAP();
  }

  /// @dev To be overridden by the inheriting TokenizationSpokeInstance contract.
  function initialize(string memory shareName, string memory shareSymbol) external virtual;

  /// @dev Sets the vault share token's ERC20 name and symbol. Must be called at first initialization.
  function __TokenizationSpoke_init(
    string memory shareName,
    string memory shareSymbol
  ) internal onlyInitializing {
    __ERC20_init(shareName, shareSymbol);
  }

  /// @inheritdoc IERC4626
  function deposit(uint256 assets, address receiver) public override returns (uint256) {
    return _executeDeposit({depositor: msg.sender, receiver: receiver, assets: assets});
  }

  /// @inheritdoc IERC4626
  function mint(uint256 shares, address receiver) public override returns (uint256) {
    return _executeMint({depositor: msg.sender, receiver: receiver, shares: shares});
  }

  /// @inheritdoc IERC4626
  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) public override returns (uint256) {
    return _executeWithdraw({caller: msg.sender, receiver: receiver, owner: owner, assets: assets});
  }

  /// @inheritdoc IERC4626
  function redeem(
    uint256 shares,
    address receiver,
    address owner
  ) public override returns (uint256) {
    return _executeRedeem({caller: msg.sender, receiver: receiver, owner: owner, shares: shares});
  }

  /// @inheritdoc ITokenizationSpoke
  function depositWithSig(
    VaultDeposit calldata params,
    bytes calldata signature
  ) external returns (uint256) {
    _verifyAndConsumeIntent({
      signer: params.depositor,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });
    return
      _executeDeposit({
        depositor: params.depositor,
        receiver: params.receiver,
        assets: params.assets
      });
  }

  /// @inheritdoc ITokenizationSpoke
  function mintWithSig(
    VaultMint calldata params,
    bytes calldata signature
  ) external returns (uint256) {
    _verifyAndConsumeIntent({
      signer: params.depositor,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });
    return
      _executeMint({depositor: params.depositor, receiver: params.receiver, shares: params.shares});
  }

  /// @inheritdoc ITokenizationSpoke
  function withdrawWithSig(
    VaultWithdraw calldata params,
    bytes calldata signature
  ) external returns (uint256) {
    _verifyAndConsumeIntent({
      signer: params.owner,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });
    return
      _executeWithdraw({
        caller: params.owner,
        receiver: params.receiver,
        owner: params.owner,
        assets: params.assets
      });
  }

  /// @inheritdoc ITokenizationSpoke
  function redeemWithSig(
    VaultRedeem calldata params,
    bytes calldata signature
  ) external returns (uint256) {
    _verifyAndConsumeIntent({
      signer: params.owner,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });
    return
      _executeRedeem({
        caller: params.owner,
        receiver: params.receiver,
        owner: params.owner,
        shares: params.shares
      });
  }

  /// @inheritdoc ITokenizationSpoke
  function depositWithPermit(
    uint256 assets,
    address receiver,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256) {
    try
      IERC20Permit(ASSET).permit({
        owner: msg.sender,
        spender: address(this),
        value: assets,
        deadline: deadline,
        v: v,
        r: r,
        s: s
      })
    {} catch {}
    return _executeDeposit({depositor: msg.sender, receiver: receiver, assets: assets});
  }

  /// @inheritdoc ITokenizationSpoke
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 digest = _hashTypedData(
      keccak256(
        abi.encode(
          EIP712Hash.PERMIT_TYPEHASH,
          owner,
          spender,
          value,
          _useNonce({owner: owner, key: PERMIT_NONCE_NAMESPACE}),
          deadline
        )
      )
    );
    require(owner == ECDSA.recover({hash: digest, v: v, r: r, s: s}), InvalidSignature());
    _approve({owner: owner, spender: spender, value: value});
  }

  /// @inheritdoc ITokenizationSpoke
  function usePermitNonce(address owner) external returns (uint256) {
    return _useNonce({owner: owner, key: PERMIT_NONCE_NAMESPACE});
  }

  /// @inheritdoc ITokenizationSpoke
  function renounceAllowance(address owner) external override {
    if (allowance({owner: owner, spender: msg.sender}) == 0) {
      return;
    }
    _approve({owner: owner, spender: msg.sender, value: 0});
  }

  /// @inheritdoc IERC4626
  function previewDeposit(uint256 assets) public view virtual returns (uint256) {
    return HUB.previewAddByAssets(ASSET_ID, assets);
  }

  /// @inheritdoc IERC4626
  function previewMint(uint256 shares) public view virtual returns (uint256) {
    return HUB.previewAddByShares(ASSET_ID, shares);
  }

  /// @inheritdoc IERC4626
  function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
    return HUB.previewRemoveByAssets(ASSET_ID, assets);
  }

  /// @inheritdoc IERC4626
  function previewRedeem(uint256 shares) public view virtual returns (uint256) {
    return HUB.previewRemoveByShares(ASSET_ID, shares);
  }

  /// @inheritdoc IERC4626
  function convertToShares(uint256 assets) public view returns (uint256) {
    return previewDeposit(assets);
  }

  /// @inheritdoc IERC4626
  function convertToAssets(uint256 shares) public view returns (uint256) {
    return previewRedeem(shares);
  }

  /// @inheritdoc IERC4626
  function maxDeposit(address) public view returns (uint256) {
    IHub.SpokeConfig memory config = HUB.getSpokeConfig(ASSET_ID, address(this));
    if (!config.active || config.paused) {
      return 0;
    }
    if (config.addCap == MAX_ALLOWED_SPOKE_CAP) {
      return type(uint256).max;
    }
    uint256 allowed = config.addCap * ASSET_UNITS;
    uint256 balance = totalAssets();
    return allowed.zeroFloorSub(balance);
  }

  /// @inheritdoc IERC4626
  function maxMint(address receiver) public view returns (uint256) {
    uint256 maxAssets = maxDeposit(receiver);
    if (maxAssets == type(uint256).max) {
      return type(uint256).max;
    }
    return convertToShares(maxAssets);
  }

  /// @inheritdoc IERC4626
  function maxWithdraw(address owner) public view returns (uint256) {
    uint256 maxRemovableAssets = _maxRemovableAssets();
    uint256 balance = convertToAssets(balanceOf(owner));
    return balance.min(maxRemovableAssets);
  }

  /// @inheritdoc IERC4626
  function maxRedeem(address owner) public view returns (uint256) {
    uint256 maxRemovableShares = convertToShares(_maxRemovableAssets());
    uint256 balance = balanceOf(owner);
    return balance.min(maxRemovableShares);
  }

  /// @inheritdoc IERC4626
  function totalAssets() public view virtual returns (uint256) {
    return previewRedeem(totalSupply());
  }

  /// @inheritdoc ITokenizationSpoke
  function hub() public view returns (address) {
    return address(HUB);
  }

  /// @inheritdoc ITokenizationSpoke
  function assetId() public view returns (uint256) {
    return ASSET_ID;
  }

  /// @inheritdoc IERC4626
  function asset() public view returns (address) {
    return ASSET;
  }

  /// @inheritdoc IERC20Metadata
  function decimals() public view override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
    return DECIMALS;
  }

  /// @inheritdoc IERC20Permit
  function nonces(address owner) public view returns (uint256) {
    return nonces({owner: owner, key: PERMIT_NONCE_NAMESPACE});
  }

  /// @inheritdoc IERC20Permit
  function DOMAIN_SEPARATOR()
    public
    view
    override(ITokenizationSpoke, IntentConsumer)
    returns (bytes32)
  {
    return _domainSeparator();
  }

  function _executeDeposit(
    address depositor,
    address receiver,
    uint256 assets
  ) internal returns (uint256) {
    uint256 maxAssets = maxDeposit(receiver);
    require(assets <= maxAssets, MaxDepositExceeded(maxAssets, assets));
    uint256 shares = previewDeposit(assets);
    _deposit({caller: depositor, receiver: receiver, assets: assets, shares: shares});
    return shares;
  }

  function _executeMint(
    address depositor,
    address receiver,
    uint256 shares
  ) internal returns (uint256) {
    uint256 maxShares = maxMint(receiver);
    require(shares <= maxShares, MaxMintExceeded(maxShares, shares));
    uint256 assets = previewMint(shares);
    _deposit({caller: depositor, receiver: receiver, assets: assets, shares: shares});
    return assets;
  }

  function _executeWithdraw(
    address caller,
    address receiver,
    address owner,
    uint256 assets
  ) internal returns (uint256) {
    uint256 maxAssets = maxWithdraw(owner);
    require(assets <= maxAssets, MaxWithdrawExceeded(maxAssets, assets));
    uint256 shares = previewWithdraw(assets);
    _withdraw({caller: caller, receiver: receiver, owner: owner, assets: assets, shares: shares});
    return shares;
  }

  function _executeRedeem(
    address caller,
    address receiver,
    address owner,
    uint256 shares
  ) internal returns (uint256) {
    uint256 maxShares = maxRedeem(owner);
    require(shares <= maxShares, MaxRedeemExceeded(maxShares, shares));
    uint256 assets = previewRedeem(shares);
    _withdraw({caller: caller, receiver: receiver, owner: owner, assets: assets, shares: shares});
    return assets;
  }

  /// @dev Does not check `hub.add(assets)` returns exactly `shares`; it must be the exact return value of `previewAddByShares` or vice versa for `assets`.
  function _deposit(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares
  ) internal virtual {
    IERC20(ASSET).safeTransferFrom(caller, address(HUB), assets);
    HUB.add(ASSET_ID, assets);
    _mint(receiver, shares);
    emit Deposit({sender: caller, owner: receiver, assets: assets, shares: shares});
  }

  function _withdraw(
    address caller,
    address receiver,
    address owner,
    uint256 assets,
    uint256 shares
  ) internal virtual {
    if (caller != owner) {
      _spendAllowance({owner: owner, spender: caller, value: shares});
    }
    HUB.remove(ASSET_ID, assets, receiver);
    _burn(owner, shares);
    emit Withdraw({
      sender: caller,
      receiver: receiver,
      owner: owner,
      assets: assets,
      shares: shares
    });
  }

  function _maxRemovableAssets() internal view returns (uint256) {
    IHub.SpokeConfig memory config = HUB.getSpokeConfig(ASSET_ID, address(this));
    if (!config.active || config.paused) {
      return 0;
    }
    return HUB.getAssetLiquidity(ASSET_ID);
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('Vault Spoke', '1');
  }
}
