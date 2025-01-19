// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../dependencies/openzeppelin/IERC20.sol';
import {ILiquidityHub} from '../interfaces/ILiquidityHub.sol';
import {IReserveInterestRateStrategy} from '../interfaces/IReserveInterestRateStrategy.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';
import {WadRayMath} from './WadRayMath.sol';
import {SharesMath} from './SharesMath.sol';
import {MathUtils} from './MathUtils.sol';

contract LiquidityHub is ILiquidityHub {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using SharesMath for uint256;

  struct Spoke {
    uint256 shares;
    uint256 debt;
    uint256 premium;
    // TODO: lastUpdateTimestamp?
    DataTypes.SpokeConfig config;
  }

  struct Asset {
    uint256 id;
    uint256 shares;
    uint256 availableLiquidity;
    uint256 debt;
    uint256 outstandingPremium;
    uint256 baseBorrowIndex;
    uint256 baseBorrowRate;
    uint256 lastUpdateTimestamp;
    DataTypes.AssetConfig config;
  }

  struct WeightedAvg {
    uint256 spokeBR;
    uint256 amtDrawn;
  }

  // asset id => asset data
  mapping(uint256 => Asset) public assets;
  address[] public assetsList; // TODO: Check if Enumerable or Set makes more sense
  uint256 public assetCount;

  // asset id => spoke address => spoke
  mapping(uint256 => mapping(address => Spoke)) public spokes;

  // asset id => weighted average of spokes' borrow rates for asset
  mapping(uint256 => WeightedAvg) public wAvgBR;
  // address of spoke => asset id -> last received borrow rate from spoke for asset
  mapping(address => mapping(uint256 => WeightedAvg)) public lastSpokeBR;

  //
  // External
  //

  function getAsset(uint256 assetId) external view returns (Asset memory) {
    return assets[assetId];
  }

  function getSpoke(uint256 assetId, address spoke) external view returns (Spoke memory) {
    return spokes[assetId][spoke];
  }

  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeConfig memory) {
    return spokes[assetId][spoke].config;
  }

  function getAssetTotalAssets(uint256 assetId) external view returns (uint256) {
    return
      assets[assetId].availableLiquidity +
      assets[assetId].debt +
      assets[assetId].outstandingPremium;
  }

  /**
   * @param assetId The asset id
   * @return The total balance of a given asset, either in shares or in assets
   */
  function updateAndGetAssetBalance(uint256 assetId) external returns (uint256) {
    Asset storage asset = assets[assetId];
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    return this.getAssetTotalAssets(assetId);
  }

  function updateAndGetShareBalance(uint256 assetId) external returns (uint256) {
    Asset storage asset = assets[assetId];
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    return asset.shares;
  }

  // /////
  // Governance
  // /////

  function addAsset(DataTypes.AssetConfig memory params, address asset) external {
    // TODO: AccessControl
    assetsList.push(asset);
    assets[assetCount] = Asset({
      id: assetCount,
      shares: 0,
      availableLiquidity: 0,
      debt: 0,
      outstandingPremium: 0,
      baseBorrowIndex: 1,
      baseBorrowRate: 0,
      lastUpdateTimestamp: block.timestamp,
      config: DataTypes.AssetConfig({
        decimals: params.decimals,
        active: params.active,
        irStrategy: params.irStrategy
      })
    });
    assetCount++;

    // TODO: emit event
  }

  function updateAssetConfig(uint256 assetId, DataTypes.AssetConfig memory params) external {
    // TODO: AccessControl
    assets[assetId].config = DataTypes.AssetConfig({
      decimals: params.decimals,
      active: params.active,
      irStrategy: params.irStrategy
    });

    // TODO: emit event
  }

  function addSpoke(uint256 assetId, DataTypes.SpokeConfig memory params, address spoke) external {
    // TODO: AccessControl
    _addSpoke(assetId, params, spoke);
  }

  function addSpokes(
    uint256[] calldata assetIds,
    DataTypes.SpokeConfig[] memory configs,
    address spoke
  ) external {
    // TODO: AccessControl

    require(assetIds.length == configs.length, 'MISMATCHED_CONFIGS');
    for (uint256 i; i < assetIds.length; i++) {
      _addSpoke(assetIds[i], configs[i], spoke);
    }
  }

  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig memory params
  ) external {
    // TODO: AccessControl
    spokes[assetId][spoke].config = DataTypes.SpokeConfig({
      drawCap: params.drawCap,
      supplyCap: params.supplyCap
    });

    // TODO: emit event
  }

  // /////
  // Users
  // /////

  /// @dev risk premium is calculated from the spoke and passed upon every action
  function supply(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremium,
    address supplier
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = assets[assetId];
    Spoke storage spoke = spokes[assetId][msg.sender];

    // Accrue interest before validating action
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    _validateSupply(asset, spoke, amount);

    // TODO Mitigate inflation attack (burn some amount if first supply)
    uint256 sharesAmount = convertAssetsToSharesDown(assetId, amount);
    require(sharesAmount > 0, 'INVALID_AMOUNT');

    asset.shares += sharesAmount;
    asset.availableLiquidity += amount;

    // TODO: How to handle spoke shares?
    spoke.shares += sharesAmount;

    _updateBorrowRate(asset, riskPremium, amount, 0);

    // TODO: fee-on-transfer
    IERC20(assetsList[assetId]).safeTransferFrom(supplier, address(this), amount);

    emit Supply(assetId, msg.sender, amount);

    return sharesAmount;
  }

  // TODO: Be able to pass -1 as amount to withdraw all or accept number of shares
  function withdraw(
    uint256 assetId,
    address to,
    uint256 amount,
    uint256 riskPremium
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = assets[assetId];
    Spoke storage spoke = spokes[assetId][msg.sender];

    // Accrue interest before validating action
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    _validateWithdraw(asset, spoke, amount);

    // TODO: Should this shares amount be from before or after accruing interest?
    uint256 sharesAmount = convertAssetsToSharesDown(assetId, amount);

    asset.shares -= sharesAmount;
    asset.availableLiquidity -= amount;

    _updateBorrowRate(asset, riskPremium, 0, amount);

    IERC20(assetsList[assetId]).safeTransfer(to, amount);

    emit Withdraw(assetId, msg.sender, to, amount);

    return sharesAmount;
  }

  function draw(
    uint256 assetId,
    address to,
    uint256 amount,
    uint256 riskPremium
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = assets[assetId];
    Spoke storage spoke = spokes[assetId][msg.sender];

    // Accrue interest before validating action
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    _validateDraw(asset, amount, spoke.config.drawCap);

    asset.availableLiquidity -= amount;
    asset.debt += amount;

    // TODO: Properly handle spoke accounting
    spoke.debt += amount;

    _updateBorrowRate(asset, riskPremium, 0, amount);

    IERC20(assetsList[assetId]).safeTransfer(to, amount);

    emit Draw(assetId, msg.sender, to, amount);

    // TODO: We used to return shares of debt amount, is this new return value needed?
    return amount;
  }

  /**
   * @notice Repays debt on behalf of user
   * @dev Only callable by spokes
   * @dev Interest is always paid off first from premium, then from base
   * @param assetId The asset id
   * @param amount The amount to repay
   * @param riskPremium The aggregated risk premium of the calling spoke
   * @param repayer The address who is trying to settle the credit line
   * @return The amount of shares restored
   */
  function restore(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremium,
    address repayer
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = assets[assetId];
    Spoke storage spoke = spokes[assetId][msg.sender];

    // Accrue interest before validating action
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    _validateRestore(asset, amount, spoke.debt);

    if (amount <= asset.outstandingPremium) {
      // If amount is less than or equal premium, only subtract from premium
      asset.outstandingPremium -= amount;
    } else {
      // Subtract full premium and then subtract remainder from base
      uint256 baseRepay = amount - asset.outstandingPremium;
      asset.outstandingPremium = 0;
      asset.debt -= baseRepay;
    }

    asset.availableLiquidity += amount;

    // TODO: Handle spoke side accounting
    spoke.debt -= amount;

    _updateBorrowRate(asset, riskPremium, amount, 0);

    // TODO: fee-on-transfer, we receive at least `amount`
    IERC20(assetsList[assetId]).safeTransferFrom(repayer, address(this), amount);

    emit Restore(assetId, msg.sender, amount);

    // TODO: We used to return sharesAmount of repaid debt. Do we still want this new absolute return value?
    return amount;
  }

  //
  // public
  //

  // TODO: gas optimize the conversions
  function convertAssetsToSharesUp(uint256 assetId, uint256 amount) public view returns (uint256) {
    return amount.toSharesUp(this.getAssetTotalAssets(assetId), assets[assetId].shares);
  }

  function convertAssetsToSharesDown(
    uint256 assetId,
    uint256 amount
  ) public view returns (uint256) {
    return amount.toSharesDown(this.getAssetTotalAssets(assetId), assets[assetId].shares);
  }

  function convertSharesToAssetsUp(uint256 assetId, uint256 amount) public view returns (uint256) {
    return amount.toAssetsUp(this.getAssetTotalAssets(assetId), assets[assetId].shares);
  }

  function convertSharesToAssetsDown(
    uint256 assetId,
    uint256 amount
  ) public view returns (uint256) {
    return amount.toAssetsDown(this.getAssetTotalAssets(assetId), assets[assetId].shares);
  }

  function getBaseInterestRate(uint256 assetId) public view returns (uint256) {
    return assets[assetId].baseBorrowRate;
  }

  function getInterestRate(uint256 assetId) public view returns (uint256) {
    return
      assets[assetId].baseBorrowRate +
      (assets[assetId].baseBorrowRate * (wAvgBR[assetId].spokeBR.fromRad())) /
      1e4;
  }

  function getSpokeDrawnLiquidity(uint256 assetId, address spoke) public view returns (uint256) {
    return spokes[assetId][spoke].debt;
  }

  function getTotalDrawnLiquidity(uint256 assetId) public view returns (uint256) {
    return assets[assetId].debt;
  }

  //
  // Internal
  //

  function _validateSupply(Asset storage asset, Spoke storage spoke, uint256 amount) internal view {
    require(assetsList[asset.id] != address(0), 'ASSET_NOT_LISTED');
    // TODO: Different states e.g. frozen, paused
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      spoke.config.supplyCap == type(uint256).max ||
        convertAssetsToSharesDown(asset.id, spoke.shares) + amount <= spoke.config.supplyCap,
      'SUPPLY_CAP_EXCEEDED'
    );
  }

  function _validateWithdraw(
    Asset storage asset,
    Spoke storage spoke,
    uint256 amount
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    // TODO: still allow withdrawal even if asset is not active, only prevent for frozen/paused?
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      amount <= convertSharesToAssetsDown(asset.id, spoke.shares) - spoke.debt,
      'SUPPLIED_AMOUNT_EXCEEDED'
    );
    require(amount <= asset.availableLiquidity, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateDraw(Asset storage asset, uint256 amount, uint256 drawCap) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(drawCap == type(uint256).max || amount + asset.debt <= drawCap, 'DRAW_CAP_EXCEEDED');
    require(amount <= asset.availableLiquidity, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateRestore(
    Asset storage asset,
    uint256 amountRestored,
    uint256 amountDrawn
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');

    // Ensure spoke is not restoring more than supplied
    require(amountRestored <= amountDrawn, 'INVALID_RESTORE_AMOUNT');
  }

  function _accrueAssetInterest(Asset storage asset, uint256 baseBorrowRate) internal {
    uint256 elapsed = block.timestamp - asset.lastUpdateTimestamp;
    if (elapsed > 0) {
      // Update total cumulated base interest on outstanding debt
      uint256 totalDrawnBase = asset.debt;
      if (totalDrawnBase == 0) return; // No interest to accrue if no liquidity drawn
      uint256 cumulatedBase = totalDrawnBase.rayMul(
        MathUtils.calculateLinearInterest(baseBorrowRate, uint40(asset.lastUpdateTimestamp))
      ); // TODO rounding

      // Update outstanding base debt
      asset.debt = cumulatedBase;

      // TODO: Double check math to add 1 (and rest of below) and also put into a library -> percentmul and fromRad
      // Accrue total premium interest on the accrued base
      uint256 currentAccruedBase = cumulatedBase - totalDrawnBase;
      asset.outstandingPremium += (currentAccruedBase * (wAvgBR[asset.id].spokeBR / 1e28)) / 1e4;

      // TODO: Fix this math
      // Update base borrow index
      asset.baseBorrowIndex = asset.baseBorrowIndex * (1 + asset.baseBorrowRate);

      // TODO: RF in terms of fee shares
      asset.lastUpdateTimestamp = block.timestamp;
    }
  }

  function _updateBorrowRate(
    Asset storage asset,
    uint256 newRiskPremium,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal {
    // Fetch base borrow rate
    uint256 baseBorrowRate = IReserveInterestRateStrategy(asset.config.irStrategy)
      .calculateInterestRates(
        DataTypes.CalculateInterestRatesParams({
          liquidityAdded: liquidityAdded,
          liquidityTaken: liquidityTaken,
          totalDebt: asset.debt, // TODO: Does total debt here need to include premium?
          reserveFactor: 0, // TODO
          assetId: asset.id,
          virtualUnderlyingBalance: this.getAssetTotalAssets(asset.id),
          usingVirtualBalance: true
        })
      );

    // Weight is spoke.drawnShares
    _calculateWAvgRP(asset.id, newRiskPremium, spokes[asset.id][msg.sender].debt);

    // Caching borrow rate for next accrual on action
    asset.baseBorrowRate = baseBorrowRate;
  }

  /**
   * @notice Calculates the weighted average risk premium across spokes, given new risk premium and weight from spoke
   * @param assetId The asset id
   * @param newRiskPremium The new risk premium
   * @param newRiskPremiumWeight The new risk premium weight
   */
  function _calculateWAvgRP(
    uint256 assetId,
    uint256 newRiskPremium,
    uint256 newRiskPremiumWeight
  ) internal {
    // Check our saved risk premiums from this spoke to see if there is a change, if not, skip
    if (
      newRiskPremium == lastSpokeBR[msg.sender][assetId].spokeBR &&
      newRiskPremiumWeight == lastSpokeBR[msg.sender][assetId].amtDrawn
    ) {
      return;
    }

    // If first update, assign the new value
    // Note: Just a change in weight matters, also can't divide by 0
    if (wAvgBR[assetId].amtDrawn == 0 && newRiskPremiumWeight != 0) {
      (uint256 newWAvg, uint256 newSumWeights) = MathUtils.addToWeightedAverage(
        0,
        0,
        newRiskPremium,
        newRiskPremiumWeight
      );
      wAvgBR[assetId].spokeBR = newWAvg;
      wAvgBR[assetId].amtDrawn = newSumWeights;
    } else {
      // Remove the old value from spoke from the weighted average
      (uint256 newWeightedAvg, uint256 newSumWeights) = MathUtils.subtractFromWeightedAverage(
        wAvgBR[assetId].spokeBR,
        wAvgBR[assetId].amtDrawn,
        lastSpokeBR[msg.sender][assetId].spokeBR,
        lastSpokeBR[msg.sender][assetId].amtDrawn
      );

      // Add new value to weighted average
      (wAvgBR[assetId].spokeBR, wAvgBR[assetId].amtDrawn) = MathUtils.addToWeightedAverage(
        newWeightedAvg,
        newSumWeights,
        newRiskPremium,
        newRiskPremiumWeight
      );
    }

    // Update the last received values
    lastSpokeBR[msg.sender][assetId].spokeBR = newRiskPremium;
    lastSpokeBR[msg.sender][assetId].amtDrawn = newRiskPremiumWeight;
  }

  function _addSpoke(uint256 assetId, DataTypes.SpokeConfig memory params, address spoke) internal {
    require(spoke != address(0), 'INVALID_SPOKE');
    spokes[assetId][spoke] = Spoke({
      shares: 0,
      debt: 0,
      premium: 0,
      config: DataTypes.SpokeConfig({supplyCap: params.supplyCap, drawCap: params.drawCap})
    });
    emit SpokeAdded(assetId, spoke);
  }
}
