// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LiquidityHub} from './LiquidityHub.sol';
import {IPriceOracle} from './IPriceOracle.sol';

library LiquidationLogic {
  /**
   * @dev allow the liquidator to liquidate enough assets so the HF goes back to this value
   */
  uint256 public constant HF_LIQUIDATION_THRESHOLD = 1e18;

  event LiquidationCall(
    uint256 indexed collateralAssetId,
    uint256 indexed debtAssetId,
    address indexed user,
    uint256 debtToCover,
    uint256 liquidatedCollateralAmount,
    address liquidator,
    bool receiveAToken
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
    bool receiveAToken,
    address oracle
  ) external {
    // TODO
    // V3 implementation to liquidate undercollateralized positions to start out with.
    // In addition, instead of allowing the liquidator to liquidate up to 50% if HF goes below certain threshold
    // we want allow the liquidator to liquidate enough assets so the HF goes back to 1 (or slightly higher).

    LiquidityHub.Reserve storage collateralReserve = reserves[collateralAssetId];
    LiquidityHub.Reserve storage debtReserve = reserves[debtAssetId];

    // TODO: check if user is undercollateralized. Get HF
    uint256 healthFactor = _calculateUserAccountData(reserves, reservesList, users, user, oracle);

    _validateLiquidationCall(collateralReserve, debtReserve);
    // TODO: _calculateDebt();

    emit LiquidationCall(
      collateralAssetId,
      debtAssetId,
      user,
      debtToCover, // TODO: actualDebtToLiquidate
      0, // TODO: liquidatedCollateralAmount
      msg.sender,
      receiveAToken
    );
  }

  function _validateLiquidationCall(
    LiquidityHub.Reserve memory collateralReserve,
    LiquidityHub.Reserve memory debtReserve
  ) internal view {
    require(debtReserve.config.active && collateralReserve.config.active, 'RESERVE_NOT_ACTIVE');
    require(!debtReserve.config.paused && !collateralReserve.config.paused, 'RESERVE_IS_PAUSED');
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

    uint256 totalCollateralInBaseCurrency;
    uint256 reserveCount = reservesList.length;
    uint256 assetId;
    while (assetId < reserveCount) {
      if (!_isUsingAsCollateralOrBorrowing(assetId)) {
        ++assetId;
        continue;
      }

      LiquidityHub.Reserve storage currentReserve = reserves[assetId];
      uint256 lt = currentReserve.config.lt;
      uint256 decimals = currentReserve.config.decimals;
      uint256 assetUnit = 10 ** decimals;

      address currentReserveAddress = reservesList[assetId];
      uint256 assetPrice = IPriceOracle(oracle).getAssetPrice(assetId);
      uint256 userBalanceInBaseCurrency = _getUserBalanceInBaseCurrency(
        user,
        currentReserve,
        assetPrice,
        assetUnit
      );
      totalCollateralInBaseCurrency += userBalanceInBaseCurrency;

      if (_isBorrowing(assetId)) {
        //TODO
        // uint256 totalDebtInBaseCurrency += _getUserDebtInBaseCurrency(
        //   params.user,
        //   currentReserve,
        //   vars.assetPrice,
        //   vars.assetUnit
        // );
      }

      ++assetId;
    }

    // TODO: hf: (collateralValue * avg liquidation threshold) / debt
    // use base currencies
    // uint256 healthFactor =

    // get collateral value, get debt
    // IPriceOracle(oracle).getAssetPrice(assetId);
    return (1); // dummy response for now
  }

  // TODO
  function _isUsingAsCollateral(uint256 assetId) internal {
    return true;
  }

  // TODO
  function _isBorrowing(uint256 assetId) internal {
    return true;
  }

  // TODO is a given asset being used as collateral or being borrowed?
  function _isUsingAsCollateralOrBorrowing(uint256 assetId) internal {
    return _isUsingAsCollateral(assetId) || _isBorrowing(assetId);
  }

  // TODO
  function _getUserBalanceInBaseCurrency(
    address user,
    LiquidityHub.Reserve storage reserve,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal pure {
    uint256 shareRatio = user.shares.rayDiv(reserve.totalShares);
    uint256 userAssets = shareRatio.rayMul(reserve.totalAssets) * assetPrice;
    return balance / assetUnit;
  }

  // TODO
  function _calculateDebt(
    LiquidityHub.UserConfig memory userConfig,
    uint256 debtToCover
  ) internal pure returns (uint256) {}
}
