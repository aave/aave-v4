// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '../dependencies/openzeppelin/IERC20.sol';
import {SafeERC20} from '../dependencies/openzeppelin/SafeERC20.sol';
import {LiquidityHub} from './LiquidityHub.sol';
import {IPriceOracle} from './IPriceOracle.sol';
import {WadRayMath} from './WadRayMath.sol';
import {SharesMath} from './SharesMath.sol';
import {BorrowModule} from './BorrowModule.sol';

import 'forge-std/console2.sol';

library LiquidationLogic {
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using SafeERC20 for IERC20;

  struct LiquidationCallLocalVars {
    uint256 actualDebtToCover;
    uint256 actualCollateralToLiquidate;
  }

  struct CalculateUserAccountDataVars {
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 reserveCount;
    uint256 assetId;
    uint256 avgLiquidationThreshold;
    uint256 userBalanceInBaseCurrency;
  }

  /**
   * @dev allow the liquidator to liquidate enough assets so the HF goes back to this value
   * TODO: decide is this a constant, or adjustable (via governance)
   */
  uint256 public constant HEALTH_FACTOR_LIQUIDATABLE_THRESHOLD = 1e18;
  // TODO: Minimum health factor allowed under any circumstance
  uint256 public constant MINIMUM_HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 0.95e18;
  /**
   * @dev Minimum health factor to consider a user position healthy
   * A value of 1e18 results in 1
   */
  uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;

  event LiquidationCall(
    uint256 indexed collateralAssetId,
    uint256 indexed debtAssetId,
    address indexed user,
    uint256 debtToCover,
    uint256 liquidatedCollateralAmount,
    address liquidator
  );

  // TODO: refactor input params to use a struct
  function executeLiquidationCall(
    mapping(uint256 => LiquidityHub.Reserve) storage reserves,
    address[] storage reservesList,
    mapping(uint256 => mapping(address => LiquidityHub.UserConfig)) storage users,
    uint256 debtToCover,
    uint256 collateralAssetId,
    uint256 debtAssetId,
    address user,
    address oracle
  ) external {
    // V3 implementation to liquidate undercollateralized positions to start out with.
    // In addition, instead of allowing the liquidator to liquidate up to 50% if HF goes below certain threshold
    // we want allow the liquidator to liquidate enough assets so the HF goes back to 1 (or slightly higher).
    // make sure to account for liquidation bonus in calculating the amount liquidatable

    LiquidationCallLocalVars memory vars;

    LiquidityHub.Reserve storage collateralReserve = reserves[collateralAssetId];
    LiquidityHub.Reserve storage debtReserve = reserves[debtAssetId];

    // TODO: check if user is undercollateralized. Get HF
    uint256 healthFactor = _calculateUserAccountData(reserves, reservesList, users, user, oracle);

    _validateLiquidationCall(collateralReserve, debtReserve, 0); // TODO: involve healthFactor, hardcode 0 for now
    // TODO: calculate the total debt of the user and the actual amount to liquidate depending on the health factor
    _calculateDebt();

    //TODO: calculate how much debt to liquidate to get health factor back to HEALTH_FACTOR_LIQUIDATABLE_THRESHOLD
    vars.actualDebtToCover = debtToCover; // TODO: actualDebtToLiquidate
    // vars.actualDebtToCover = debtToCover > vars.actualDebtToCover
    //   ? vars.actualDebtToCover
    //   : debtToCover;
    // TODO: calculate how much of a specific collateral can be liquidated, given a certain amount of debt asset
    // TODO: account for liquidation bonus, protocol liquidation fee

    // TODO: pay off debt to debtReserve in liq hub, where debt asset is stored
    IERC20(reservesList[debtAssetId]).safeTransferFrom(
      msg.sender,
      address(this), // liq hub
      vars.actualDebtToCover
    );
    // TODO: update user's debt balance
    // TODO: transfer collateral to liquidator
    IERC20(reservesList[collateralAssetId]).safeTransfer(
      msg.sender,
      vars.actualCollateralToLiquidate
    );

    emit LiquidationCall(
      collateralAssetId,
      debtAssetId,
      user,
      vars.actualDebtToCover, // TODO: actualDebtToLiquidate
      vars.actualCollateralToLiquidate, // TODO: liquidatedCollateralAmount
      msg.sender
    );
  }

  function _validateLiquidationCall(
    LiquidityHub.Reserve memory collateralReserve,
    LiquidityHub.Reserve memory debtReserve,
    uint256 healthFactor
  ) internal view {
    require(debtReserve.config.active && collateralReserve.config.active, 'RESERVE_NOT_ACTIVE');
    require(!debtReserve.config.paused && !collateralReserve.config.paused, 'RESERVE_PAUSED');
    require(
      healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      'HEALTH_FACTOR_NOT_BELOW_THRESHOLD'
    );
  }

  function _calculateUserAccountData(
    mapping(uint256 => LiquidityHub.Reserve) storage reserves,
    address[] storage reservesList,
    mapping(uint256 => mapping(address => LiquidityHub.UserConfig)) storage users,
    address user,
    address oracle
  ) internal view returns (uint256) {
    // TODO: calculate user account data, including health factor
    // if no debt, then health factor is type(uint256).max
    // TODO: emode config logic

    CalculateUserAccountDataVars memory vars;

    vars.reserveCount = reservesList.length;
    // loop thru all reserves
    while (vars.assetId < vars.reserveCount) {
      if (!_isUsingAsCollateralOrBorrowing(vars.assetId)) {
        ++vars.assetId;
        continue;
      }

      LiquidityHub.Reserve storage currentReserve = reserves[vars.assetId];
      (, , , , , BorrowModule.ReserveConfig memory reserveConfig) = BorrowModule(
        currentReserve.config.borrowModule
      ).reserves(vars.assetId); // TODO: liquidation threshold, get it from proper reserve

      uint256 decimals = currentReserve.config.decimals;
      uint256 assetUnit = 10 ** decimals;

      address currentReserveAddress = reservesList[vars.assetId];
      uint256 assetPrice = IPriceOracle(oracle).getAssetPrice(vars.assetId);
      vars.userBalanceInBaseCurrency = _getUserBalanceInBaseCurrency(
        users[vars.assetId][user],
        currentReserve,
        assetPrice,
        assetUnit
      );
      vars.totalCollateralInBaseCurrency += vars.userBalanceInBaseCurrency;

      if (_isBorrowing(vars.assetId)) {
        vars.totalDebtInBaseCurrency += _getUserDebtInBaseCurrency(
          user,
          currentReserve,
          assetPrice,
          assetUnit
        );
      }

      vars.avgLiquidationThreshold += vars.userBalanceInBaseCurrency * reserveConfig.lt;
      ++vars.assetId;
    }

    vars.avgLiquidationThreshold = vars.totalCollateralInBaseCurrency != 0
      ? vars.avgLiquidationThreshold / vars.totalCollateralInBaseCurrency
      : 0;

    // TODO: hf calc: (collateralValue * avg liquidation threshold) / debt
    // use base currencies
    uint256 healthFactor = (vars.totalDebtInBaseCurrency == 0)
      ? type(uint256).max
      : (vars.totalCollateralInBaseCurrency * vars.avgLiquidationThreshold).wadDiv(
        vars.totalDebtInBaseCurrency
      );
    // console2.log('HF calcs, totalDebtInBaseCurrency:', vars.totalDebtInBaseCurrency);

    return healthFactor;
  }

  // TODO
  function _isUsingAsCollateral(uint256 assetId) internal view returns (bool) {
    return true;
  }

  // TODO
  function _isBorrowing(uint256 assetId) internal view returns (bool) {
    return true;
  }

  // TODO is a given asset being used as collateral or being borrowed?
  function _isUsingAsCollateralOrBorrowing(uint256 assetId) internal view returns (bool) {
    return _isUsingAsCollateral(assetId) || _isBorrowing(assetId);
  }

  // TODO
  function _getUserDebtInBaseCurrency(
    address user,
    LiquidityHub.Reserve storage reserve,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    (uint256 principalBalance, uint256 interestBalance, , ) = BorrowModule(
      reserve.config.borrowModule
    ).users(reserve.id, user);
    uint256 userTotalDebt = principalBalance + interestBalance;
    userTotalDebt *= assetPrice;
    // console2.log('userTotalDebt:', userTotalDebt);
    return userTotalDebt / assetUnit;
  }

  // TODO
  function _getUserBalanceInBaseCurrency(
    LiquidityHub.UserConfig storage user,
    LiquidityHub.Reserve storage reserve,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    uint256 userAssets = reserve.totalShares != 0
      ? (user.shares.toAssetsDown(reserve.totalAssets, reserve.totalShares) * assetPrice)
      : 0;
    return userAssets / assetUnit;
  }

  // TODO
  function _calculateDebt() internal pure returns (uint256) {}
}
