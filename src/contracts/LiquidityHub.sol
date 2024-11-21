// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../dependencies/openzeppelin/IERC20.sol';
import {WadRayMath} from './WadRayMath.sol';
import {SharesMath} from './SharesMath.sol';
import {MathUtils} from './MathUtils.sol';
import {ILiquidityHub} from '../interfaces/ILiquidityHub.sol';
import {IReserveInterestRateStrategy} from '../interfaces/IReserveInterestRateStrategy.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';

import 'forge-std/console2.sol';

contract LiquidityHub is ILiquidityHub {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using SharesMath for uint256;

  struct Spoke {
    uint256 totalShares;
    uint256 drawnShares;
    // TODO: lastUpdateTimestamp?
    SpokeConfig config;
  }

  // TODO: borrow cap per spoke
  struct SpokeConfig {
    uint256 drawCap; // asset denominated
    uint256 supplyCap; // asset denominated
  }

  struct Asset {
    uint256 id;
    uint256 totalShares;
    uint256 totalAssets;
    uint256 drawnShares;
    uint256 lastUpdateTimestamp;
    uint256 currentBorrowRate;
    AssetConfig config;
  }

  struct AssetConfig {
    uint256 decimals;
    bool active; // TODO: frozen, paused
    address irStrategy;
  }

  // asset id => asset data
  mapping(uint256 => Asset) public assets;
  address[] public assetsList; // TODO: Check if Enumerable or Set makes more sense
  uint256 public assetCount;

  // asset id => spoke address => spoke
  mapping(uint256 => mapping(address => Spoke)) public spokes;

  // asset id => weighted average risk premium of asset
  mapping(uint256 => uint256) public weightedAverageRiskPremium;

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
  ) external view returns (SpokeConfig memory) {
    return spokes[assetId][spoke].config;
  }

  /**
   * @param assetId The asset id
   * @return The total balance of a given asset, either in shares or in assets
   */
  function updateAndGetAssetBalance(uint256 assetId) external returns (uint256) {
    Asset storage asset = assets[assetId];
    _accrueAssetInterest(asset, asset.currentBorrowRate);
    return asset.totalAssets;
  }

  function updateAndGetShareBalance(uint256 assetId) external returns (uint256) {
    Asset storage asset = assets[assetId];
    _accrueAssetInterest(asset, asset.currentBorrowRate);
    return asset.totalShares;
  }

  // /////
  // Governance
  // /////

  function addAsset(AssetConfig memory params, address asset) external {
    // TODO: AccessControl
    assetsList.push(asset);
    assets[assetCount] = Asset({
      id: assetCount,
      totalShares: 0,
      totalAssets: 0,
      drawnShares: 0,
      lastUpdateTimestamp: block.timestamp,
      currentBorrowRate: 0,
      config: AssetConfig({
        decimals: params.decimals,
        active: params.active,
        irStrategy: params.irStrategy
      })
    });
    assetCount++;
  }

  function updateAssetConfig(uint256 assetId, AssetConfig memory params) external {
    // TODO: AccessControl
    assets[assetId].config = AssetConfig({
      decimals: params.decimals,
      active: params.active,
      irStrategy: params.irStrategy
    });
  }

  function addSpoke(uint256 assetId, SpokeConfig memory params, address spoke) external {
    // TODO: AccessControl
    spokes[assetId][spoke] = Spoke({
      totalShares: 0,
      drawnShares: 0,
      config: SpokeConfig({supplyCap: params.supplyCap, drawCap: params.drawCap})
    });
  }
  function updateSpokeConfig(uint256 assetId, address spoke, SpokeConfig memory params) external {
    // TODO: AccessControl
    spokes[assetId][spoke].config = SpokeConfig({
      drawCap: params.drawCap,
      supplyCap: params.supplyCap
    });
  }

  // /////
  // Users
  // /////

  /// @dev risk premium is calculated from the spoke and passed upon every action
  function supply(uint256 assetId, uint256 amount, uint256 riskPremium) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = assets[assetId];
    Spoke storage spoke = spokes[assetId][msg.sender];

    // Update indexes and IRs
    _updateState(asset, spoke.drawnShares, riskPremium, amount, 0);
    _validateSupply(asset, spoke, amount);

    // TODO Mitigate inflation attack (burn some amount if first supply)
    uint256 sharesAmount = convertAssetsToShares(assetId, amount, false);
    require(sharesAmount > 0, 'INVALID_AMOUNT');

    asset.totalShares += sharesAmount;
    asset.totalAssets += amount;
    spoke.totalShares += sharesAmount;

    // TODO: fee-on-transfer
    // TODO: should this be transferred from the originating user instead of the spoke?
    IERC20(assetsList[assetId]).safeTransferFrom(msg.sender, address(this), amount);

    emit Supply(assetId, msg.sender, amount);

    return sharesAmount;
  }

  function withdraw(
    uint256 assetId,
    address to,
    uint256 amount,
    uint256 riskPremium
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = assets[assetId];
    Spoke storage spoke = spokes[assetId][msg.sender];

    _updateState(asset, spoke.drawnShares, riskPremium, 0, amount);
    _validateWithdraw(asset, spoke, amount);

    uint256 sharesAmount = convertAssetsToShares(assetId, amount, false);
    asset.totalShares -= sharesAmount;
    asset.totalAssets -= amount;
    spoke.totalShares -= sharesAmount;

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

    _updateState(asset, spoke.drawnShares, riskPremium, 0, amount);
    _validateDraw(asset, amount, spoke.config.drawCap);

    uint256 sharesAmount = convertAssetsToShares(assetId, amount, true);
    asset.drawnShares += sharesAmount;
    spoke.drawnShares += sharesAmount;

    IERC20(assetsList[assetId]).safeTransfer(to, amount);

    emit Draw(assetId, msg.sender, to, amount);

    return sharesAmount;
  }

  function restore(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremium
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = assets[assetId];
    Spoke storage spoke = spokes[assetId][msg.sender];

    _updateState(asset, spoke.drawnShares, riskPremium, amount, 0);
    uint256 sharesAmount = convertAssetsToShares(assetId, amount, false);
    _validateRestore(asset, sharesAmount, spoke.drawnShares);

    asset.drawnShares -= sharesAmount;
    spoke.drawnShares -= sharesAmount;

    // TODO: should this be transferred from the originating user instead of the spoke?
    IERC20(assetsList[assetId]).safeTransferFrom(msg.sender, address(this), amount);

    emit Restore(assetId, msg.sender, amount);

    return sharesAmount;
  }

  //
  // public
  //

  function convertAssetsToShares(
    uint256 assetId,
    uint256 amount,
    bool roundUp
  ) public view returns (uint256) {
    return
      roundUp
        ? amount.toSharesUp(assets[assetId].totalAssets, assets[assetId].totalShares)
        : amount.toSharesDown(assets[assetId].totalAssets, assets[assetId].totalShares);
  }

  function convertSharesToAssets(
    uint256 assetId,
    uint256 amount,
    bool roundUp
  ) public view returns (uint256) {
    return
      roundUp
        ? amount.toAssetsUp(assets[assetId].totalAssets, assets[assetId].totalShares)
        : amount.toAssetsDown(assets[assetId].totalAssets, assets[assetId].totalShares);
  }

  function getBaseInterestRate(uint256 assetId) public view returns (uint256) {
    return assets[assetId].currentBorrowRate;
  }

  // TODO: separate getter method for final IR that incorporates risk premium

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
        convertAssetsToShares(asset.id, spoke.totalShares, false) + amount <=
        spoke.config.supplyCap,
      'SUPPLY_CAP_EXCEEDED'
    );
  }

  function _validateWithdraw(
    Asset storage asset,
    Spoke storage spoke,
    uint256 amount
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      amount <= convertSharesToAssets(asset.id, (spoke.totalShares - spoke.drawnShares), false),
      'SUPPLIED_AMOUNT_EXCEEDED'
    );
    require(
      amount <= asset.totalAssets - convertSharesToAssets(asset.id, asset.drawnShares, true),
      'NOT_AVAILABLE_LIQUIDITY'
    );
  }

  function _validateDraw(Asset storage asset, uint256 amount, uint256 drawCap) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    uint256 drawnAssets = convertSharesToAssets(asset.id, asset.drawnShares, true);
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

    // Esnure spoke is not restoring more than supplied
    require(sharesAmount <= drawnShares, 'INVALID_RESTORE_AMOUNT');
  }

  function _updateState(
    Asset storage asset,
    uint256 spokeDrawnLiquidity,
    uint256 newRiskPremium,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal {
    // Accrue interest with current borrow rate
    // TODO: Include RF calculation
    _accrueAssetInterest(asset, asset.currentBorrowRate);

    // Update interest rates
    uint256 borrowRate = IReserveInterestRateStrategy(asset.config.irStrategy)
      .calculateInterestRates(
        DataTypes.CalculateInterestRatesParams({
          liquidityAdded: liquidityAdded,
          liquidityTaken: liquidityTaken,
          totalDebt: convertSharesToAssets(asset.id, asset.drawnShares, true),
          reserveFactor: 0, // TODO
          assetId: asset.id,
          virtualUnderlyingBalance: asset.totalAssets,
          usingVirtualBalance: true
        })
      );
    // TODO: This function should take into account the new risk premium - probably done already by borrow module
    borrowRate = _calculateWeightedInterestRate(borrowRate, newRiskPremium, spokeDrawnLiquidity);

    // Caching borrow rate for next accrual on action
    asset.currentBorrowRate = borrowRate;
  }

  function _accrueAssetInterest(Asset storage asset, uint256 borrowRate) internal {
    uint256 elapsed = block.timestamp - asset.lastUpdateTimestamp;
    if (elapsed > 0) {
      // linear interest
      uint256 totalDrawn = convertSharesToAssets(asset.id, asset.drawnShares, false);
      uint256 cumulated = totalDrawn.rayMul(
        MathUtils.calculateLinearInterest(borrowRate, uint40(asset.lastUpdateTimestamp))
      ); // TODO rounding
      console2.log(
        'cumulated: %e, drawn: %e, cumulatedInterest: %e',
        cumulated,
        totalDrawn,
        (cumulated - totalDrawn)
      );
      asset.totalAssets += (cumulated - totalDrawn); // add delta, ie cumulated interest to totalAssets
      asset.drawnShares = cumulated.toSharesDown(asset.totalAssets, asset.totalShares);

      // TODO: RF in terms of fee shares
      asset.lastUpdateTimestamp = block.timestamp;
    }
  }

  function _calculateWeightedInterestRate(
    uint256 borrowRate,
    uint256 newRiskPremium,
    uint256 spokeDrawnLiquidity
  ) internal returns (uint256) {
    // TODO: Add new value risk premium to weighted average
    // TODO: Calculate final rate based on borrow rate and weighted average risk premium across spokes
  }
}
