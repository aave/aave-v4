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
  event Draw(uint256 indexed asset, address indexed to, uint256 amount);
  event Restore(uint256 indexed asset, address indexed spoke, uint256 amount);

  struct SpokeConfig {
    uint256 drawCap;
    uint256 drawnLiquidity;
  }

  struct Asset {
    uint256 id;
    uint256 totalShares;
    uint256 totalAssets;
    uint256 totalDrawn;
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

  // TODO: convert all user-related functions to draw modules
  function getSpokeAssetConfig(
    uint256 assetId,
    address spoke
  ) external view returns (SpokeConfig memory) {
    return spokeAssetConfigs[assetId][spoke];
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
      totalDrawn: 0,
      lastUpdateTimestamp: block.timestamp,
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

  /// @dev risk premium is calculated from the borrow module and passed upon every action
  function supply(uint256 assetId, uint256 amount, uint256 riskPremium) external {
    Asset storage asset = assets[assetId];
    SpokeConfig memory spoke = spokeAssetConfigs[assetId][msg.sender];

    _validateSupply(asset, amount);

    // update indexes and IRs
    _updateState(asset, spoke.drawnLiquidity, riskPremium, amount, 0);

    // TODO Mitigate inflation attack (burn some amount if first supply)

    uint256 sharesAmount = amount.toSharesDown(asset.totalAssets, asset.totalShares);
    require(sharesAmount > 0, 'INVALID_AMOUNT');

    asset.totalShares += sharesAmount;
    asset.totalAssets += amount;

    // TODO: fee-on-transfer
    IERC20(assetsList[assetId]).safeTransferFrom(msg.sender, address(this), amount);

    emit Supply(assetId, msg.sender, amount);
  }

  function withdraw(uint256 assetId, address to, uint256 amount, uint256 riskPremium) external {
    Asset storage asset = assets[assetId];
    SpokeConfig memory spoke = spokeAssetConfigs[assetId][msg.sender];

    _validateWithdraw(asset, amount);

    _updateState(asset, spoke.drawnLiquidity, riskPremium, 0, amount);

    uint256 sharesAmount = amount.toSharesUp(asset.totalAssets, asset.totalShares);
    asset.totalShares -= sharesAmount;
    asset.totalAssets -= amount;

    IERC20(assetsList[assetId]).safeTransfer(to, amount);

    emit Withdraw(assetId, msg.sender, to, amount);
  }

  // TODO: authorization - only borrow module
  function draw(uint256 assetId, address to, uint256 amount, uint256 riskPremium) external {
    Asset storage asset = assets[assetId];
    SpokeConfig memory spoke = spokeAssetConfigs[assetId][msg.sender];

    _validateDrawLiquidity(asset, amount);

    _updateState(asset, spoke.drawnLiquidity, riskPremium, 0, amount);

    asset.totalDrawn += amount;

    IERC20(assetsList[assetId]).safeTransfer(to, amount);

    emit Draw(assetId, to, amount);
  }

  function restore(uint256 assetId, uint256 amount, uint256 riskPremium) external {
    Asset storage asset = assets[assetId];
    SpokeConfig memory spoke = spokeAssetConfigs[assetId][msg.sender];

    _validateRestore(asset, amount, spoke.drawnLiquidity);

    _updateState(asset, spoke.drawnLiquidity, riskPremium, amount, 0);

    asset.totalDrawn -= amount;

    IERC20(assetsList[assetId]).safeTransferFrom(msg.sender, address(this), amount);

    emit Restore(assetId, msg.sender, amount);
  }

  //
  // Internal
  //
  function _validateSupply(Asset storage asset, uint256 amount) internal view {
    require(assetsList[asset.id] != address(0), 'ASSET_NOT_LISTED');
    // TODO: Different states e.g. frozen, paused
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      asset.config.supplyCap == type(uint256).max ||
        asset.totalAssets + amount <= asset.config.supplyCap,
      'SUPPLY_CAP_EXCEEDED'
    );
  }

  function _validateWithdraw(Asset storage asset, uint256 amount) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');

    // TODO: Check draw module is not withdrawing more than supplied

    require(amount <= asset.totalAssets - asset.totalDrawn, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateDrawLiquidity(Asset storage asset, uint256 amount) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      asset.config.drawCap == type(uint256).max ||
        amount + asset.totalDrawn <= asset.config.drawCap,
      'DRAW_CAP_EXCEEDED'
    );
    require(amount <= asset.totalAssets - asset.totalDrawn, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateRestore(
    Asset storage asset,
    uint256 amount,
    uint256 drawnLiquidity
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');

    // Esnure draw module is not restoring more than supplied
    require(amount <= drawnLiquidity, 'INVALID_AMOUNT');
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
          totalDebt: asset.totalDrawn,
          assetFactor: 0, // TODO
          assetId: asset.id,
          virtualUnderlyingBalance: asset.totalAssets,
          usingVirtualBalance: true
        })
      );

    borrowRate = _calculateWeightedInterestRate(borrowRate, newRiskPremium, spokeDrawnLiquidity);

    // Caching borrow rate for next accrual on action
    asset.currentBorrowRate = borrowRate;
  }

  function _accrueAssetInterest(Asset storage r, uint256 borrowRate) internal {
    uint256 elapsed = block.timestamp - r.lastUpdateTimestamp;
    if (elapsed > 0) {
      // linear interest
      uint256 cumulated = r.totalDrawn.rayMul(
        MathUtils.calculateLinearInterest(borrowRate, uint40(r.lastUpdateTimestamp))
      ); // TODO rounding
      console2.log(
        'cumulated: %e, drawn: %e, cumulatedInterest: %e',
        cumulated,
        r.totalDrawn,
        (cumulated - r.totalDrawn)
      );
      r.totalAssets += (cumulated - r.totalDrawn); // add delta, ie cumulated interest to totalAssets
      r.totalDrawn = cumulated;

      // TODO: RF in terms of fee shares
      r.lastUpdateTimestamp = block.timestamp;
    }
  }

  function _calculateWeightedInterestRate(uint256 borrowRate, uint256 newRiskPremium) internal {
    // TODO: Add new value risk premium to weighted average
    // TODO: Calculate final rate based on borrow rate and weighted average risk premium across borrow modules
  }
}
