// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ERC20Upgradeable} from 'src/dependencies/openzeppelin-upgradeable/ERC20Upgradeable.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {IERC4626, IERC20Metadata} from 'src/dependencies/openzeppelin/IERC4626.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IVaultSpoke} from 'src/spoke/interfaces/IVaultSpoke.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {EIP712Hash, EIP712Types} from 'src/libraries/EIP712Hash.sol';
import {SignatureChecker, ECDSA} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';

/// @title VaultSpoke
/// @author Aave Labs
/// @notice ERC4626 compliant vault for hub's listed asset position management.
/// @dev Connects to one listed asset, only responsible for tokenizing positions.
/// @dev Share price accounting is maintained solely on the Hub.
abstract contract VaultSpoke is IVaultSpoke, ERC20Upgradeable, NoncesKeyed, EIP712 {
  using SafeERC20 for IERC20;
  using MathUtils for uint256;
  using EIP712Hash for *;

  IHub internal immutable _HUB;
  uint256 internal immutable _ASSET_ID;
  address internal immutable _ASSET;
  uint8 internal immutable _DECIMALS;
  uint40 internal immutable _MAX_ALLOWED_SPOKE_CAP;
  uint192 internal constant _PERMIT_NONCE_KEY = 0;

  constructor(address hub_, uint256 assetId_) {
    _HUB = IHub(hub_);
    _ASSET_ID = assetId_;
    require(_ASSET_ID < _HUB.getAssetCount());
    _MAX_ALLOWED_SPOKE_CAP = _HUB.MAX_ALLOWED_SPOKE_CAP();
    (_ASSET, _DECIMALS) = _HUB.getAssetUnderlyingAndDecimals(_ASSET_ID);
  }

  function initialize(string memory prefix) external virtual;

  function __VaultSpoke_init(string memory prefix) internal onlyInitializing {
    __ERC20_init(
      string.concat(prefix, IERC20Metadata(_ASSET).name()),
      string.concat('s', IERC20Metadata(_ASSET).symbol())
    );
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

  /// @inheritdoc IVaultSpoke
  function depositWithSig(
    EIP712Types.VaultDeposit calldata params,
    bytes calldata signature
  ) public returns (uint256) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    bytes32 digest = _hashTypedData(params.hash());
    require(
      SignatureChecker.isValidSignatureNow(params.depositor, digest, signature),
      InvalidSignature()
    );
    _useCheckedNonce(params.depositor, params.nonce);
    return
      _executeDeposit({
        depositor: params.depositor,
        receiver: params.receiver,
        assets: params.assets
      });
  }

  /// @inheritdoc IVaultSpoke
  function mintWithSig(
    EIP712Types.VaultMint calldata params,
    bytes calldata signature
  ) public returns (uint256) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    bytes32 digest = _hashTypedData(params.hash());
    require(
      SignatureChecker.isValidSignatureNow(params.depositor, digest, signature),
      InvalidSignature()
    );
    _useCheckedNonce(params.depositor, params.nonce);
    return
      _executeMint({depositor: params.depositor, receiver: params.receiver, shares: params.shares});
  }

  /// @inheritdoc IVaultSpoke
  function withdrawWithSig(
    EIP712Types.VaultWithdraw calldata params,
    bytes calldata signature
  ) public returns (uint256) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    bytes32 digest = _hashTypedData(params.hash());
    require(
      SignatureChecker.isValidSignatureNow(params.owner, digest, signature),
      InvalidSignature()
    );
    _useCheckedNonce(params.owner, params.nonce);
    return
      _executeWithdraw({
        caller: msg.sender,
        receiver: params.receiver,
        owner: params.owner,
        assets: params.assets
      });
  }

  /// @inheritdoc IVaultSpoke
  function redeemWithSig(
    EIP712Types.VaultRedeem calldata params,
    bytes memory signature
  ) public returns (uint256) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    bytes32 digest = _hashTypedData(params.hash());
    require(
      SignatureChecker.isValidSignatureNow(params.owner, digest, signature),
      InvalidSignature()
    );
    _useCheckedNonce(params.owner, params.nonce);
    return
      _executeRedeem({
        caller: msg.sender,
        receiver: params.receiver,
        owner: params.owner,
        shares: params.shares
      });
  }

  /// @inheritdoc IVaultSpoke
  function depositWithPermit(
    uint256 assets,
    address receiver,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256) {
    try
      IERC20Permit(asset()).permit({
        owner: msg.sender, // deposit only mints for caller
        spender: address(this),
        value: assets,
        deadline: deadline,
        v: v,
        r: r,
        s: s
      })
    {} catch {}
    return deposit(assets, receiver);
  }

  /// @inheritdoc IERC20Permit
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
          _useNonce({owner: owner, key: _PERMIT_NONCE_KEY}),
          deadline
        )
      )
    );
    require(owner == ECDSA.recover({hash: digest, v: v, r: r, s: s}), InvalidSignature());
    _approve({owner: owner, spender: spender, value: value});
  }

  /// @inheritdoc IERC4626
  function previewDeposit(uint256 assets) public view virtual returns (uint256) {
    return hub().previewAddByAssets(assetId(), assets);
  }

  /// @inheritdoc IERC4626
  function previewMint(uint256 shares) public view virtual returns (uint256) {
    return hub().previewAddByShares(assetId(), shares);
  }

  /// @inheritdoc IERC4626
  function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
    return hub().previewRemoveByAssets(assetId(), assets);
  }

  /// @inheritdoc IERC4626
  function previewRedeem(uint256 shares) public view virtual returns (uint256) {
    return hub().previewRemoveByShares(assetId(), shares);
  }

  /// @inheritdoc IERC4626
  function convertToShares(uint256 assets) public view returns (uint256) {
    return previewDeposit(assets);
  }

  /// @inheritdoc IERC4626
  function convertToAssets(uint256 shares) public view returns (uint256) {
    return previewMint(shares);
  }

  /// @inheritdoc IERC4626
  function maxDeposit(address) public view returns (uint256) {
    IHub.SpokeConfig memory config = hub().getSpokeConfig(assetId(), address(this));
    if (!config.active || config.paused) {
      return 0;
    }
    if (config.addCap == _MAX_ALLOWED_SPOKE_CAP) {
      return type(uint256).max;
    }
    uint256 allowed = config.addCap * MathUtils.uncheckedExp(10, decimals());
    uint256 balance = totalAssets();
    return allowed.zeroFloorSub(balance);
  }

  /// @inheritdoc IERC4626
  function maxMint(address owner) public view returns (uint256) {
    uint256 maxAssets = maxDeposit(owner);
    return maxAssets == type(uint256).max ? type(uint256).max : previewDeposit(maxAssets);
  }

  /// @inheritdoc IERC4626
  function maxWithdraw(address owner) public view returns (uint256) {
    return previewRedeem(maxRedeem(owner));
  }

  /// @inheritdoc IERC4626
  function maxRedeem(address owner) public view returns (uint256) {
    IHub.SpokeConfig memory config = hub().getSpokeConfig(assetId(), address(this));
    if (!config.active || config.paused) {
      return 0;
    }
    return balanceOf(owner);
  }

  /// @inheritdoc IERC4626
  function totalAssets() public view virtual returns (uint256) {
    return previewRedeem(totalSupply());
  }

  /// @inheritdoc IVaultSpoke
  function hub() public view returns (IHub) {
    return _HUB;
  }

  /// @inheritdoc IVaultSpoke
  function assetId() public view returns (uint256) {
    return _ASSET_ID;
  }

  /// @inheritdoc IERC4626
  function asset() public view returns (address) {
    return _ASSET;
  }

  /// @inheritdoc IERC20Metadata
  function decimals() public view override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
    return _DECIMALS;
  }

  /// @inheritdoc IERC20Permit
  function DOMAIN_SEPARATOR() public view returns (bytes32) {
    return _domainSeparator();
  }

  /// @inheritdoc IERC20Permit
  function nonces(address owner) public view returns (uint256) {
    return nonces({owner: owner, key: _PERMIT_NONCE_KEY});
  }

  function _executeDeposit(
    address depositor,
    address receiver,
    uint256 assets
  ) internal returns (uint256) {
    uint256 maxAssets = maxDeposit(receiver);
    require(assets <= maxAssets, MaxDepositExceeded(maxAssets, assets));
    uint256 shares = previewDeposit(assets);
    _deposit(depositor, receiver, assets, shares);
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
    _deposit(depositor, receiver, assets, shares);
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
    _withdraw(caller, receiver, owner, assets, shares);
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
    _withdraw(caller, receiver, owner, assets, shares);
    return assets;
  }

  function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal {
    IERC20(asset()).safeTransferFrom(caller, address(hub()), assets);
    hub().add(assetId(), assets);
    _mint(receiver, shares);
    emit Deposit(caller, receiver, assets, shares);
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
    hub().remove(assetId(), assets, receiver);
    _burn(owner, shares);
    emit Withdraw(caller, receiver, owner, assets, shares);
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('Vault Spoke', '1');
  }
}
