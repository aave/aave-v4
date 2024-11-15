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

  event Supply(uint256 indexed reserve, address indexed spoke, uint256 amount);

  event Withdraw(
    uint256 indexed reserve,
    address indexed spoke,
    address indexed to,
    uint256 amount
  );

  event Draw(uint256 indexed reserve, address indexed to, uint256 amount);

  event Restore(uint256 indexed reserve, address indexed spoke, uint256 amount);

  struct SpokeConfig {
    uint256 drawCap;
    uint256 drawnLiquidity;
  }

  struct Reserve {
    uint256 id;
    uint256 totalShares;
    uint256 totalAssets;
    uint256 totalDrawn;
    uint256 lastUpdateTimestamp;
    uint256 currentBorrowRate;
    ReserveConfig config;
  }

  struct ReserveConfig {
    uint256 decimals;
    bool active; // TODO: frozen, paused
    uint256 supplyCap;
    address irStrategy;
  }

  // asset id => reserve data
  mapping(uint256 => Reserve) public reserves;
  address[] public reservesList; // TODO: Check if Enumerable or Set makes more sense
  uint256 public reserveCount;

  // asset id => spoke address => spoke config
  mapping(uint256 => mapping(address => SpokeConfig)) public spokeReserveConfigs;

  // asset id => weighted average risk premium of asset
  mapping(uint256 => uint256) public weightedAverageRiskPremium;

  function getReserve(uint256 assetId) external view returns (Reserve memory) {
    return reserves[assetId];
  }

  // TODO: convert all user-related functions to draw modules
  function getSpokeReserveConfig(
    uint256 assetId,
    address spoke
  ) external view returns (SpokeConfig memory) {
    return spokeReserveConfigs[assetId][spoke];
  }

  function getSpokeBalance(uint256 assetId, address spoke) external view returns (uint256) {
    SpokeConfig memory s = spokeReserveConfigs[assetId][spoke];

    return s.shares.toAssetsDown(reserves[assetId].totalAssets, reserves[assetId].totalShares);
  }

  // /////
  // Governance
  // /////

  function addReserve(ReserveConfig memory params, address asset) external {
    // TODO: AccessControl
    reservesList.push(asset);
    reserves[reserveCount] = Reserve({
      id: reserveCount,
      totalShares: 0,
      totalAssets: 0,
      totalDrawn: 0,
      lastUpdateTimestamp: block.timestamp,
      config: ReserveConfig({
        decimals: params.decimals,
        active: params.active,
        supplyCap: params.supplyCap,
        irStrategy: params.irStrategy
      })
    });
    reserveCount++;
  }

  function updateReserve(uint256 assetId, ReserveConfig memory params) external {
    // TODO: AccessControl
    reserves[assetId].config = ReserveConfig({
      decimals: params.decimals,
      active: params.active,
      supplyCap: params.supplyCap,
      irStrategy: params.irStrategy
    });
  }

  function updateSpokeConfig(uint256 assetId, address spoke, uint256 drawCap) external {
    // TODO: AccessControl
    spokeReserveConfigs[assetId][spoke].drawCap = drawCap;
  }

  // /////
  // Users
  // /////

  /// @dev risk premium is calculated from the borrow module and passed upon every action
  function supply(uint256 assetId, uint256 amount, uint256 riskPremium) external {
    Reserve storage reserve = reserves[assetId];
    SpokeConfig storage spoke = spokeReserveConfigs[assetId][msg.sender];

    _validateSupply(reserve, amount);

    // update indexes and IRs
    _updateState(reserve, spoke.drawnLiquidity, riskPremium, amount, 0);

    // TODO Mitigate inflation attack (burn some amount if first supply)

    uint256 sharesAmount = amount.toSharesDown(reserve.totalAssets, reserve.totalShares);
    require(sharesAmount > 0, 'INVALID_AMOUNT');

    reserve.totalShares += sharesAmount;
    reserve.totalAssets += amount;

    // TODO: fee-on-transfer
    IERC20(reservesList[assetId]).safeTransferFrom(msg.sender, address(this), amount);

    emit Supply(assetId, msg.sender, amount);
  }

  function withdraw(uint256 assetId, address to, uint256 amount, uint256 riskPremium) external {
    Reserve storage reserve = reserves[assetId];
    SpokeConfig storage spoke = spokeReserveConfigs[assetId][msg.sender];

    _validateWithdraw(reserve, amount);

    _updateState(reserve, spoke.drawnLiquidity, riskPremium, 0, amount);

    uint256 sharesAmount = amount.toSharesUp(reserve.totalAssets, reserve.totalShares);
    reserve.totalShares -= sharesAmount;
    reserve.totalAssets -= amount;

    IERC20(reservesList[assetId]).safeTransfer(to, amount);

    emit Withdraw(assetId, msg.sender, to, amount);
  }

  // TODO: authorization - only borrow module
  function draw(uint256 assetId, address to, uint256 amount, uint256 riskPremium) external {
    Reserve storage reserve = reserves[assetId];
    SpokeConfig spoke = spokeReserveConfigs[assetId][msg.sender];

    _validateDrawLiquidity(reserve, amount);

    _updateState(reserve, spoke.drawnLiquidity, riskPremium, 0, amount);

    reserve.totalDrawn += amount;

    IERC20(reservesList[assetId]).safeTransfer(to, amount);

    emit Draw(assetId, to, amount);
  }

  function restore(uint256 assetId, uint256 amount, uint256 riskPremium) external {
    Reserve storage reserve = reserves[assetId];
    SpokeConfig spoke = spokeReserveConfigs[assetId][msg.sender];

    _validateRestore(reserve, amount, spoke.drawnLiquidity);

    _updateState(reserve, spoke.drawnLiquidity, riskPremium, amount, 0);

    reserve.totalDrawn -= amount;

    IERC20(reservesList[assetId]).safeTransferFrom(msg.sender, address(this), amount);

    emit Restore(assetId, msg.sender, amount);
  }

  //
  // Internal
  //
  function _validateSupply(Reserve storage reserve, uint256 amount) internal view {
    require(reservesList[reserve.id] != address(0), 'ASSET_NOT_LISTED');
    // TODO: Different states e.g. frozen, paused
    require(reserve.config.active, 'RESERVE_NOT_ACTIVE');
    require(
      reserve.config.supplyCap == type(uint256).max ||
        reserve.totalAssets + amount <= reserve.config.supplyCap,
      'SUPPLY_CAP_EXCEEDED'
    );
  }

  function _validateWithdraw(Reserve storage reserve, uint256 amount) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(reserve.config.active, 'RESERVE_NOT_ACTIVE');

    // TODO: Check draw module is not withdrawing more than supplied

    require(amount <= reserve.totalAssets - reserve.totalDrawn, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateDrawLiquidity(Reserve storage reserve, uint256 amount) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(reserve.config.active, 'RESERVE_NOT_ACTIVE');
    require(
      reserve.config.drawCap == type(uint256).max ||
        amount + reserve.totalDrawn <= reserve.config.drawCap,
      'DRAW_CAP_EXCEEDED'
    );
    require(amount <= reserve.totalAssets - reserve.totalDrawn, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateRestore(
    Reserve storage reserve,
    uint256 amount,
    uint256 drawnLiquidity
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(reserve.config.active, 'RESERVE_NOT_ACTIVE');

    // Esnure draw module is not restoring more than supplied
    require(amount <= drawnLiquidity, 'INVALID_AMOUNT');
  }

  function _updateState(
    Reserve storage reserve,
    uint256 spokeDrawnLiquidity,
    uint256 newRiskPremium,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal {
    // Accrue interest with current borrow rate
    // TODO: Include RF calculation
    _accrueReserveInterest(reserve, reserve.currentBorrowRate);

    // Update interest rates
    uint256 borrowRate = IReserveInterestRateStrategy(reserve.config.irStrategy)
      .calculateInterestRates(
        DataTypes.CalculateInterestRatesParams({
          liquidityAdded: liquidityAdded,
          liquidityTaken: liquidityTaken,
          totalDebt: reserve.totalDrawn,
          reserveFactor: 0, // TODO
          assetId: reserve.id,
          virtualUnderlyingBalance: reserve.totalAssets,
          usingVirtualBalance: true
        })
      );

    borrowRate = _calculateWeightedInterestRate(borrowRate, newRiskPremium, spokeDrawnLiquidity);

    // Caching borrow rate for next accrual on action
    reserve.currentBorrowRate = borrowRate;
  }

  function _accrueReserveInterest(Reserve storage r, uint256 borrowRate) internal {
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
