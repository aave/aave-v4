// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {AssetLogic} from 'src/contracts/AssetLogic.sol';
import {SpokeDataLogic} from 'src/contracts/SpokeDataLogic.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';
import {SharesMath} from 'src/contracts/SharesMath.sol';
import {MathUtils} from 'src/contracts/MathUtils.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';

// @dev Amounts are `asset` denominated by default unless specified otherwise with `share` suffix
contract LiquidityHub is ILiquidityHub {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using AssetLogic for DataTypes.Asset;
  using SpokeDataLogic for DataTypes.SpokeData;

  uint256 public constant DEFAULT_ASSET_INDEX = WadRayMath.RAY;
  uint256 public constant DEFAULT_SPOKE_INDEX = 0;

  mapping(uint256 assetId => DataTypes.Asset assetData) internal _assets;
  mapping(uint256 assetId => mapping(address spokeAddress => DataTypes.SpokeData spokeData))
    internal _spokes;

  IERC20[] public assetsList; // TODO: Check if Enumerable or Set makes more sense
  uint256 public assetCount;

  // /////
  // Governance
  // /////

  function addAsset(DataTypes.AssetConfig memory config, address asset) external {
    // TODO: AccessControl
    assetsList.push(IERC20(asset));
    _assets[assetCount] = DataTypes.Asset({
      id: assetCount,
      suppliedShares: 0,
      availableLiquidity: 0,
      baseDebt: 0,
      outstandingPremium: 0,
      baseBorrowIndex: DEFAULT_ASSET_INDEX,
      baseBorrowRate: 0,
      lastUpdateTimestamp: block.timestamp,
      riskPremium: 0,
      config: DataTypes.AssetConfig({
        decimals: config.decimals,
        active: config.active,
        irStrategy: config.irStrategy
      })
    });

    emit AssetAdded(assetCount++, asset);
  }

  function updateAssetConfig(uint256 assetId, DataTypes.AssetConfig memory config) external {
    // TODO: AccessControl
    _assets[assetId].config = DataTypes.AssetConfig({
      decimals: config.decimals,
      active: config.active,
      irStrategy: config.irStrategy
    });

    emit AssetConfigUpdated(assetId, config.decimals, config.active, config.irStrategy);
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

  // /////
  // Users
  // /////

  /// @inheritdoc ILiquidityHub
  function supply(
    uint256 assetId,
    uint256 amount,
    uint32 riskPremium,
    address supplier
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    _accrueInterest(asset, spoke);
    _validateSupply(asset, spoke, amount);

    asset.updateBorrowRate({liquidityAdded: amount, liquidityTaken: 0});
    _updateRiskPremiumAndBaseDebt({
      asset: asset,
      spoke: spoke,
      newSpokeRiskPremium: _boundBps(riskPremium).rayify(),
      baseDebtChange: 0
    });

    // todo: Mitigate inflation attack (burn some amount if first supply)
    uint256 sharesAmount = asset.convertToSharesDown(amount);
    require(sharesAmount > 0, InvalidSharesAmount());

    asset.availableLiquidity += amount;
    asset.suppliedShares += sharesAmount;
    spoke.suppliedShares += sharesAmount; // todo: mint 4626 shares to abstract this accounting

    // TODO: fee-on-transfer
    assetsList[assetId].safeTransferFrom(supplier, address(this), amount);

    emit Supply(assetId, msg.sender, amount);

    return sharesAmount;
  }

  /// @inheritdoc ILiquidityHub
  function withdraw(
    uint256 assetId,
    uint256 amount,
    uint32 riskPremium,
    address to
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    _accrueInterest(asset, spoke); // accrue interest before validating action
    _validateWithdraw(asset, spoke, amount);

    asset.updateBorrowRate({liquidityAdded: 0, liquidityTaken: amount});
    _updateRiskPremiumAndBaseDebt(asset, spoke, _boundBps(riskPremium).rayify(), 0); // no base debt change

    uint256 sharesAmount = asset.convertToSharesUp(amount);
    require(sharesAmount > 0, InvalidSharesAmount());

    asset.suppliedShares -= sharesAmount;
    asset.availableLiquidity -= amount;
    spoke.suppliedShares -= sharesAmount;

    assetsList[assetId].safeTransfer(to, amount);

    emit Withdraw(assetId, msg.sender, to, amount);

    return sharesAmount;
  }

  /// @inheritdoc ILiquidityHub
  function draw(
    uint256 assetId,
    uint256 amount,
    uint32 riskPremium,
    address to
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    _accrueInterest(asset, spoke); // accrue interest before validating action
    _validateDraw(asset, amount, spoke.config.drawCap);

    asset.updateBorrowRate({liquidityAdded: 0, liquidityTaken: amount});
    _updateRiskPremiumAndBaseDebt(asset, spoke, _boundBps(riskPremium).rayify(), int256(amount)); // base debt added

    asset.availableLiquidity -= amount;

    assetsList[assetId].safeTransfer(to, amount);

    emit Draw(assetId, msg.sender, to, amount);

    return amount;
  }

  /// @inheritdoc ILiquidityHub
  function restore(
    uint256 assetId,
    uint256 amount,
    uint32 riskPremium,
    address repayer
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    _accrueInterest(asset, spoke); // accrue interest before validating action
    _validateRestore(asset, spoke, amount);

    asset.updateBorrowRate({liquidityAdded: amount, liquidityTaken: 0});
    uint256 baseDebtRestored = _deductFromOutstandingPremium(asset, spoke, amount);
    _updateRiskPremiumAndBaseDebt(
      asset,
      spoke,
      _boundBps(riskPremium).rayify(),
      -int256(baseDebtRestored)
    );

    asset.availableLiquidity += amount;

    assetsList[assetId].safeTransferFrom(repayer, address(this), amount);

    emit Restore(assetId, msg.sender, amount);

    return amount;
  }

  /// @inheritdoc ILiquidityHub
  function accrueInterest(uint256 assetId, uint32 riskPremium) external {
    // TODO: authorization - only spokes

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    _accrueInterest(asset, spoke);
    _updateRiskPremiumAndBaseDebt(asset, spoke, _boundBps(riskPremium).rayify(), 0);
  }

  //
  // public
  //

  function previewNextBorrowIndex(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].previewNextBorrowIndex();
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

  function getTotalAssets(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].getTotalAssets();
  }

  function convertToSharesUp(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].convertToSharesUp(assets);
  }

  function convertToSharesDown(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].convertToSharesDown(assets);
  }

  function convertToAssetsUp(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].convertToAssetsUp(shares);
  }

  function convertToAssetsDown(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].convertToAssetsDown(shares);
  }

  function convertToAssets(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].convertToAssetsDown(shares);
  }

  function convertToShares(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].convertToSharesDown(assets);
  }

  function getBaseInterestRate(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].baseBorrowRate;
  }

  function getInterestRate(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].getInterestRate();
  }

  function getAssetDebt(uint256 assetId) external view returns (uint256, uint256) {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = _assets[assetId]
      .previewInterest(_assets[assetId].previewNextBorrowIndex());
    return (cumulatedBaseDebt, cumulatedOutstandingPremium);
  }

  function getAssetCumulativeDebt(uint256 assetId) external view returns (uint256) {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = _assets[assetId]
      .previewInterest(_assets[assetId].previewNextBorrowIndex());
    return cumulatedBaseDebt + cumulatedOutstandingPremium;
  }

  function getSpokeDebt(uint256 assetId, address spoke) external view returns (uint256, uint256) {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = _spokes[assetId][spoke]
      .previewInterest(_assets[assetId].previewNextBorrowIndex());
    return (cumulatedBaseDebt, cumulatedOutstandingPremium);
  }

  function getSpokeCumulativeDebt(uint256 assetId, address spoke) external view returns (uint256) {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = _spokes[assetId][spoke]
      .previewInterest(_assets[assetId].previewNextBorrowIndex());
    return cumulatedBaseDebt + cumulatedOutstandingPremium;
  }

  function getAssetSuppliedAmount(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].convertToAssetsDown(_assets[assetId].suppliedShares);
  }

  function getAssetSuppliedShares(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].suppliedShares;
  }

  function getSpokeSuppliedAmount(uint256 assetId, address spoke) external view returns (uint256) {
    return _assets[assetId].convertToAssetsDown(_spokes[assetId][spoke].suppliedShares);
  }

  function getSpokeSuppliedShares(uint256 assetId, address spoke) external view returns (uint256) {
    return _spokes[assetId][spoke].suppliedShares;
  }

  function getAssetRiskPremium(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].riskPremium.derayify();
  }

  function getSpokeRiskPremium(uint256 assetId, address spoke) external view returns (uint256) {
    return _spokes[assetId][spoke].riskPremium.derayify();
  }

  function getAvailableLiquidity(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].availableLiquidity;
  }

  /// @inheritdoc ILiquidityHub
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
    require(amount > 0, InvalidSupplyAmount());
    require(assetsList[asset.id] != IERC20(address(0)), AssetNotListed());
    // TODO: Different states e.g. frozen, paused
    require(asset.config.active, AssetNotActive());
    require(
      spoke.config.supplyCap == type(uint256).max ||
        asset.convertToAssetsDown(spoke.suppliedShares) + amount <= spoke.config.supplyCap,
      SupplyCapExceeded(spoke.config.supplyCap)
    );
  }

  function _validateWithdraw(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    // TODO: still allow withdrawal even if asset is not active, only prevent for frozen/paused?
    require(asset.config.active, AssetNotActive());
    require(amount > 0, InvalidWithdrawAmount());
    uint256 withdrawable = asset.convertToAssetsDown(spoke.suppliedShares);
    require(amount <= withdrawable, SuppliedAmountExceeded(withdrawable));
    require(amount <= asset.availableLiquidity, NotAvailableLiquidity(asset.availableLiquidity));
  }

  function _validateDraw(
    DataTypes.Asset storage asset,
    uint256 amount,
    uint256 drawCap
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, AssetNotActive());
    require(amount > 0, InvalidDrawAmount());
    require(
      drawCap == type(uint256).max || amount + asset.baseDebt <= drawCap,
      DrawCapExceeded(drawCap)
    );
    require(amount <= asset.availableLiquidity, NotAvailableLiquidity(asset.availableLiquidity));
  }

  function _validateRestore(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amountRestored
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, AssetNotActive());
    require(amountRestored > 0, InvalidRestoreAmount());
    // Ensure spoke is not restoring more than accrued drawn
    uint256 maxAllowedRestore = spoke.baseDebt + spoke.outstandingPremium;
    require(amountRestored <= maxAllowedRestore, SurplusAmountRestored(maxAllowedRestore));
  }

  // @dev Utilizes existing asset & spoke: `baseBorrowIndex`, `riskPremium`
  function _accrueInterest(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke
  ) internal {
    uint256 nextBaseBorrowIndex = asset.previewNextBorrowIndex();

    asset.accrueInterest(nextBaseBorrowIndex);
    spoke.accrueInterest(nextBaseBorrowIndex);
  }

  // @dev Expects both `asset.baseDebt` & `spoke.baseDebt` have been accrued
  // @dev Does not update `outstandingPremium`
  function _updateRiskPremiumAndBaseDebt(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 newSpokeRiskPremium,
    int256 baseDebtChange
  ) internal {
    uint256 existingAssetDebt = asset.baseDebt;
    uint256 existingSpokeDebt = spoke.baseDebt;

    // weighted average risk premium of all spokes without current `spoke`
    (uint256 assetRiskPremiumWithoutCurrent, uint256 assetDebtWithoutCurrent) = MathUtils
      .subtractFromWeightedAverage(
        asset.riskPremium,
        existingAssetDebt,
        spoke.riskPremium, // use current spoke risk premium
        existingSpokeDebt
      );

    uint256 newSpokeDebt = baseDebtChange > 0
      ? existingSpokeDebt + uint256(baseDebtChange) // debt added
      : existingSpokeDebt - uint256(-baseDebtChange); // debt restored
    // force underflow^: only possible when spoke takes repays amount more than net drawn

    (uint256 newAssetRiskPremium, uint256 newAssetDebt) = MathUtils.addToWeightedAverage(
      assetRiskPremiumWithoutCurrent,
      assetDebtWithoutCurrent,
      newSpokeRiskPremium, // use new spoke risk premium
      newSpokeDebt
    );

    asset.baseDebt = newAssetDebt;
    spoke.baseDebt = newSpokeDebt;

    asset.riskPremium = newAssetRiskPremium;
    spoke.riskPremium = newSpokeRiskPremium;
  }

  function _addSpoke(uint256 assetId, DataTypes.SpokeConfig memory config, address spoke) internal {
    require(spoke != address(0), InvalidSpoke());
    _spokes[assetId][spoke] = DataTypes.SpokeData({
      suppliedShares: 0,
      baseDebt: 0,
      outstandingPremium: 0,
      baseBorrowIndex: DEFAULT_SPOKE_INDEX,
      riskPremium: 0,
      lastUpdateTimestamp: 0,
      config: config
    });
    emit SpokeAdded(assetId, spoke);
  }

  // @dev `amount` can cover at most spoke's outstanding premium
  function _deductFromOutstandingPremium(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount
  ) internal returns (uint256) {
    uint256 spokeOutstandingPremium = spoke.outstandingPremium;

    uint256 baseDebtRestored;

    if (amount > spokeOutstandingPremium) {
      baseDebtRestored = amount - spokeOutstandingPremium;
      spoke.outstandingPremium = 0;
      // underflow not possible bc of invariant: asset.outstandingPremium >= spoke.outstandingPremium
      asset.outstandingPremium -= spokeOutstandingPremium;
    } else {
      // no base debt is restored, only outstanding premium
      spoke.outstandingPremium -= amount;
      asset.outstandingPremium -= amount;
    }

    return baseDebtRestored;
  }

  function _boundBps(uint32 a) internal pure returns (uint256) {
    require(a < 1000_00, InvalidRiskPremiumBps(a));
    return uint256(a);
  }
}
