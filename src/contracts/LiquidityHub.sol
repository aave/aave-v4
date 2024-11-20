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

  event Supply(uint256 indexed asset, address indexed spoke, uint256 amount);
  event Withdraw(uint256 indexed asset, address indexed spoke, address indexed to, uint256 amount);
  event Draw(uint256 indexed asset, address indexed spoke, address indexed to, uint256 amount);
  event Restore(uint256 indexed asset, address indexed spoke, uint256 amount);

  // TODO: borrow cap per spoke
  struct SpokeConfig {
    uint256 drawCap; // asset denominated
    uint256 drawnShares;
    uint256 supplyCap; // asset denominated
    uint256 shares;
  }

  struct Asset {
    uint256 id;
    uint256 totalShares;
    uint256 totalAssets; // TODO: does totalAssets include drawn liquidity?
    uint256 totalDrawnShares;
    uint256 lastUpdateTimestamp;
    uint256 currentBorrowRate;
    AssetConfig config;
  }

  struct AssetConfig {
    uint256 decimals;
    bool active; // TODO: frozen, paused
    uint256 supplyCap;
    address irStrategy;
  }

  // asset id => asset data
  mapping(uint256 => Asset) public assets;
  address[] public assetsList; // TODO: Check if Enumerable or Set makes more sense
  uint256 public assetCount;

  // asset id => spoke address => spoke config
  mapping(uint256 => mapping(address => SpokeConfig)) public spokeAssetConfigs;

  // asset id => weighted average risk premium of asset
  mapping(uint256 => uint256) public weightedAverageRiskPremium;

  function getAsset(uint256 assetId) external view returns (Asset memory) {
    return assets[assetId];
  }

  function getSpokeDrawnLiquidity(uint256 assetId, address spoke) public view returns (uint256) {
    return
      spokeAssetConfigs[assetId][spoke].drawnShares.toAssetsUp(
        assets[assetId].totalAssets,
        assets[assetId].totalShares
      );
  }

  function getTotalDrawnLiquidity(uint256 assetId) public view returns (uint256) {
    return
      assets[assetId].totalDrawnShares.toAssetsUp(
        assets[assetId].totalAssets,
        assets[assetId].totalShares
      );
  }

  function getSpokeAssetConfig(
    uint256 assetId,
    address spoke
  ) external view returns (SpokeConfig memory) {
    return spokeAssetConfigs[assetId][spoke];
  }

  function getInterestRate(uint256 assetId) public view returns (uint256) {
    return assets[assetId].currentBorrowRate;
  }

  /**
   * @param assetId The asset id
   * @return The total balance of a given asset
   */
  function getUpdatedAssetBalance(uint256 assetId) external returns (uint256) {
    Asset storage asset = assets[assetId];
    _accrueAssetInterest(asset, asset.currentBorrowRate);
    return asset.totalAssets;
  }

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
  ) external view returns (uint256) {
    return
      roundUp
        ? amount.toAssetsUp(assets[assetId].totalAssets, assets[assetId].totalShares)
        : amount.toAssetsDown(assets[assetId].totalAssets, assets[assetId].totalShares);
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
      totalDrawnShares: 0,
      lastUpdateTimestamp: block.timestamp,
      currentBorrowRate: 0,
      config: AssetConfig({
        decimals: params.decimals,
        active: params.active,
        supplyCap: params.supplyCap,
        irStrategy: params.irStrategy
      })
    });
    assetCount++;
  }

  function updateAsset(uint256 assetId, AssetConfig memory params) external {
    // TODO: AccessControl
    assets[assetId].config = AssetConfig({
      decimals: params.decimals,
      active: params.active,
      supplyCap: params.supplyCap,
      irStrategy: params.irStrategy
    });
  }

  function updateSpokeConfig(uint256 assetId, address spoke, uint256 drawCap) external {
    // TODO: AccessControl
    spokeAssetConfigs[assetId][spoke].drawCap = drawCap;
  }

  // /////
  // Users
  // /////

  /// @dev risk premium is calculated from the spoke and passed upon every action
  function supply(uint256 assetId, uint256 amount, uint256 riskPremium) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = assets[assetId];
    SpokeConfig storage spoke = spokeAssetConfigs[assetId][msg.sender];

    _validateSupply(asset, spoke, amount);
    // Update indexes and IRs
    _updateState(asset, spoke.drawnShares, riskPremium, amount, 0);

    // TODO Mitigate inflation attack (burn some amount if first supply)
    uint256 sharesAmount = convertAssetsToShares(assetId, amount, false);
    require(sharesAmount > 0, 'INVALID_AMOUNT');

    asset.totalShares += sharesAmount;
    asset.totalAssets += amount;
    spoke.shares += sharesAmount;

    // TODO: fee-on-transfer
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
    SpokeConfig storage spoke = spokeAssetConfigs[assetId][msg.sender];

    _validateWithdraw(asset, spoke, amount);
    _updateState(asset, spoke.drawnShares, riskPremium, 0, amount);

    uint256 sharesAmount = convertAssetsToShares(assetId, amount, false);
    asset.totalShares -= sharesAmount;
    asset.totalAssets -= amount;
    spoke.shares -= sharesAmount;

    IERC20(assetsList[assetId]).safeTransfer(to, amount);

    emit Withdraw(assetId, msg.sender, to, amount);

    return sharesAmount;
  }

  function draw(
    uint256 assetId,
    address onBehalfOf,
    uint256 amount,
    uint256 riskPremium
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = assets[assetId];
    SpokeConfig storage spoke = spokeAssetConfigs[assetId][msg.sender];

    _validateDraw(asset, amount, spoke.drawCap);
    _updateState(asset, spoke.drawnShares, riskPremium, 0, amount);

    uint256 sharesAmount = convertAssetsToShares(assetId, amount, true);
    asset.totalDrawnShares += sharesAmount;
    spoke.drawnShares += sharesAmount;

    IERC20(assetsList[assetId]).safeTransfer(onBehalfOf, amount);

    emit Draw(assetId, msg.sender, onBehalfOf, amount);

    return sharesAmount;
  }

  function restore(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremium
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = assets[assetId];
    SpokeConfig storage spoke = spokeAssetConfigs[assetId][msg.sender];

    uint256 sharesAmount = convertAssetsToShares(assetId, amount, false);
    _validateRestore(asset, sharesAmount, spoke.drawnShares);
    _updateState(asset, spoke.drawnShares, riskPremium, amount, 0);

    asset.totalDrawnShares -= sharesAmount;
    spoke.drawnShares -= sharesAmount;

    IERC20(assetsList[assetId]).safeTransferFrom(msg.sender, address(this), amount);

    emit Restore(assetId, msg.sender, amount);

    return sharesAmount;
  }

  //
  // Internal
  //

  function _validateSupply(
    Asset storage asset,
    SpokeConfig storage spokeConfig,
    uint256 amount
  ) internal view {
    require(assetsList[asset.id] != address(0), 'ASSET_NOT_LISTED');
    // TODO: Different states e.g. frozen, paused
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      spokeConfig.supplyCap == type(uint256).max ||
        asset.totalAssets + amount <= spokeConfig.supplyCap,
      'SUPPLY_CAP_EXCEEDED'
    );
  }

  function _validateWithdraw(
    Asset storage asset,
    SpokeConfig storage spoke,
    uint256 amount
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');

    require(
      amount.toSharesDown(asset.totalAssets, asset.totalShares) <= spoke.drawnShares,
      'INVALID_AMOUNT'
    );

    require(
      amount <=
        asset.totalAssets - asset.totalDrawnShares.toAssetsUp(asset.totalAssets, asset.totalShares),
      'NOT_AVAILABLE_LIQUIDITY'
    );
  }

  function _validateDraw(Asset storage asset, uint256 amount, uint256 drawCap) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      drawCap == type(uint256).max ||
        amount + asset.totalDrawnShares.toAssetsUp(asset.totalAssets, asset.totalShares) <= drawCap,
      'DRAW_CAP_EXCEEDED'
    );
    require(
      amount <=
        asset.totalAssets - asset.totalDrawnShares.toAssetsUp(asset.totalAssets, asset.totalShares),
      'NOT_AVAILABLE_LIQUIDITY'
    );
  }

  function _validateRestore(
    Asset storage asset,
    uint256 sharesAmount,
    uint256 drawnShares
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');

    // Esnure spoke is not restoring more than supplied
    require(sharesAmount <= drawnShares, 'INVALID_AMOUNT');
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
          totalDebt: asset.totalDrawnShares.toAssetsUp(asset.totalAssets, asset.totalShares),
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

  function _accrueAssetInterest(Asset storage r, uint256 borrowRate) internal {
    uint256 elapsed = block.timestamp - r.lastUpdateTimestamp;
    if (elapsed > 0) {
      // linear interest
      uint256 totalDrawn = r.totalDrawnShares.toAssetsDown(r.totalAssets, r.totalShares);
      uint256 cumulated = totalDrawn.rayMul(
        MathUtils.calculateLinearInterest(borrowRate, uint40(r.lastUpdateTimestamp))
      ); // TODO rounding
      console2.log(
        'cumulated: %e, drawn: %e, cumulatedInterest: %e',
        cumulated,
        totalDrawn,
        (cumulated - totalDrawn)
      );
      r.totalAssets += (cumulated - totalDrawn); // add delta, ie cumulated interest to totalAssets
      r.totalDrawnShares = cumulated.toSharesDown(r.totalAssets, r.totalShares);

      // TODO: RF in terms of fee shares
      r.lastUpdateTimestamp = block.timestamp;
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
