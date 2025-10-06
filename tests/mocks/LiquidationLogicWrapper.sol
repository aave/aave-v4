// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';

contract LiquidationLogicWrapper {
  using SafeCast for uint256;
  using PositionStatusMap for ISpoke.PositionStatus;

  ISpoke.Reserve internal collateralReserve;
  ISpoke.UserPosition internal collateralPosition;

  ISpoke.Reserve internal debtReserve;
  ISpoke.UserPosition internal debtPosition;

  ISpoke.PositionStatus internal positionStatus;

  ISpoke.LiquidationConfig internal liquidationConfig;
  ISpoke.DynamicReserveConfig internal dynamicCollateralConfig;

  function setCollateralReserveHub(IHub hub) public {
    collateralReserve.hub = hub;
  }

  function setCollateralReserveDecimals(uint256 decimals) public {
    collateralReserve.decimals = decimals.toUint8();
  }

  function setCollateralReserveAssetId(uint256 assetId) public {
    collateralReserve.assetId = assetId.toUint16();
  }

  function setCollateralPositionSuppliedShares(uint256 suppliedShares) public {
    collateralPosition.suppliedShares = suppliedShares.toUint128();
  }

  function getCollateralReserve() public view returns (ISpoke.Reserve memory) {
    return collateralReserve;
  }

  function getCollateralPosition() public view returns (ISpoke.UserPosition memory) {
    return collateralPosition;
  }

  function setDebtReserveHub(IHub hub) public {
    debtReserve.hub = hub;
  }

  function setDebtReserveDecimals(uint256 decimals) public {
    debtReserve.decimals = decimals.toUint8();
  }

  function setDebtReserveAssetId(uint256 assetId) public {
    debtReserve.assetId = assetId.toUint16();
  }

  function setDebtPositionDrawnShares(uint256 drawnShares) public {
    debtPosition.drawnShares = drawnShares.toUint128();
  }

  function setDebtPositionPremiumShares(uint256 premiumShares) public {
    debtPosition.premiumShares = premiumShares.toUint128();
  }

  function setDebtPositionPremiumOffset(uint256 premiumOffset) public {
    debtPosition.premiumOffset = premiumOffset.toUint128();
  }

  function setDebtPositionRealizedPremium(uint256 realizedPremium) public {
    debtPosition.realizedPremium = realizedPremium.toUint128();
  }

  function setCollateralStatus(uint256 reserveId, bool status) public {
    positionStatus.setUsingAsCollateral(reserveId, status);
  }

  function setBorrowingStatus(uint256 reserveId, bool status) public {
    positionStatus.setBorrowing(reserveId, status);
  }

  function getDebtReserve() public view returns (ISpoke.Reserve memory) {
    return debtReserve;
  }

  function getDebtPosition() public view returns (ISpoke.UserPosition memory) {
    return debtPosition;
  }

  function getCollateralStatus(uint256 reserveId) public view returns (bool) {
    return positionStatus.isUsingAsCollateral(reserveId);
  }

  function getBorrowingStatus(uint256 reserveId) public view returns (bool) {
    return positionStatus.isBorrowing(reserveId);
  }

  function setLiquidationConfig(ISpoke.LiquidationConfig memory newLiquidationConfig) public {
    liquidationConfig = newLiquidationConfig;
  }

  function setDynamicCollateralConfig(
    ISpoke.DynamicReserveConfig memory newDynamicCollateralConfig
  ) public {
    dynamicCollateralConfig = newDynamicCollateralConfig;
  }

  function calculateLiquidationBonus(
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonusFactor,
    uint256 healthFactor,
    uint256 maxLiquidationBonus
  ) public pure returns (uint256) {
    return
      LiquidationLogic.calculateLiquidationBonus(
        healthFactorForMaxBonus,
        liquidationBonusFactor,
        healthFactor,
        maxLiquidationBonus
      );
  }

  function validateLiquidationCall(
    LiquidationLogic.ValidateLiquidationCallParams memory params
  ) public pure {
    LiquidationLogic._validateLiquidationCall(params);
  }

  function calculateDebtToTargetHealthFactor(
    LiquidationLogic.CalculateDebtToTargetHealthFactorParams memory params
  ) public pure returns (uint256) {
    return LiquidationLogic._calculateDebtToTargetHealthFactor(params);
  }

  function calculateMaxDebtToLiquidate(
    LiquidationLogic.CalculateMaxDebtToLiquidateParams memory params
  ) public pure returns (uint256) {
    return LiquidationLogic._calculateMaxDebtToLiquidate(params);
  }

  function calculateLiquidationAmounts(
    LiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public pure returns (uint256, uint256, uint256) {
    return LiquidationLogic._calculateLiquidationAmounts(params);
  }

  function evaluateDeficit(
    bool isCollateralPositionEmpty,
    bool isDebtPositionEmpty,
    uint256 activeCollateralCount,
    uint256 borrowedCount
  ) public pure returns (bool) {
    return
      LiquidationLogic._evaluateDeficit(
        isCollateralPositionEmpty,
        isDebtPositionEmpty,
        activeCollateralCount,
        borrowedCount
      );
  }

  function liquidateCollateral(
    LiquidationLogic.LiquidateCollateralParams memory params
  ) public returns (bool) {
    return LiquidationLogic._liquidateCollateral(collateralReserve, collateralPosition, params);
  }

  function liquidateDebt(LiquidationLogic.LiquidateDebtParams memory params) public returns (bool) {
    return LiquidationLogic._liquidateDebt(debtReserve, debtPosition, positionStatus, params);
  }

  function liquidateUser(LiquidationLogic.LiquidateUserParams memory params) public returns (bool) {
    return
      LiquidationLogic.liquidateUser(
        collateralReserve,
        debtReserve,
        collateralPosition,
        debtPosition,
        positionStatus,
        liquidationConfig,
        dynamicCollateralConfig,
        params
      );
  }
}
