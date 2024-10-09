// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '../dependencies/openzeppelin/IERC20.sol';
import {SafeERC20} from '../dependencies/openzeppelin/SafeERC20.sol';
import {LiquidityHub} from './LiquidityHub.sol';
import {IPriceOracle} from './IPriceOracle.sol';
import {WadRayMath} from './WadRayMath.sol';
import {SharesMath} from './SharesMath.sol';
import {PercentageMath} from './PercentageMath.sol';
import {BorrowModule} from './BorrowModule.sol';

import 'forge-std/console2.sol';

library LiquidationLogic {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using SafeERC20 for IERC20;

  struct LiquidationCallLocalVars {
    uint256 actualDebtToCover;
    uint256 actualCollateralToLiquidate;
    uint256 actualDebtToLiquidate;
    uint256 liquidationProtocolFeeAmount;
    uint256 userCollateralBalance;
    uint256 userDebtBalance;
    uint256 healthFactor;
    uint256 maxDebtToCover;
  }

  struct CalculateUserAccountDataVars {
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 reserveCount;
    uint256 assetId;
    uint256 avgLiquidationThreshold;
    uint256 userBalanceInBaseCurrency;
  }

  struct AvailableCollateralToLiquidateLocalVars {
    uint256 collateralAssetPrice;
    uint256 debtAssetPrice;
    uint256 collateralAssetUnit;
    uint256 debtAssetUnit;
    uint256 liquidationProtocolFeePercentage;
    uint256 baseCollateral;
    uint256 maxCollateralToLiquidate;
    uint256 collateralAmount;
    uint256 debtAmountNeeded;
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

    require(debtToCover > 0, 'INVALID_DEBT_TO_COVER');

    LiquidationCallLocalVars memory vars;

    LiquidityHub.Reserve storage collateralReserve = reserves[collateralAssetId];
    LiquidityHub.Reserve storage debtReserve = reserves[debtAssetId];

    uint256 healthFactor = _calculateUserAccountData(reserves, reservesList, users, user, oracle);

    // TODO: check if user has HF below threshold
    _validateLiquidationCall(collateralReserve, debtReserve, user, 0); // TODO: involve healthFactor, hardcode 0 for now
    vars.userDebtBalance = BorrowModule(debtReserve.config.borrowModule).getUserDebt(
      debtReserve.id,
      user
    );
    vars.userCollateralBalance = LiquidityHub(address(this)).getUserBalance(
      collateralAssetId,
      user
    );

    vars.actualDebtToCover = debtToCover > vars.userDebtBalance
      ? vars.userDebtBalance
      : debtToCover;

    // TODO: calculate how much of a specific collateral can be liquidated, given a certain amount of debt asset
    // TODO: account for liquidation bonus, protocol liquidation fee

    console2.log(
      'vars.userCollateralBalance',
      vars.userCollateralBalance,
      'vars.actualDebtToCover',
      vars.actualDebtToCover
    );
    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = _calculateAvailableCollateralToLiquidate(
      collateralReserve,
      debtReserve,
      oracle,
      vars.actualDebtToCover,
      vars.userCollateralBalance,
      10_000 // TODO: liquidation bonus
    );

    IERC20(reservesList[debtAssetId]).safeTransferFrom(
      msg.sender,
      address(this), // liq hub
      vars.actualDebtToLiquidate
    );
    IERC20(reservesList[collateralAssetId]).safeTransfer(
      msg.sender,
      vars.actualCollateralToLiquidate
    );
    // TODO: update interest rates, etc. for the reserves
    // TODO: update user's collateral balance

    // console2.log(
    //   'vars.actualDebtToLiquidate',
    //   vars.actualDebtToLiquidate,
    //   'vars.actualCollateralToLiquidate',
    //   vars.actualCollateralToLiquidate
    // );

    emit LiquidationCall(
      collateralAssetId,
      debtAssetId,
      user,
      vars.actualDebtToLiquidate, // TODO: actualDebtToLiquidate
      vars.actualCollateralToLiquidate, // TODO: liquidatedCollateralAmount
      msg.sender
    );
  }

  function _calculateAvailableCollateralToLiquidate(
    LiquidityHub.Reserve memory collateralReserve,
    LiquidityHub.Reserve memory debtReserve,
    address oracle,
    uint256 debtToCover,
    uint256 userCollateralBalance,
    uint256 liquidationBonus
  ) internal view returns (uint256, uint256, uint256) {
    AvailableCollateralToLiquidateLocalVars memory vars;

    vars.collateralAssetPrice = IPriceOracle(oracle).getAssetPrice(collateralReserve.id);
    vars.debtAssetPrice = IPriceOracle(oracle).getAssetPrice(debtReserve.id);

    vars.collateralAssetUnit = 10 ** collateralReserve.config.decimals;
    vars.debtAssetUnit = 10 ** debtReserve.config.decimals;

    vars.liquidationProtocolFeePercentage = (
      BorrowModule(collateralReserve.config.borrowModule).getReserve(collateralReserve.id)
    ).config.lb;

    vars.baseCollateral =
      (vars.debtAssetPrice * debtToCover * vars.collateralAssetUnit) /
      (vars.collateralAssetPrice * vars.debtAssetUnit);

    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(liquidationBonus);

    // console2.log('vars.baseCollateral:', vars.baseCollateral);
    // console2.log(
    //   'vars.maxCollateralToLiquidate:',
    //   vars.maxCollateralToLiquidate,
    //   'userCollateralBalance',
    //   userCollateralBalance
    // );

    // if the calculated maxCollateralToLiquidate (based on debt) is higher than the user's collateral balance,
    // liquidate the max possible - userCollateralBalance
    if (vars.maxCollateralToLiquidate > userCollateralBalance) {
      console2.log('maxCollateralToLiquidate > userCollateralBalance');
      vars.collateralAmount = userCollateralBalance;
      vars.debtAmountNeeded = ((vars.collateralAssetPrice *
        vars.collateralAmount *
        vars.debtAssetUnit) / (vars.debtAssetPrice * vars.collateralAssetUnit)).percentDiv(
          liquidationBonus
        );
    } else {
      console2.log('maxCollateralToLiquidate <= userCollateralBalance');
      vars.collateralAmount = vars.maxCollateralToLiquidate;
      vars.debtAmountNeeded = debtToCover;
    }

    // TODO: logic for liquidationProtocolFeePercentage
    return (vars.collateralAmount, vars.debtAmountNeeded, 0);
  }

  function _validateLiquidationCall(
    LiquidityHub.Reserve memory collateralReserve,
    LiquidityHub.Reserve memory debtReserve,
    address user,
    uint256 healthFactor
  ) internal view {
    require(debtReserve.config.active && collateralReserve.config.active, 'RESERVE_NOT_ACTIVE');
    require(!debtReserve.config.paused && !collateralReserve.config.paused, 'RESERVE_PAUSED');
    require(
      healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      'HEALTH_FACTOR_NOT_BELOW_THRESHOLD'
    );
    require(
      BorrowModule(debtReserve.config.borrowModule).getUserDebt(debtReserve.id, user) > 0,
      'SPECIFIED_CURRENCY_NOT_BORROWED_BY_USER'
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
      if (!_isUsingAsCollateralOrBorrowing(user, vars.assetId)) {
        ++vars.assetId;
        continue;
      }

      LiquidityHub.Reserve storage currentReserve = reserves[vars.assetId];
      (, , , , , BorrowModule.ReserveConfig memory reserveConfig) = BorrowModule(
        currentReserve.config.borrowModule
      ).reserves(vars.assetId); // TODO: liquidation threshold, get it from proper reserve
      uint256 decimals = currentReserve.config.decimals;
      uint256 assetUnit = 10 ** decimals;
      uint256 assetPrice = IPriceOracle(oracle).getAssetPrice(vars.assetId);

      if (reserveConfig.lt != 0 && _isUsingAsCollateral(user, vars.assetId)) {
        vars.userBalanceInBaseCurrency = _getUserBalanceInBaseCurrency(
          users[vars.assetId][user],
          currentReserve,
          assetPrice,
          assetUnit
        );
        vars.totalCollateralInBaseCurrency += vars.userBalanceInBaseCurrency;
        vars.avgLiquidationThreshold += vars.userBalanceInBaseCurrency * reserveConfig.lt;
      }

      if (_isBorrowing(user, vars.assetId)) {
        vars.totalDebtInBaseCurrency += _getUserDebtInBaseCurrency(
          user,
          currentReserve,
          assetPrice,
          assetUnit
        );
      }

      ++vars.assetId;
    }

    vars.avgLiquidationThreshold = vars.totalCollateralInBaseCurrency != 0
      ? vars.avgLiquidationThreshold / vars.totalCollateralInBaseCurrency
      : 0;

    // TODO: hf calc: hf = (collateralValue * avg liquidation threshold) / debt
    // maxDebtToCover = (collateralValue * avg liquidation threshold) / HEALTH_FACTOR_LIQUIDATABLE_THRESHOLD
    // use base currencies. Max debt to pay to result in HF above threshold
    uint256 healthFactor = (vars.totalDebtInBaseCurrency == 0)
      ? type(uint256).max
      : (vars.totalCollateralInBaseCurrency * vars.avgLiquidationThreshold).wadDiv(
        vars.totalDebtInBaseCurrency
      );
    uint256 maxDebtToCover = (vars.totalCollateralInBaseCurrency * vars.avgLiquidationThreshold)
      .wadDiv(HEALTH_FACTOR_LIQUIDATABLE_THRESHOLD);
    // console2.log('HF calcs, totalDebtInBaseCurrency:', vars.totalDebtInBaseCurrency);

    return (healthFactor);
  }

  // TODO
  function _isUsingAsCollateral(address user, uint256 assetId) internal view returns (bool) {
    return true;
  }

  // TODO
  function _isBorrowing(address user, uint256 assetId) internal view returns (bool) {
    return true;
  }

  // TODO is a given asset being used as collateral or being borrowed?
  function _isUsingAsCollateralOrBorrowing(
    address user,
    uint256 assetId
  ) internal view returns (bool) {
    return _isUsingAsCollateral(user, assetId) || _isBorrowing(user, assetId);
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
}
