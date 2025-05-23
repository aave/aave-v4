// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {AssetLogic} from 'src/libraries/logic/AssetLogic.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SharesMath} from 'src/libraries/math/SharesMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

// @dev Amounts are `asset` denominated by default unless specified otherwise with `share` suffix
contract LiquidityHub is ILiquidityHub {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using AssetLogic for DataTypes.Asset;

  uint256 public constant MAX_ALLOWED_ASSET_DECIMALS = 18;

  mapping(uint256 assetId => DataTypes.Asset assetData) internal _assets;
  mapping(uint256 assetId => mapping(address spokeAddress => DataTypes.SpokeData spokeData))
    internal _spokes;

  IERC20[] public assetsList; // TODO: Check if Enumerable or Set makes more sense
  uint256 public assetCount;

  // /////
  // Governance
  // /////

  function addAsset(DataTypes.AssetConfig calldata config, address asset) external {
    // TODO: AccessControl, prevent dup entry
    _validateAssetConfig(config, asset);
    assetsList.push(IERC20(asset));
    uint256 assetId = assetCount++;
    _assets[assetId] = DataTypes.Asset({
      suppliedShares: 0,
      availableLiquidity: 0,
      baseDrawnShares: 0, // offset in exchange ratio
      premiumDrawnShares: 0,
      premiumOffset: 0,
      realizedPremium: 0,
      baseDebtIndex: WadRayMath.RAY,
      lastUpdateTimestamp: block.timestamp,
      baseBorrowRate: 0, // todo check
      id: assetId, // todo rm
      config: DataTypes.AssetConfig({
        decimals: config.decimals, // todo fetch decimals from token
        active: config.active,
        frozen: config.frozen,
        paused: config.paused,
        irStrategy: config.irStrategy
      })
    });

    emit AssetAdded(assetId++, asset);
  }

  function updateAssetConfig(uint256 assetId, DataTypes.AssetConfig calldata config) external {
    _validateAssetConfig(config, address(assetsList[assetId]));
    DataTypes.Asset storage asset = _assets[assetId];
    // TODO: AccessControl
    asset.config = DataTypes.AssetConfig({
      decimals: config.decimals,
      active: config.active,
      frozen: config.frozen,
      paused: config.paused,
      irStrategy: config.irStrategy
    });

    emit AssetConfigUpdated(assetId);
  }

  function addSpoke(uint256 assetId, DataTypes.SpokeConfig memory config, address spoke) external {
    // TODO: AccessControl
    _addSpoke(assetId, config, spoke);
  }

  function addSpokes(
    uint256[] calldata assetIds,
    DataTypes.SpokeConfig[] memory configs,
    address spoke
  ) external {
    // TODO: AccessControl

    require(assetIds.length == configs.length, MismatchedConfigs());
    for (uint256 i; i < assetIds.length; i++) {
      _addSpoke(assetIds[i], configs[i], spoke);
    }
  }

  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig memory config
  ) external {
    // TODO: AccessControl
    _spokes[assetId][spoke].config = DataTypes.SpokeConfig({
      drawCap: config.drawCap,
      supplyCap: config.supplyCap
    });

    emit SpokeConfigUpdated(assetId, spoke, config.drawCap, config.supplyCap);
  }

  /// @inheritdoc ILiquidityHub
  function add(uint256 assetId, uint256 amount, address from) external returns (uint256) {
    // TODO: authorization - only spokes

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue();
    _validateSupply(asset, spoke, amount);

    asset.updateBorrowRate({liquidityAdded: amount, liquidityTaken: 0});

    // todo: Mitigate inflation attack
    uint256 suppliedShares = asset.toSuppliedSharesDown(amount);
    require(suppliedShares != 0, InvalidSharesAmount());

    asset.availableLiquidity += amount;
    asset.suppliedShares += suppliedShares;

    spoke.suppliedShares += suppliedShares;

    // TODO: fee-on-transfer
    assetsList[assetId].safeTransferFrom(from, address(this), amount);

    emit Add(assetId, msg.sender, suppliedShares, amount);

    return suppliedShares;
  }

  /// @inheritdoc ILiquidityHub
  function remove(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    // TODO: authorization - only spokes

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue();
    _validateWithdraw(asset, spoke, amount);

    asset.updateBorrowRate({liquidityAdded: 0, liquidityTaken: amount});

    uint256 withdrawnShares = asset.toSuppliedSharesUp(amount); // non zero since we round up

    asset.availableLiquidity -= amount;
    asset.suppliedShares -= withdrawnShares;

    spoke.suppliedShares -= withdrawnShares;

    assetsList[assetId].safeTransfer(to, amount);

    emit Remove(assetId, msg.sender, withdrawnShares, amount);

    return withdrawnShares;
  }

  /// @inheritdoc ILiquidityHub
  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    // TODO: authorization - only spokes

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue();
    _validateDraw(asset, amount, spoke.config.drawCap);

    asset.updateBorrowRate({liquidityAdded: 0, liquidityTaken: amount});

    uint256 drawnShares = asset.toDrawnSharesUp(amount); // non zero since we round up

    asset.availableLiquidity -= amount;
    asset.baseDrawnShares += drawnShares;

    spoke.baseDrawnShares += drawnShares;

    assetsList[assetId].safeTransfer(to, amount);

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
    // TODO: authorization - only spokes
    // global & spoke premiumDebt (ghost, offset, realized) is *expected* to be updated on the `refreshPremiumDebt` callback

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue();

    _validateRestore(asset, spoke, baseAmount, premiumAmount);
    asset.updateBorrowRate({liquidityAdded: baseAmount, liquidityTaken: 0}); // both can be zero

    uint256 totalRestoredAmount = baseAmount + premiumAmount;
    uint256 baseDrawnSharesRestored = asset.toDrawnSharesDown(baseAmount);

    asset.availableLiquidity += totalRestoredAmount;
    asset.baseDrawnShares -= baseDrawnSharesRestored;

    spoke.baseDrawnShares -= baseDrawnSharesRestored;

    assetsList[assetId].safeTransferFrom(from, address(this), totalRestoredAmount);

    emit Restore(assetId, msg.sender, baseDrawnSharesRestored, totalRestoredAmount);

    return baseDrawnSharesRestored;
  }

  /// @inheritdoc ILiquidityHub
  function refreshPremiumDebt(
    uint256 assetId,
    int256 premiumDrawnShareDelta,
    int256 premiumOffsetDelta,
    int256 realizedPremiumDelta
  ) external {
    // todo only spoke
    (uint256 baseDebt, uint256 premiumDebt) = _assets[assetId].debt();
    _refresh(assetId, msg.sender, premiumDrawnShareDelta, premiumOffsetDelta, realizedPremiumDelta);
    (uint256 baseDebtAfter, uint256 premiumDebtAfter) = _assets[assetId].debt();
    // can increase due to precision loss on premium debt (base unchanged)
    // todo mathematically find premium diff ceiling and replace the `2`
    require(baseDebtAfter == baseDebt && premiumDebtAfter - premiumDebt <= 2, InvalidDebtChange());
  }

  /// @inheritdoc ILiquidityHub
  function settlePremiumDebt(
    uint256 assetId,
    int256 premiumDrawnShareDelta,
    int256 premiumOffsetDelta,
    int256 realizedPremiumDelta
  ) external {
    // todo: merge with repay and validate total debt only goes down by `premiumDebtRestored`
    // which ensures reduced assets are added to available liquidity
    // todo: only spoke
    uint256 baseDebt = _assets[assetId].baseDebt();
    _refresh(assetId, msg.sender, premiumDrawnShareDelta, premiumOffsetDelta, realizedPremiumDelta);
    require(_assets[assetId].baseDebt() == baseDebt, InvalidDebtChange());
  }

  function _refresh(
    uint256 assetId,
    address spokeAddress,
    int256 premiumDrawnShareDelta,
    int256 premiumOffsetDelta,
    int256 realizedPremiumDelta
  ) internal {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][spokeAddress];

    asset.premiumDrawnShares = _add(asset.premiumDrawnShares, premiumDrawnShareDelta);
    asset.premiumOffset = _add(asset.premiumOffset, premiumOffsetDelta);
    asset.realizedPremium = _add(asset.realizedPremium, realizedPremiumDelta);

    spoke.premiumDrawnShares = _add(spoke.premiumDrawnShares, premiumDrawnShareDelta);
    spoke.premiumOffset = _add(spoke.premiumOffset, premiumOffsetDelta);
    spoke.realizedPremium = _add(spoke.realizedPremium, realizedPremiumDelta);

    emit RefreshPremiumDebt(
      assetId,
      spokeAddress,
      premiumDrawnShareDelta,
      premiumOffsetDelta,
      realizedPremiumDelta
    );
  }

  //
  // public
  //

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

  function convertToSuppliedShares(
    uint256 assetId,
    uint256 assets
  ) external view returns (uint256) {
    return _assets[assetId].toSuppliedSharesDown(assets);
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

  function getBaseInterestRate(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].baseInterestRate();
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
    return _assets[assetId].toSuppliedAssetsDown(_assets[assetId].suppliedShares);
  }

  function getAssetSuppliedShares(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].suppliedShares;
  }

  function getTotalSuppliedAssets(uint256 assetId) external view override returns (uint256) {
    return _assets[assetId].totalSuppliedAssets();
  }

  function getSpokeSuppliedAmount(uint256 assetId, address spoke) external view returns (uint256) {
    return _assets[assetId].toSuppliedAssetsDown(_spokes[assetId][spoke].suppliedShares);
  }

  function getSpokeSuppliedShares(uint256 assetId, address spoke) external view returns (uint256) {
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
    uint256 amount
  ) internal view {
    require(amount != 0, InvalidSupplyAmount());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    require(!asset.config.frozen, AssetFrozen());
    require(assetsList[asset.id] != IERC20(address(0)), AssetNotListed());
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
    require(amount != 0, InvalidWithdrawAmount());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    uint256 withdrawable = asset.toSuppliedAssetsDown(spoke.suppliedShares);
    require(amount <= withdrawable, SuppliedAmountExceeded(withdrawable));
    require(amount <= asset.availableLiquidity, NotAvailableLiquidity(asset.availableLiquidity));
  }

  function _validateDraw(
    DataTypes.Asset storage asset,
    uint256 amount,
    uint256 drawCap
  ) internal view {
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
    require(baseAmountRestored + premiumAmountRestored != 0, InvalidRestoreAmount());
    require(asset.config.active, AssetNotActive());
    require(!asset.config.paused, AssetPaused());
    (uint256 baseDebt, ) = _getSpokeDebt(asset, spoke);
    require(baseAmountRestored <= baseDebt, SurplusAmountRestored(baseDebt));
    // we should have already restored premium debt
  }

  function _addSpoke(uint256 assetId, DataTypes.SpokeConfig memory config, address spoke) internal {
    require(spoke != address(0), InvalidSpoke());
    _spokes[assetId][spoke] = DataTypes.SpokeData({
      suppliedShares: 0,
      baseDrawnShares: 0,
      premiumDrawnShares: 0,
      premiumOffset: 0,
      realizedPremium: 0,
      lastUpdateTimestamp: 0,
      config: config
    });

    emit SpokeAdded(assetId, spoke);
  }

  function _validateAssetConfig(
    DataTypes.AssetConfig calldata config,
    address asset
  ) internal pure {
    require(asset != address(0), InvalidAssetAddress());
    require(address(config.irStrategy) != address(0), InvalidIrStrategy());
    require(config.decimals <= MAX_ALLOWED_ASSET_DECIMALS, InvalidAssetDecimals());
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
}
