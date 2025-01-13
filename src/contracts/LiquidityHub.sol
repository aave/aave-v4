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

  // TODO: update name of this struct to reference the asset/reserve?
  struct Spoke {
    uint256 totalShares;
    uint256 drawnShares;
    // TODO: lastUpdateTimestamp?
    DataTypes.SpokeConfig config;
  }

  // TODO: Simplify the needed variables here
  // * potentially remove totalAssetsBase
  // * potentially store risk premium accruals separate from base interest accruals
  // We don't need all 3 of totalPremium, totalAssets, totalAssetsBase, because totalAssets = totalAssetsBase + totalPremium
  // To facilitate this refactor can expose totalAssets as a function
  // TODO: Consider renaming totalAssets
  struct Asset {
    uint256 id;
    uint256 totalShares;
    uint256 totalSharesBase;
    uint256 totalAssets;
    uint256 totalAssetsBase;
    uint256 drawnShares;
    uint256 drawnSharesBase;
    uint256 totalPremium;
    uint256 lastUpdateTimestamp;
    uint256 baseBorrowRate;
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

  /**
   * @param assetId The asset id
   * @return The total balance of a given asset, either in shares or in assets
   */
  function updateAndGetAssetBalance(uint256 assetId) external returns (uint256) {
    Asset storage asset = assets[assetId];
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    return asset.totalAssets;
  }

  function updateAndGetShareBalance(uint256 assetId) external returns (uint256) {
    Asset storage asset = assets[assetId];
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    return asset.totalShares;
  }

  // /////
  // Governance
  // /////

  function addAsset(DataTypes.AssetConfig memory params, address asset) external {
    // TODO: AccessControl
    assetsList.push(asset);
    assets[assetCount] = Asset({
      id: assetCount,
      totalShares: 0,
      totalSharesBase: 0,
      totalAssets: 0,
      totalAssetsBase: 0,
      drawnShares: 0,
      drawnSharesBase: 0,
      totalPremium: 0,
      lastUpdateTimestamp: block.timestamp,
      baseBorrowRate: 0,
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
  function supply(uint256 assetId, uint256 amount, uint256 riskPremium) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = assets[assetId];
    Spoke storage spoke = spokes[assetId][msg.sender];

    // Accrue interest before validating action
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    _validateSupply(asset, spoke, amount);

    // TODO Mitigate inflation attack (burn some amount if first supply)
    uint256 sharesAmount = convertAssetsToSharesDown(assetId, amount);
    require(sharesAmount > 0, 'INVALID_AMOUNT');

    asset.totalSharesBase += sharesAmount;
    asset.totalShares += sharesAmount;
    asset.totalAssetsBase += amount;
    asset.totalAssets += amount;

    // TODO: How to handle spoke shares?
    spoke.totalShares += sharesAmount;

    _updateBorrowRate(asset, riskPremium, amount, 0);

    // TODO: fee-on-transfer
    // instead transferred by spoke from user to LH
    // IERC20(assetsList[assetId]).safeTransferFrom(msg.sender, address(this), amount);

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

    uint256 sharesAmount = convertAssetsToSharesDown(assetId, amount);
    // TODO: On a withdraw, how do we know which shares (base or premium) to withdraw from? - Same as restore?
    // It's just from base (total assets) because risk premium portion only relates to debt. Risk premium never available
    asset.totalSharesBase -= sharesAmount;
    asset.totalShares -= sharesAmount;
    asset.totalAssetsBase -= amount;
    asset.totalAssets -= amount;
    spoke.totalShares -= sharesAmount;

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

    uint256 sharesAmount = convertAssetsToSharesUp(assetId, amount);
    asset.drawnSharesBase += sharesAmount;
    asset.drawnShares += sharesAmount;
    // TODO: What do we do with spoke shares here?
    spoke.drawnShares += sharesAmount;

    _updateBorrowRate(asset, riskPremium, 0, amount);

    IERC20(assetsList[assetId]).safeTransfer(to, amount);

    emit Draw(assetId, msg.sender, to, amount);

    return sharesAmount;
  }

  /**
   * @notice Repays debt on behalf of user
   * @dev Only callable by spokes
   * @dev Interest is paid off first from premium, then from base, passed as parameters
   * @param assetId The asset id
   * @param amountFromPremium The amount to repay from premium interest
   * @param amountFromBase The amount to repay from base interest
   * @param riskPremium The aggregated risk premium of the calling spoke
   */
  function restore(
    uint256 assetId,
    uint256 amountFromPremium,
    uint256 amountFromBase,
    uint256 riskPremium
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = assets[assetId];
    Spoke storage spoke = spokes[assetId][msg.sender];

    // Accrue interest before validating action
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    uint256 amount = amountFromPremium + amountFromBase;
    uint256 sharesAmount = convertAssetsToSharesDown(assetId, amount);
    _validateRestore(asset, sharesAmount, spoke.drawnShares);

    if (amountFromPremium > 0) asset.totalPremium -= amountFromPremium;
    if (amountFromBase > 0) {
      asset.drawnSharesBase -= convertAssetsToSharesDown(assetId, amountFromBase);
    }
    asset.drawnShares -= sharesAmount;

    // TODO: How to handle spoke's side shares?
    // TODO: Keep track of premium and base interest separately
    spoke.drawnShares -= sharesAmount;

    _updateBorrowRate(asset, riskPremium, amount, 0);

    emit Restore(assetId, msg.sender, amount);

    return sharesAmount;
  }

  //
  // public
  //

  // TODO: gas optimize the conversions
  function convertAssetsToSharesUp(uint256 assetId, uint256 amount) public view returns (uint256) {
    return amount.toSharesUp(assets[assetId].totalAssets, assets[assetId].totalShares);
  }

  function convertAssetsToSharesDown(
    uint256 assetId,
    uint256 amount
  ) public view returns (uint256) {
    return amount.toSharesDown(assets[assetId].totalAssets, assets[assetId].totalShares);
  }

  function convertSharesToAssetsUp(uint256 assetId, uint256 amount) public view returns (uint256) {
    return amount.toAssetsUp(assets[assetId].totalAssets, assets[assetId].totalShares);
  }

  function convertSharesToAssetsDown(
    uint256 assetId,
    uint256 amount
  ) public view returns (uint256) {
    return amount.toAssetsDown(assets[assetId].totalAssets, assets[assetId].totalShares);
  }

  function getBaseInterestRate(uint256 assetId) public view returns (uint256) {
    return assets[assetId].baseBorrowRate;
  }

  function getInterestRate(uint256 assetId) public view returns (uint256) {
    return
      assets[assetId].baseBorrowRate +
      (assets[assetId].baseBorrowRate * (wAvgBR[assetId].spokeBR / 1e28)) /
      1e4;
  }

  function getSpokeDrawnLiquidity(uint256 assetId, address spoke) public view returns (uint256) {
    return
      spokes[assetId][spoke].drawnShares.toAssetsUp(
        assets[assetId].totalAssets,
        assets[assetId].totalShares
      );
  }

  function getTotalDrawnLiquidity(uint256 assetId) public view returns (uint256) {
    return
      assets[assetId].drawnShares.toAssetsUp(
        assets[assetId].totalAssets,
        assets[assetId].totalShares
      );
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
        convertAssetsToSharesDown(asset.id, spoke.totalShares) + amount <= spoke.config.supplyCap,
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
      amount <= convertSharesToAssetsDown(asset.id, (spoke.totalShares - spoke.drawnShares)),
      'SUPPLIED_AMOUNT_EXCEEDED'
    );
    require(
      amount <=
        (asset.totalAssetsBase + asset.totalPremium) -
          convertSharesToAssetsUp(asset.id, asset.drawnShares),
      'NOT_AVAILABLE_LIQUIDITY'
    );
  }

  function _validateDraw(Asset storage asset, uint256 amount, uint256 drawCap) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    uint256 drawnAssets = asset.drawnSharesBase.toAssetsDown(asset.totalAssets, asset.totalShares) +
      asset.totalPremium;
    require(drawCap == type(uint256).max || amount + drawnAssets <= drawCap, 'DRAW_CAP_EXCEEDED');
    require(amount <= asset.totalAssets - drawnAssets, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateRestore(
    Asset storage asset,
    uint256 sharesAmount,
    uint256 drawnShares
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');

    // Ensure spoke is not restoring more than supplied
    require(sharesAmount <= drawnShares, 'INVALID_RESTORE_AMOUNT');
  }

  function _accrueAssetInterest(Asset storage asset, uint256 baseBorrowRate) internal {
    uint256 elapsed = block.timestamp - asset.lastUpdateTimestamp;
    if (elapsed > 0) {
      // Update total cumulated base interest on outstanding debt
      uint256 totalDrawnBase = convertSharesToAssetsUp(asset.id, asset.drawnSharesBase);
      if (totalDrawnBase == 0) return; // No interest to accrue if no liquidity drawn
      uint256 cumulatedBase = totalDrawnBase.rayMul(
        MathUtils.calculateLinearInterest(baseBorrowRate, uint40(asset.lastUpdateTimestamp))
      ); // TODO rounding

      // Update outstanding base debt
      asset.drawnSharesBase = cumulatedBase.toSharesDown(
        asset.totalAssetsBase,
        asset.totalSharesBase
      );

      // Base interest accrued since last action is added to total assets
      uint256 currentAccruedBase = cumulatedBase - totalDrawnBase;
      asset.totalAssetsBase += currentAccruedBase;

      // TODO: Double check math to add 1 (and rest of below) and also put into a library -> percentmul and fromRad
      // Accrue total premium interest, and update total assets
      asset.totalPremium += (currentAccruedBase * (wAvgBR[asset.id].spokeBR / 1e28)) / 1e4;
      asset.totalAssets = asset.totalAssetsBase + asset.totalPremium;

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
          totalDebt: convertSharesToAssetsUp(asset.id, asset.drawnShares),
          reserveFactor: 0, // TODO
          assetId: asset.id,
          virtualUnderlyingBalance: asset.totalAssets,
          usingVirtualBalance: true
        })
      );

    // Weight is spoke.drawnShares
    _calculateWAvgRP(asset.id, newRiskPremium, spokes[asset.id][msg.sender].drawnShares);

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
        newRiskPremium * newRiskPremiumWeight,
        newRiskPremiumWeight
      );
      wAvgBR[assetId].spokeBR = newWAvg;
      wAvgBR[assetId].amtDrawn = newSumWeights;
    } else {
      // Remove the old value from spoke from the weighted average
      (uint256 newWeightedAvg, uint256 newSumWeights) = MathUtils.subtractFromWeightedAverage(
        wAvgBR[assetId].spokeBR,
        wAvgBR[assetId].amtDrawn,
        lastSpokeBR[msg.sender][assetId].spokeBR * lastSpokeBR[msg.sender][assetId].amtDrawn,
        lastSpokeBR[msg.sender][assetId].amtDrawn
      );

      // Add new value to weighted average
      (uint256 finalWAvg, uint256 finalSumWeights) = MathUtils.addToWeightedAverage(
        newWeightedAvg,
        newSumWeights,
        newRiskPremium * newRiskPremiumWeight,
        newRiskPremiumWeight
      );
      wAvgBR[assetId].spokeBR = finalWAvg;
      wAvgBR[assetId].amtDrawn = finalSumWeights;
    }

    // Update the last received values
    lastSpokeBR[msg.sender][assetId].spokeBR = newRiskPremium;
    lastSpokeBR[msg.sender][assetId].amtDrawn = newRiskPremiumWeight;
  }

  function _addSpoke(uint256 assetId, DataTypes.SpokeConfig memory params, address spoke) internal {
    require(spoke != address(0), 'INVALID_SPOKE');
    spokes[assetId][spoke] = Spoke({
      totalShares: 0,
      drawnShares: 0,
      config: DataTypes.SpokeConfig({supplyCap: params.supplyCap, drawCap: params.drawCap})
    });

    emit SpokeAdded(assetId, spoke);
  }
}
