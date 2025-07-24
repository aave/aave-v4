// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';

// libraries
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {AssetLogic} from 'src/libraries/logic/AssetLogic.sol';
import {WadRayMathExtended} from 'src/libraries/math/WadRayMathExtended.sol';
import {SharesMath} from 'src/libraries/math/SharesMath.sol';
import {PercentageMathExtended} from 'src/libraries/math/PercentageMathExtended.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';

// interfaces
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {IAssetInterestRateStrategy} from 'src/interfaces/IAssetInterestRateStrategy.sol';

// @dev Amounts are `asset` denominated by default unless specified otherwise with `share` suffix
contract LiquidityHub is ILiquidityHub, AccessManaged {
  using SafeERC20 for IERC20;
  using WadRayMathExtended for uint256;
  using SharesMath for uint256;
  using PercentageMathExtended for uint256;
  using AssetLogic for DataTypes.Asset;
  using MathUtils for uint256;

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
    address irStrategy,
    bytes calldata data
  ) external restricted returns (uint256) {
    require(underlying != address(0), InvalidUnderlying());
    require(decimals <= MAX_ALLOWED_ASSET_DECIMALS, InvalidAssetDecimals());
    require(feeReceiver != address(0), InvalidFeeReceiver());
    require(irStrategy != address(0), InvalidIrStrategy());

    uint256 assetId = _assetCount++;
    IAssetInterestRateStrategy(irStrategy).setInterestRateData(assetId, data);
    uint256 baseDrawnRate = IAssetInterestRateStrategy(irStrategy).calculateInterestRate({
      assetId: assetId,
      availableLiquidity: 0,
      baseDebt: 0,
      premiumDebt: 0
    });

    uint256 baseDrawnIndex = WadRayMathExtended.RAY;
    uint256 lastUpdateTimestamp = block.timestamp;
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
      addedShares: 0,
      availableLiquidity: 0,
      baseDrawnShares: 0,
      premiumDrawnShares: 0,
      premiumOffset: 0,
      realizedPremium: 0,
      baseDrawnIndex: baseDrawnIndex,
      baseDrawnRate: baseDrawnRate,
      lastUpdateTimestamp: lastUpdateTimestamp,
      config: config
    });

    emit AssetAdded(assetId, underlying, decimals);
    emit AssetConfigUpdated(assetId, config);
    emit AssetUpdated(assetId, baseDrawnIndex, baseDrawnRate, lastUpdateTimestamp);

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
    asset.updateBorrowRate(assetId);

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
      addedShares: 0,
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
    _validateAdd(asset, spoke, amount, from);

    // todo: Mitigate inflation attack
    uint256 shares = asset.toAddedSharesDown(amount);
    require(shares != 0, InvalidSharesAmount());
    asset.addedShares += shares;
    spoke.addedShares += shares;
    asset.availableLiquidity += amount;

    asset.updateBorrowRate(assetId);

    // TODO: fee-on-transfer
    IERC20(asset.underlying).safeTransferFrom(from, address(this), amount);

    emit Add(assetId, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc ILiquidityHub
  function remove(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    _validateRemove(asset, spoke, amount);

    uint256 shares = asset.toAddedSharesUp(amount); // non zero since we round up
    asset.addedShares -= shares;
    spoke.addedShares -= shares;
    asset.availableLiquidity -= amount;

    asset.updateBorrowRate(assetId);

    IERC20(asset.underlying).safeTransfer(to, amount);

    emit Remove(assetId, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc ILiquidityHub
  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    _validateDraw(asset, spoke, amount, spoke.config.drawCap);

    uint256 shares = asset.toDrawnSharesUp(amount); // non zero since we round up
    asset.baseDrawnShares += shares;
    spoke.baseDrawnShares += shares;
    asset.availableLiquidity -= amount;

    asset.updateBorrowRate(assetId);

    IERC20(asset.underlying).safeTransfer(to, amount);

    emit Draw(assetId, msg.sender, shares, amount);

    return shares;
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

    uint256 shares = asset.toDrawnSharesDown(baseAmount);
    asset.baseDrawnShares -= shares;
    spoke.baseDrawnShares -= shares;
    uint256 totalAmount = baseAmount + premiumAmount;
    asset.availableLiquidity += totalAmount;

    /// @dev premium debt must be restored in `refreshPremiumDebt` before calling this function
    asset.updateBorrowRate(assetId);

    IERC20(asset.underlying).safeTransferFrom(from, address(this), totalAmount);

    emit Restore(assetId, msg.sender, shares, totalAmount);

    return shares;
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
  function payFee(uint256 assetId, uint256 shares) external {
    DataTypes.SpokeData storage sender = _spokes[assetId][msg.sender];
    _validatePayFee(sender, shares);

    address feeReceiver = _assets[assetId].config.feeReceiver;
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage receiver = _spokes[assetId][feeReceiver];

    asset.accrue(assetId, receiver);

    uint256 addedShares = sender.addedShares;
    uint256 suppliedAssets = asset.toAddedAssetsDown(addedShares);
    uint256 feeAmount = asset.toAddedAssetsDown(shares);
    require(feeAmount <= suppliedAssets, AddedAmountExceeded(suppliedAssets));

    sender.addedShares = addedShares - shares;
    receiver.addedShares += shares;

    emit Remove(assetId, msg.sender, shares, feeAmount);
    emit Add(assetId, feeReceiver, shares, feeAmount);
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

    asset.premiumDrawnShares = asset.premiumDrawnShares.add(premiumDrawnShareDelta);
    asset.premiumOffset = asset.premiumOffset.add(premiumOffsetDelta);
    asset.realizedPremium = asset.realizedPremium + realizedPremiumAdded - realizedPremiumTaken;

    spoke.premiumDrawnShares = spoke.premiumDrawnShares.add(premiumDrawnShareDelta);
    spoke.premiumOffset = spoke.premiumOffset.add(premiumOffsetDelta);
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
  function convertToAddedAssets(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toAddedAssetsDown(shares);
  }

  function convertToAddedAssetsUp(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toAddedAssetsUp(shares);
  }

  function convertToAddedShares(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].toAddedSharesDown(assets);
  }

  function convertToAddedSharesUp(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].toAddedSharesUp(assets);
  }

  function convertToDrawnAssets(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toDrawnAssetsUp(shares);
  }

  function convertToDrawnShares(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].toDrawnSharesDown(assets);
  }

  function convertToDrawnSharesUp(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].toDrawnSharesUp(assets);
  }

  function previewOffset(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toDrawnAssetsDown(shares);
  }

  function previewDrawnIndex(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].previewDrawnIndex();
  }

  function getBaseInterestRate(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].baseDrawnRate;
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

  function getAssetAddedAmount(uint256 assetId) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    return asset.toAddedAssetsDown(asset.addedShares);
  }

  function getAssetAddedShares(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].addedShares;
  }

  function getTotalAddedAssets(uint256 assetId) external view override returns (uint256) {
    return _assets[assetId].totalAddedAssets();
  }

  function getTotalAddedShares(uint256 assetId) external view override returns (uint256) {
    return _assets[assetId].totalAddedShares();
  }

  function getSpokeAddedAmount(uint256 assetId, address spoke) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    if (spoke == asset.config.feeReceiver) {
      return
        asset.toAddedAssetsDown(_spokes[assetId][spoke].addedShares + asset.unrealizedFeeShares());
    }
    return asset.toAddedAssetsDown(_spokes[assetId][spoke].addedShares);
  }

  function getSpokeAddedShares(uint256 assetId, address spoke) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    if (spoke == asset.config.feeReceiver) {
      return _spokes[assetId][spoke].addedShares + asset.unrealizedFeeShares();
    }
    return _spokes[assetId][spoke].addedShares;
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

  function _validateAdd(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount,
    address from
  ) internal view {
    require(spoke.config.active, SpokeNotActive());
    require(amount != 0, InvalidAddAmount());
    require(from != address(this), InvalidAddFromHub());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    require(!asset.config.frozen, AssetFrozen());
    require(
      spoke.config.addCap == type(uint256).max ||
        asset.toAddedAssetsUp(spoke.addedShares) + amount <= spoke.config.addCap,
      AddCapExceeded(spoke.config.addCap)
    );
  }

  function _validateRemove(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount
  ) internal view {
    require(spoke.config.active, SpokeNotActive());
    require(amount != 0, InvalidRemoveAmount());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    uint256 withdrawable = asset.toAddedAssetsDown(spoke.addedShares);
    require(amount <= withdrawable, AddedAmountExceeded(withdrawable));
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
    uint256 baseAmount,
    uint256 premiumAmount
  ) internal view {
    require(spoke.config.active, SpokeNotActive());
    require(baseAmount + premiumAmount != 0, InvalidRestoreAmount());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    (uint256 baseDebt, ) = _getSpokeDebt(asset, spoke);
    require(baseAmount <= baseDebt, SurplusAmountRestored(baseDebt));
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

  function _validatePayFee(DataTypes.SpokeData storage spoke, uint256 feeShares) internal view {
    // TODO: validate valid asset
    require(spoke.config.active, SpokeNotActive());
    require(feeShares != 0, InvalidFeeShares());
  }
}
