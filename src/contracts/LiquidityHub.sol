// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {IAssetInterestRateStrategy} from 'src/interfaces/IAssetInterestRateStrategy.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {AssetLogic} from 'src/libraries/logic/AssetLogic.sol';
import {WadRayMathExtended} from 'src/libraries/math/WadRayMathExtended.sol';
import {SharesMath} from 'src/libraries/math/SharesMath.sol';
import {PercentageMathExtended} from 'src/libraries/math/PercentageMathExtended.sol';

// @dev Amounts are `asset` denominated by default unless specified otherwise with `share` suffix
contract LiquidityHub is ILiquidityHub, AccessManaged {
  using SafeERC20 for IERC20;
  using WadRayMathExtended for uint256;
  using SharesMath for uint256;
  using PercentageMathExtended for uint256;
  using AssetLogic for DataTypes.Asset;

  uint8 public constant MAX_ALLOWED_ASSET_DECIMALS = 18;

  uint256 internal _assetCount;
  mapping(uint256 assetId => DataTypes.Asset assetData) internal _assets;
  mapping(uint256 assetId => mapping(address spokeAddress => DataTypes.SpokeData spokeData))
    internal _spokes;

  /**
   * @dev Constructor.
   * @dev The authority contract must implement the AccessManaged interface for access control.
   * @param authority_ The address of the authority contract which manages permissions.
   */
  constructor(address authority_) AccessManaged(authority_) {
    // Intentionally left blank
  }

  /// @inheritdoc ILiquidityHub
  function addAsset(
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address irStrategy
  ) external restricted returns (uint256) {
    require(underlying != address(0), InvalidUnderlying());
    require(decimals <= MAX_ALLOWED_ASSET_DECIMALS, InvalidAssetDecimals());
    require(feeReceiver != address(0), InvalidFeeReceiver());
    require(irStrategy != address(0), InvalidIrStrategy());

    uint256 assetId = _assetCount++;
    DataTypes.AssetConfig memory config = DataTypes.AssetConfig({
      active: true,
      paused: false,
      frozen: false,
      feeReceiver: feeReceiver,
      liquidityFee: 0,
      irStrategy: irStrategy
    });

    _assets[assetId] = DataTypes.Asset({
      underlying: underlying,
      decimals: decimals,
      suppliedShares: 0,
      availableLiquidity: 0,
      baseDrawnShares: 0,
      premiumDrawnShares: 0,
      premiumOffset: 0,
      realizedPremium: 0,
      baseDebtIndex: WadRayMathExtended.RAY,
      baseBorrowRate: 0,
      lastUpdateTimestamp: block.timestamp,
      config: config
    });

    emit AssetAdded(assetId, underlying, decimals);
    emit AssetConfigUpdated(assetId, config);

    return assetId;
  }

  /// @inheritdoc ILiquidityHub
  function updateAssetConfig(
    uint256 assetId,
    DataTypes.AssetConfig calldata config
  ) external restricted {
    require(assetId < _assetCount, AssetNotListed());
    require(config.liquidityFee <= PercentageMathExtended.PERCENTAGE_FACTOR, InvalidLiquidityFee());
    require(config.feeReceiver != address(0), InvalidFeeReceiver());
    require(config.irStrategy != address(0), InvalidIrStrategy());

    DataTypes.Asset storage asset = _assets[assetId];
    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);

    asset.config = config;
    asset.updateBorrowRate({assetId: assetId, liquidityAdded: 0, liquidityTaken: 0});

    emit AssetConfigUpdated(assetId, config);
  }

  function addSpoke(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig calldata config
  ) external restricted {
    require(assetId < _assetCount, AssetNotListed());
    require(spoke != address(0), InvalidSpoke()); // todo: how to remove spoke

    _spokes[assetId][spoke] = DataTypes.SpokeData({
      suppliedShares: 0,
      baseDrawnShares: 0,
      premiumDrawnShares: 0,
      premiumOffset: 0,
      realizedPremium: 0,
      lastUpdateTimestamp: block.timestamp,
      config: config
    });

    emit SpokeAdded(assetId, spoke);
    emit SpokeConfigUpdated(assetId, spoke, config);
  }

  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig calldata config
  ) external restricted {
    require(_spokes[assetId][spoke].lastUpdateTimestamp != 0, SpokeNotListed());

    _spokes[assetId][spoke].config = config;
    emit SpokeConfigUpdated(assetId, spoke, config);
  }

  /// @inheritdoc ILiquidityHub
  function setInterestRateData(uint256 assetId, bytes calldata data) external restricted {
    DataTypes.Asset storage asset = _assets[assetId];
    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    IAssetInterestRateStrategy(asset.config.irStrategy).setInterestRateData(assetId, data);
  }

  // /////
  // Spoke Actions
  // /////

  /// @inheritdoc ILiquidityHub
  function add(uint256 assetId, uint256 amount, address from) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    _validateSupply(asset, spoke, amount, from);

    asset.updateBorrowRate({assetId: assetId, liquidityAdded: amount, liquidityTaken: 0});

    // todo: Mitigate inflation attack
    uint256 suppliedShares = asset.toSuppliedSharesDown(amount);
    require(suppliedShares != 0, InvalidSharesAmount());

    asset.availableLiquidity += amount;
    asset.suppliedShares += suppliedShares;

    spoke.suppliedShares += suppliedShares;

    // TODO: fee-on-transfer
    IERC20(asset.underlying).safeTransferFrom(from, address(this), amount);

    emit Add(assetId, msg.sender, suppliedShares, amount);

    return suppliedShares;
  }

  /// @inheritdoc ILiquidityHub
  function remove(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    _validateWithdraw(asset, spoke, amount);

    asset.updateBorrowRate({assetId: assetId, liquidityAdded: 0, liquidityTaken: amount});

    uint256 withdrawnShares = asset.toSuppliedSharesUp(amount); // non zero since we round up

    asset.availableLiquidity -= amount;
    asset.suppliedShares -= withdrawnShares;

    spoke.suppliedShares -= withdrawnShares;

    IERC20(asset.underlying).safeTransfer(to, amount);

    emit Remove(assetId, msg.sender, withdrawnShares, amount);

    return withdrawnShares;
  }

  /// @inheritdoc ILiquidityHub
  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    _validateDraw(asset, spoke, amount, spoke.config.drawCap);

    asset.updateBorrowRate({assetId: assetId, liquidityAdded: 0, liquidityTaken: amount});

    uint256 drawnShares = asset.toDrawnSharesUp(amount); // non zero since we round up

    asset.availableLiquidity -= amount;
    asset.baseDrawnShares += drawnShares;

    spoke.baseDrawnShares += drawnShares;

    IERC20(asset.underlying).safeTransfer(to, amount);

    emit Draw(assetId, msg.sender, drawnShares, amount);

    return drawnShares;
  }

  /// @inheritdoc ILiquidityHub
  function restore(
    uint256 assetId,
    uint256 baseAmount,
    uint256 premiumAmount,
    address from
  ) external returns (uint256) {
    // global & spoke premiumDebt (ghost, offset, realized) is *expected* to be updated on the `refreshPremiumDebt` callback

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);

    _validateRestore(asset, spoke, baseAmount, premiumAmount);
    asset.updateBorrowRate({assetId: assetId, liquidityAdded: baseAmount, liquidityTaken: 0}); // both can be zero

    uint256 totalRestoredAmount = baseAmount + premiumAmount;
    uint256 baseDrawnSharesRestored = asset.toDrawnSharesDown(baseAmount);

    asset.availableLiquidity += totalRestoredAmount;
    asset.baseDrawnShares -= baseDrawnSharesRestored;

    spoke.baseDrawnShares -= baseDrawnSharesRestored;

    IERC20(asset.underlying).safeTransferFrom(from, address(this), totalRestoredAmount);

    emit Restore(assetId, msg.sender, baseDrawnSharesRestored, totalRestoredAmount);

    return baseDrawnSharesRestored;
  }

  /// @inheritdoc ILiquidityHub
  function refreshPremiumDebt(
    uint256 assetId,
    int256 premiumDrawnShareDelta,
    int256 premiumOffsetDelta,
    uint256 realizedPremiumAdded,
    uint256 realizedPremiumTaken
  ) external {
    require(_spokes[assetId][msg.sender].config.active, SpokeNotActive());

    DataTypes.Asset storage asset = _assets[assetId];

    uint256 premiumDebtBefore = asset.premiumDebt();
    _refresh(
      assetId,
      msg.sender,
      premiumDrawnShareDelta,
      premiumOffsetDelta,
      realizedPremiumAdded,
      realizedPremiumTaken
    );
    uint256 premiumDebtAfter = asset.premiumDebt();
    // can increase due to precision loss on premium debt (base unchanged)
    // todo mathematically find premium diff ceiling and replace the `2`
    // if no premium debt is restored, premium debt remains unchanged
    require(premiumDebtAfter + realizedPremiumTaken - premiumDebtBefore <= 2, InvalidDebtChange());
  }

  /// @inheritdoc ILiquidityHub
  function payFee(uint256 assetId, uint256 feeShares) external {
    DataTypes.SpokeData storage sender = _spokes[assetId][msg.sender];
    _validatePayFee(sender, feeShares);

    address feeReceiver = _assets[assetId].config.feeReceiver;
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage receiver = _spokes[assetId][feeReceiver];

    asset.accrue(assetId, receiver);

    uint256 suppliedShares = sender.suppliedShares;
    uint256 suppliedAssets = asset.toSuppliedAssetsDown(suppliedShares);
    uint256 feeAmount = asset.toSuppliedAssetsDown(feeShares);
    require(feeAmount <= suppliedAssets, SuppliedAmountExceeded(suppliedAssets));

    sender.suppliedShares = suppliedShares - feeShares;
    receiver.suppliedShares += feeShares;

    emit Remove(assetId, msg.sender, feeShares, feeAmount);
    emit Add(assetId, feeReceiver, feeShares, feeAmount);
  }

  function _refresh(
    uint256 assetId,
    address spokeAddress,
    int256 premiumDrawnShareDelta,
    int256 premiumOffsetDelta,
    uint256 realizedPremiumAdded,
    uint256 realizedPremiumTaken
  ) internal {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][spokeAddress];

    // accrue interest and liquidity fees
    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);

    asset.premiumDrawnShares = _add(asset.premiumDrawnShares, premiumDrawnShareDelta);
    asset.premiumOffset = _add(asset.premiumOffset, premiumOffsetDelta);
    asset.realizedPremium = asset.realizedPremium + realizedPremiumAdded - realizedPremiumTaken;

    spoke.premiumDrawnShares = _add(spoke.premiumDrawnShares, premiumDrawnShareDelta);
    spoke.premiumOffset = _add(spoke.premiumOffset, premiumOffsetDelta);
    spoke.realizedPremium = spoke.realizedPremium + realizedPremiumAdded - realizedPremiumTaken;

    emit RefreshPremiumDebt(
      assetId,
      spokeAddress,
      premiumDrawnShareDelta,
      premiumOffsetDelta,
      realizedPremiumAdded,
      realizedPremiumTaken
    );
  }

  //
  // public
  //

  function getAssetCount() external view override returns (uint256) {
    return _assetCount;
  }

  function getAsset(uint256 assetId) external view returns (DataTypes.Asset memory) {
    return _assets[assetId];
  }

  function getSpoke(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeData memory) {
    return _spokes[assetId][spoke];
  }

  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeConfig memory) {
    return _spokes[assetId][spoke].config;
  }

  // todo 4626 getter naming
  function convertToSuppliedAssets(
    uint256 assetId,
    uint256 shares
  ) external view returns (uint256) {
    return _assets[assetId].toSuppliedAssetsDown(shares);
  }

  function convertToSuppliedAssetsUp(
    uint256 assetId,
    uint256 shares
  ) external view returns (uint256) {
    return _assets[assetId].toSuppliedAssetsUp(shares);
  }

  function convertToSuppliedShares(
    uint256 assetId,
    uint256 assets
  ) external view returns (uint256) {
    return _assets[assetId].toSuppliedSharesDown(assets);
  }

  function convertToSuppliedSharesUp(
    uint256 assetId,
    uint256 assets
  ) external view returns (uint256) {
    return _assets[assetId].toSuppliedSharesUp(assets);
  }

  function convertToDrawnAssets(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toDrawnAssetsUp(shares);
  }

  function convertToDrawnShares(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].toDrawnSharesDown(assets);
  }

  function previewOffset(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toDrawnAssetsDown(shares);
  }

  function previewDrawnIndex(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].previewDrawnIndex();
  }

  function getBaseInterestRate(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].baseBorrowRate;
  }

  function getAssetDebt(uint256 assetId) external view returns (uint256, uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    return (asset.baseDebt(), asset.premiumDebt());
  }

  function getAssetTotalDebt(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].totalDebt();
  }

  function getSpokeDebt(uint256 assetId, address spoke) external view returns (uint256, uint256) {
    return _getSpokeDebt(_assets[assetId], _spokes[assetId][spoke]);
  }

  function getSpokeTotalDebt(uint256 assetId, address spoke) external view returns (uint256) {
    (uint256 baseDebt, uint256 premiumDebt) = _getSpokeDebt(
      _assets[assetId],
      _spokes[assetId][spoke]
    );
    return baseDebt + premiumDebt;
  }

  function getAssetSuppliedAmount(uint256 assetId) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    return asset.toSuppliedAssetsDown(asset.suppliedShares);
  }

  function getAssetSuppliedShares(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].suppliedShares;
  }

  function getTotalSuppliedAssets(uint256 assetId) external view override returns (uint256) {
    return _assets[assetId].totalSuppliedAssets();
  }

  function getTotalSuppliedShares(uint256 assetId) external view override returns (uint256) {
    return _assets[assetId].totalSuppliedShares();
  }

  function getSpokeSuppliedAmount(uint256 assetId, address spoke) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    if (spoke == asset.config.feeReceiver) {
      return
        asset.toSuppliedAssetsDown(
          _spokes[assetId][spoke].suppliedShares + asset.unrealizedFeeShares()
        );
    }
    return asset.toSuppliedAssetsDown(_spokes[assetId][spoke].suppliedShares);
  }

  function getSpokeSuppliedShares(uint256 assetId, address spoke) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    if (spoke == asset.config.feeReceiver) {
      return _spokes[assetId][spoke].suppliedShares + asset.unrealizedFeeShares();
    }
    return _spokes[assetId][spoke].suppliedShares;
  }

  function getAvailableLiquidity(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].availableLiquidity;
  }

  function getAssetConfig(uint256 assetId) external view returns (DataTypes.AssetConfig memory) {
    return _assets[assetId].config;
  }

  //
  // Internal
  //

  function _validateSupply(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount,
    address from
  ) internal view {
    require(spoke.config.active, SpokeNotActive());
    require(amount != 0, InvalidSupplyAmount());
    require(from != address(this), InvalidAddFromHub());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    require(!asset.config.frozen, AssetFrozen());
    require(
      spoke.config.supplyCap == type(uint256).max ||
        asset.toSuppliedAssetsUp(spoke.suppliedShares) + amount <= spoke.config.supplyCap,
      SupplyCapExceeded(spoke.config.supplyCap)
    );
  }

  function _validateWithdraw(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount
  ) internal view {
    require(spoke.config.active, SpokeNotActive());
    require(amount != 0, InvalidWithdrawAmount());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    uint256 withdrawable = asset.toSuppliedAssetsDown(spoke.suppliedShares);
    require(amount <= withdrawable, SuppliedAmountExceeded(withdrawable));
    require(amount <= asset.availableLiquidity, NotAvailableLiquidity(asset.availableLiquidity));
  }

  function _validateDraw(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount,
    uint256 drawCap
  ) internal view {
    require(spoke.config.active, SpokeNotActive());
    require(amount > 0, InvalidDrawAmount());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    require(!asset.config.frozen, AssetFrozen());
    require(
      drawCap == type(uint256).max || amount + asset.totalDebt() <= drawCap,
      DrawCapExceeded(drawCap)
    );
    require(amount <= asset.availableLiquidity, NotAvailableLiquidity(asset.availableLiquidity));
  }

  function _validateRestore(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 baseAmountRestored,
    uint256 premiumAmountRestored
  ) internal view {
    require(spoke.config.active, SpokeNotActive());
    require(baseAmountRestored + premiumAmountRestored != 0, InvalidRestoreAmount());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    (uint256 baseDebt, ) = _getSpokeDebt(asset, spoke);
    require(baseAmountRestored <= baseDebt, SurplusAmountRestored(baseDebt));
    // we should have already restored premium debt
  }

  function _getSpokeDebt(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke
  ) internal view returns (uint256, uint256) {
    // sanity: utilize solc underflow check
    uint256 accruedPremium = asset.toDrawnAssetsUp(spoke.premiumDrawnShares) - spoke.premiumOffset;
    return (asset.toDrawnAssetsUp(spoke.baseDrawnShares), spoke.realizedPremium + accruedPremium);
  }

  // handles underflow
  function _add(uint256 a, int256 b) internal pure returns (uint256) {
    if (b >= 0) return a + uint256(b);
    return a - uint256(-b);
  }

  function _validatePayFee(DataTypes.SpokeData storage spoke, uint256 feeShares) internal view {
    // TODO: validate valid asset
    require(spoke.config.active, SpokeNotActive());
    require(feeShares != 0, InvalidFeeShares());
  }
}
