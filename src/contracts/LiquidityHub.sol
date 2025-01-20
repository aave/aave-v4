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
import {PercentageMath} from './PercentageMath.sol';

// @dev Amounts are `asset` denominated unless specified otherwise (`share`)
contract LiquidityHub is ILiquidityHub {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using PercentageMath for uint256;

  struct Spoke {
    uint256 suppliedShares; // share
    uint256 debt; // asset
    uint256 outstandingPremium; // asset
    // TODO: lastUpdateTimestamp?
    DataTypes.SpokeConfig config;
  }

  struct Asset {
    uint256 id;
    uint256 suppliedShares; // share
    uint256 availableLiquidity; // asset
    uint256 debt; // asset
    uint256 outstandingPremium; // asset
    uint256 baseBorrowIndex;
    uint256 baseBorrowRate;
    uint256 averageRiskPremiumRad;
    uint256 lastUpdateTimestamp;
    DataTypes.AssetConfig config;
  }

  mapping(uint256 assetId => Asset assetData) internal _assets;
  IERC20[] public assetsList; // TODO: Check if Enumerable or Set makes more sense
  uint256 public assetCount;

  mapping(uint256 assetId => mapping(address spokeAddress => Spoke spokeConfig)) internal _spokes;

  // todo: probably won't need
  struct WeightedAvg {
    uint256 spokeBR;
    uint256 amtDrawn;
  }

  // asset id => weighted average of spokes' borrow rates for asset
  mapping(uint256 => WeightedAvg) public wAvgBR;
  // address of spoke => asset id -> last received borrow rate from spoke for asset
  mapping(address => mapping(uint256 => WeightedAvg)) public lastSpokeBR;

  //
  // External
  //

  function getAsset(uint256 assetId) external view returns (Asset memory) {
    return _assets[assetId];
  }

  function getSpoke(uint256 assetId, address spoke) external view returns (Spoke memory) {
    return _spokes[assetId][spoke];
  }

  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeConfig memory) {
    return _spokes[assetId][spoke].config;
  }

  function getTotalAssets(uint256 assetId) external view returns (uint256) {
    Asset storage asset = _assets[assetId];
    return _getTotalAssets(asset);
  }

  // todo: needed?
  /**
   * @return The total balance of a given asset in assets
   */
  function updateAndGetAssetBalance(uint256 assetId) external returns (uint256) {
    Asset storage asset = _assets[assetId];
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    return _getTotalAssets(asset);
  }

  function updateAndGetShareBalance(uint256 assetId) external returns (uint256) {
    Asset storage asset = _assets[assetId];
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    return asset.suppliedShares;
  }

  // /////
  // Governance
  // /////

  function addAsset(DataTypes.AssetConfig memory params, address asset) external {
    // TODO: AccessControl
    assetsList.push(IERC20(asset));
    _assets[assetCount] = Asset({
      id: assetCount,
      suppliedShares: 0,
      availableLiquidity: 0,
      debt: 0,
      outstandingPremium: 0,
      baseBorrowIndex: 1,
      baseBorrowRate: 0,
      lastUpdateTimestamp: block.timestamp,
      averageRiskPremiumRad: 0,
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
    _assets[assetId].config = DataTypes.AssetConfig({
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
    _spokes[assetId][spoke].config = DataTypes.SpokeConfig({
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

    Asset storage asset = _assets[assetId];
    Spoke storage spoke = _spokes[assetId][msg.sender];

    // Accrue interest before validating action
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    _validateSupply(asset, spoke, amount);

    // todo: Mitigate inflation attack (burn some amount if first supply)
    uint256 sharesAmount = _convertToSharesDown(asset, amount);
    require(sharesAmount > 0, 'INVALID_AMOUNT'); // todo fail earlier for this case

    asset.suppliedShares += sharesAmount;
    asset.availableLiquidity += amount;

    // TODO: How to handle spoke shares? - issue 4626 shares and track balances through it
    spoke.suppliedShares += sharesAmount;

    _updateBorrowRate(asset, riskPremium, amount, 0);

    // TODO: fee-on-transfer
    assetsList[assetId].safeTransferFrom(supplier, address(this), amount);

    emit Supply(assetId, msg.sender, amount);

    return sharesAmount;
  }

  // TODO: Be able to pass max(uint) as amount to withdraw all or accept number of shares
  function withdraw(
    uint256 assetId,
    address to,
    uint256 amount,
    uint256 riskPremium
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = _assets[assetId];
    Spoke storage spoke = _spokes[assetId][msg.sender];

    // Accrue interest before validating action
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    _validateWithdraw(asset, spoke, amount);

    // TODO: Should this shares amount be from before or after accruing interest?
    uint256 sharesAmount = _convertToSharesDown(asset, amount);

    asset.suppliedShares -= sharesAmount;
    asset.availableLiquidity -= amount;

    _updateBorrowRate(asset, riskPremium, 0, amount);

    assetsList[assetId].safeTransfer(to, amount);

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

    Asset storage asset = _assets[assetId];
    Spoke storage spoke = _spokes[assetId][msg.sender];

    // Accrue interest before validating action
    _accrueAssetInterest(asset, asset.baseBorrowRate);
    _validateDraw(asset, amount, spoke.config.drawCap);

    asset.availableLiquidity -= amount;
    asset.debt += amount;

    // TODO: Properly handle spoke accounting
    spoke.debt += amount;

    _updateBorrowRate(asset, riskPremium, 0, amount);

    assetsList[assetId].safeTransfer(to, amount);

    emit Draw(assetId, msg.sender, to, amount);

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

    Asset storage asset = _assets[assetId];
    Spoke storage spoke = _spokes[assetId][msg.sender];

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
    assetsList[assetId].safeTransferFrom(repayer, address(this), amount);

    emit Restore(assetId, msg.sender, amount);

    return amount;
  }

  //
  // public
  //

  // TODO: gas optimize the conversions
  function convertToSharesUp(uint256 assetId, uint256 assets) external view returns (uint256) {
    Asset storage asset = _assets[assetId];
    return _convertToSharesUp(asset, assets);
  }

  function convertToSharesDown(uint256 assetId, uint256 assets) external view returns (uint256) {
    Asset storage asset = _assets[assetId];
    return _convertToSharesDown(asset, assets);
  }

  function convertToAssetsUp(uint256 assetId, uint256 shares) external view returns (uint256) {
    Asset storage asset = _assets[assetId];
    return _convertToAssetsUp(asset, shares);
  }

  function convertToAssetsDown(uint256 assetId, uint256 shares) external view returns (uint256) {
    Asset storage asset = _assets[assetId];
    return _convertToAssetsUp(asset, shares);
  }

  function getBaseInterestRate(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].baseBorrowRate;
  }

  function getInterestRate(uint256 assetId) public view returns (uint256) {
    Asset memory asset = _assets[assetId];
    return _getInterestRate(asset);
  }

  function getSpokeDrawnLiquidity(uint256 assetId, address spoke) public view returns (uint256) {
    return _spokes[assetId][spoke].debt;
  }

  function getTotalDrawnLiquidity(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].debt;
  }

  //
  // Internal
  //

  function _validateSupply(Asset storage asset, Spoke storage spoke, uint256 amount) internal view {
    require(assetsList[asset.id] != IERC20(address(0)), 'ASSET_NOT_LISTED');
    // TODO: Different states e.g. frozen, paused
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      spoke.config.supplyCap == type(uint256).max ||
        _convertToSharesDown(asset, spoke.suppliedShares) + amount <= spoke.config.supplyCap, // todo: exchange rate is incorrect, fix
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
      amount <= _convertToAssetsDown(asset, spoke.suppliedShares) - spoke.debt,
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
    if (elapsed == 0) return;

    // Update total cumulated base interest on outstanding debt
    uint256 totalDrawnBase = asset.debt;
    if (totalDrawnBase == 0) return; // No interest to accrue if no liquidity drawn
    uint256 cumulatedBase = totalDrawnBase.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, uint40(asset.lastUpdateTimestamp))
    ); // TODO rounding

    // Update outstanding base debt
    asset.debt = cumulatedBase;

    // Accrue total premium interest on the accrued base
    uint256 currentAccruedBase = cumulatedBase - totalDrawnBase;
    asset.outstandingPremium += currentAccruedBase.percentMul(wAvgBR[asset.id].spokeBR).fromRad();

    // Update base borrow index
    asset.baseBorrowIndex += asset.baseBorrowIndex.rayMul(asset.baseBorrowRate);

    // TODO: RF in terms of fee shares
    asset.lastUpdateTimestamp = block.timestamp;
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
          totalDebt: asset.debt, // TODO: Does total debt here need to include premium? no
          reserveFactor: 0, // TODO
          assetId: asset.id,
          virtualUnderlyingBalance: _getTotalAssets(asset),
          usingVirtualBalance: true
        })
      );

    _calculateWAvgRP(asset.id, newRiskPremium, _spokes[asset.id][msg.sender].debt);

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
    _spokes[assetId][spoke] = Spoke({
      suppliedShares: 0,
      debt: 0,
      outstandingPremium: 0,
      config: DataTypes.SpokeConfig(params.supplyCap, params.drawCap)
    });
    emit SpokeAdded(assetId, spoke);
  }

  // todo: pass cached memory reference like v3 in all of the below
  function _getInterestRate(Asset memory asset) internal pure returns (uint256) {
    return
      asset
        .baseBorrowRate
        .percentMul(PercentageMath.PERCENTAGE_FACTOR + asset.averageRiskPremiumRad)
        .fromRad(); // todo check for overflow, do fromRad before
  }

  function _getTotalAssets(Asset memory asset) internal pure returns (uint256) {
    return asset.availableLiquidity + asset.outstandingPremium + asset.debt;
  }

  function _convertToSharesUp(Asset memory asset, uint256 assets) internal pure returns (uint256) {
    return assets.toSharesUp(_getTotalAssets(asset), asset.suppliedShares);
  }

  function _convertToSharesDown(
    Asset memory asset,
    uint256 assets
  ) internal pure returns (uint256) {
    return assets.toSharesDown(_getTotalAssets(asset), asset.suppliedShares);
  }

  function _convertToAssetsUp(Asset memory asset, uint256 shares) internal pure returns (uint256) {
    return shares.toAssetsUp(_getTotalAssets(asset), asset.suppliedShares);
  }

  function _convertToAssetsDown(
    Asset memory asset,
    uint256 shares
  ) internal pure returns (uint256) {
    return shares.toAssetsDown(_getTotalAssets(asset), asset.suppliedShares);
  }
}
