// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LiquidityHub} from '../LiquidityHub.sol';

library LiquidationLogic {
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
    uint256 collateralAssetId,
    uint256 debtAssetId,
    address user,
    uint256 debtToCover,
    uint256 liquidatedCollateralAmount,
    address liquidator,
    bool receiveAToken
  ) external {
    // TODO
    // V3 implementation to liquidate undercollateralized positions to start out with.
    // In addition, instead of allowing the liquidator to liquidate up to 50% if HF goes below certain threshold
    // we want allow the liquidator to liquidate enough assets so the HF goes back to 1 (or slightly higher).

    LiquidityHub.Reserve storage collateralReserve = reserves[collateralAssetId];
    LiquidityHub.Reserve storage debtReserve = reserves[debtAssetId];
    LiquidityHub.UserConfig storage userConfig = users[debtAssetId][user];

    // TODO: check if user is undercollateralized. Get HF
    uint256 healthFactor = _calculateUserAccountData(reserves, reservesList, userConfig, user);

    _validateLiquidationCall(userConfig, collateralReserve, debtReserve, debtToCover);
    // TODO: _calculateDebt();

    emit LiquidationCall(
      collateralAssetId,
      debtAssetId,
      user,
      debtToCover,
      0, // liquidatedCollateralAmount
      msg.sender,
      receiveAToken
    );
  }

  function _validateLiquidationCall(
    LiquidityHub.UserConfig memory userConfig,
    LiquidityHub.Reserve memory collateralReserve,
    LiquidityHub.Reserve memory debtReserve,
    uint256 debtToCover
  ) internal view {
    require(debtReserve.config.active && collateralReserve.config.active, 'RESERVE_NOT_ACTIVE');
    require(!debtReserve.config.paused && !collateralReserve.config.paused, 'RESERVE_IS_PAUSED');
  }

  function _calculateUserAccountData(
    mapping(uint256 => LiquidityHub.Reserve) storage reserves,
    address[] storage reservesList,
    LiquidityHub.UserConfig memory userConfig,
    address user
  ) internal view returns (uint256) {
    // TODO: calculate user account data, including health factor
    // if no debt, then health factor is type(uint256).max
    // TODO: emode config logic

    // TODO: hf: (collateralValue * avg liquidation threshold) / debt
    // use base currencies
    // uint256 healthFactor =

    // get collateral value, get debt
    // IPriceOracle(oracle).getAssetPrice(assetId);
    return (1); // dummy response for now
  }

  function _calculateDebt(
    LiquidityHub.UserConfig memory userConfig,
    uint256 debtToCover
  ) internal pure returns (uint256) {}
}
