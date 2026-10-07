// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {ERC20Upgradeable} from 'src/dependencies/openzeppelin-upgradeable/ERC20Upgradeable.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {ECDSA} from 'src/dependencies/openzeppelin/ECDSA.sol';
import {IERC4626, IERC20Metadata} from 'src/dependencies/openzeppelin/IERC4626.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {EIP712Hash} from 'src/spoke/libraries/EIP712Hash.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {IntentConsumer} from 'src/utils/IntentConsumer.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

/// @title TokenizationSpoke
/// @author Aave Labs
/// @notice ERC4626 compliant wrapper to tokenize one listed asset of the connected Hub.
abstract contract TokenizationSpoke is ITokenizationSpoke, ERC20Upgradeable, IntentConsumer {
  using SafeERC20 for IERC20;
  using EIP712Hash for *;
  using MathUtils for uint256;
  using SafeCast for uint256;

  /// @inheritdoc ITokenizationSpoke
  uint192 public constant PERMIT_NONCE_NAMESPACE = 0;
  /// @inheritdoc ITokenizationSpoke
  bytes32 public constant PERMIT_TYPEHASH = EIP712Hash.PERMIT_TYPEHASH;
  /// @inheritdoc ITokenizationSpoke
  bytes32 public constant DEPOSIT_TYPEHASH = EIP712Hash.TOKENIZED_DEPOSIT_TYPEHASH;
  /// @inheritdoc ITokenizationSpoke
  bytes32 public constant MINT_TYPEHASH = EIP712Hash.TOKENIZED_MINT_TYPEHASH;
  /// @inheritdoc ITokenizationSpoke
  bytes32 public constant WITHDRAW_TYPEHASH = EIP712Hash.TOKENIZED_WITHDRAW_TYPEHASH;
  /// @inheritdoc ITokenizationSpoke
  bytes32 public constant REDEEM_TYPEHASH = EIP712Hash.TOKENIZED_REDEEM_TYPEHASH;

  /// @custom:storage-location erc7201:aave-v4.storage.TokenizationSpoke
  struct TokenizationSpokeStorage {
    address hub;
    uint8 decimals;
    uint40 maxAllowedSpokeCap;
    address asset;
    uint96 assetId;
  }

  /// @dev The storage slot for the TokenizationSpoke storage struct.
  bytes32 private constant NAMESPACE_SLOT =
    // keccak256(abi.encode(uint256(keccak256("aave-v4.storage.TokenizationSpoke")) - 1)) & ~bytes32(uint256(0xff))
    0x245f623a0b50d834ae2ab712581dfcde6f97f1be388fe2ccaeb274dc99041500;

  /// @dev To be overridden by the inheriting TokenizationSpokeInstance contract.
  function initialize(
    address hub_,
    address underlying_,
    string memory shareName,
    string memory shareSymbol
  ) external virtual;

  /// @dev Binds the vault to the Hub asset of `underlying_` and sets the share token's ERC20 name and symbol.
  /// @dev Must be called at every initialization, including upgrades: revision 1 held the Hub binding in immutables.
  function __TokenizationSpoke_init(
    address hub_,
    address underlying_,
    string memory shareName,
    string memory shareSymbol
  ) internal onlyInitializing {
    require(hub_ != address(0), InvalidAddress());
    uint256 assetId_ = IHub(hub_).getAssetId(underlying_); // reverts if invalid
    (address asset_, uint8 decimals_) = IHub(hub_).getAssetUnderlyingAndDecimals(assetId_);

    TokenizationSpokeStorage storage $ = _getTokenizationSpokeStorage();
    $.hub = hub_;
    $.decimals = decimals_;
    $.maxAllowedSpokeCap = IHub(hub_).MAX_ALLOWED_SPOKE_CAP();
    $.asset = asset_;
    $.assetId = assetId_.toUint96();

    emit SetTokenizationSpokeImmutables(hub_, assetId_);

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
    TokenizedDeposit calldata params,
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
    TokenizedMint calldata params,
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
    TokenizedWithdraw calldata params,
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
    TokenizedRedeem calldata params,
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
      IERC20Permit(asset()).permit({
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
  function usePermitNonce() external returns (uint256) {
    return _useNonce({owner: msg.sender, key: PERMIT_NONCE_NAMESPACE});
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
    (IHub hub_, uint256 assetId_) = _hubAndAssetId();
    return hub_.previewAddByAssets(assetId_, assets);
  }

  /// @inheritdoc IERC4626
  function previewMint(uint256 shares) public view virtual returns (uint256) {
    (IHub hub_, uint256 assetId_) = _hubAndAssetId();
    return hub_.previewAddByShares(assetId_, shares);
  }

  /// @inheritdoc IERC4626
  function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
    (IHub hub_, uint256 assetId_) = _hubAndAssetId();
    return hub_.previewRemoveByAssets(assetId_, assets);
  }

  /// @inheritdoc IERC4626
  function previewRedeem(uint256 shares) public view virtual returns (uint256) {
    (IHub hub_, uint256 assetId_) = _hubAndAssetId();
    return hub_.previewRemoveByShares(assetId_, shares);
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
    TokenizationSpokeStorage storage $ = _getTokenizationSpokeStorage();
    IHub.SpokeConfig memory config = IHub($.hub).getSpokeConfig($.assetId, address(this));
    if (!config.active || config.halted) {
      return 0;
    }
    if (config.addCap == $.maxAllowedSpokeCap) {
      return type(uint256).max;
    }
    uint256 allowed = config.addCap * MathUtils.uncheckedExp(10, $.decimals);
    uint256 balance = previewMint(totalSupply());
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
    uint256 assetBalance = convertToAssets(balanceOf(owner));
    return assetBalance.min(maxRemovableAssets);
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
  function MAX_ALLOWED_SPOKE_CAP() public view returns (uint40) {
    return _getTokenizationSpokeStorage().maxAllowedSpokeCap;
  }

  /// @inheritdoc ITokenizationSpoke
  function hub() public view returns (address) {
    return _getTokenizationSpokeStorage().hub;
  }

  /// @inheritdoc ITokenizationSpoke
  function assetId() public view returns (uint256) {
    return _getTokenizationSpokeStorage().assetId;
  }

  /// @inheritdoc IERC4626
  function asset() public view returns (address) {
    return _getTokenizationSpokeStorage().asset;
  }

  /// @inheritdoc IERC20Metadata
  function decimals() public view override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
    return _getTokenizationSpokeStorage().decimals;
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
    uint256 shares = previewDeposit(assets);
    _deposit({caller: depositor, receiver: receiver, assets: assets, shares: shares});
    return shares;
  }

  function _executeMint(
    address depositor,
    address receiver,
    uint256 shares
  ) internal returns (uint256) {
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
    uint256 assets = previewRedeem(shares);
    _withdraw({caller: caller, receiver: receiver, owner: owner, assets: assets, shares: shares});
    return assets;
  }

  /// @dev Deposit/Mint common workflow. Emits {Deposit} event.
  function _deposit(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares
  ) internal virtual {
    _pullAndDepositAssets(caller, assets);
    _mint(receiver, shares);
    _afterDeposit(assets, shares);
    emit Deposit(caller, receiver, assets, shares);
  }

  /// @dev Withdraw/Redeem common workflow. Emits {Withdraw} event.
  /// @dev Consumes share token allowance if `caller` is not `owner`.
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
    _beforeWithdraw(assets, shares);
    _burn(owner, shares);
    _removeAndPushAssets(receiver, assets);
    emit Withdraw(caller, receiver, owner, assets, shares);
  }

  /// @dev Pulls the underlying asset from `from` and deposits it into the Hub.
  /// @dev Added shares in the Hub should match the minted shares in `_deposit`.
  function _pullAndDepositAssets(address from, uint256 amount) internal virtual {
    TokenizationSpokeStorage storage $ = _getTokenizationSpokeStorage();
    IERC20($.asset).safeTransferFrom(from, $.hub, amount);
    IHub($.hub).add($.assetId, amount);
  }

  /// @dev Removes the underlying asset from the Hub and pushes it to `to`.
  /// @dev Removed shares in the Hub should match the burned shares in `_withdraw`.
  function _removeAndPushAssets(address to, uint256 amount) internal virtual {
    (IHub hub_, uint256 assetId_) = _hubAndAssetId();
    hub_.remove(assetId_, amount, to);
  }

  /// @dev Hook that is called after any deposit or mint.
  function _afterDeposit(uint256 assets, uint256 shares) internal virtual {}

  /// @dev Hook that is called before any withdrawal or redemption.
  function _beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}

  function _maxRemovableAssets() internal view returns (uint256) {
    (IHub hub_, uint256 assetId_) = _hubAndAssetId();
    IHub.SpokeConfig memory config = hub_.getSpokeConfig(assetId_, address(this));
    if (!config.active || config.halted) {
      return 0;
    }
    return hub_.getAssetLiquidity(assetId_);
  }

  function _hubAndAssetId() internal view returns (IHub, uint256) {
    TokenizationSpokeStorage storage $ = _getTokenizationSpokeStorage();
    return (IHub($.hub), $.assetId);
  }

  function _getTokenizationSpokeStorage()
    private
    pure
    returns (TokenizationSpokeStorage storage $)
  {
    assembly ('memory-safe') {
      $.slot := NAMESPACE_SLOT
    }
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('Tokenization Spoke', '1');
  }
}
