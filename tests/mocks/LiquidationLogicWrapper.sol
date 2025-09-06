// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.10;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IHub} from 'src/interfaces/IHub.sol';
import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

contract LiquidationLogicWrapper {
  using SafeCast for uint256;
  using PositionStatus for DataTypes.PositionStatus;

  DataTypes.Reserve internal collateralReserve;
  DataTypes.UserPosition internal collateralPosition;

  DataTypes.Reserve internal debtReserve;
  DataTypes.UserPosition internal debtPosition;

  DataTypes.PositionStatus internal positionStatus;

  function setCollateralReserveHub(IHub hub) public {
    collateralReserve.hub = hub;
  }

  function setCollateralReserveAssetId(uint256 assetId) public {
    collateralReserve.assetId = assetId.toUint16();
  }

  function setCollateralPositionSuppliedShares(uint256 suppliedShares) public {
    collateralPosition.suppliedShares = suppliedShares.toUint128();
  }

  function getCollateralReserve() public view returns (DataTypes.Reserve memory) {
    return collateralReserve;
  }

  function getCollateralPosition() public view returns (DataTypes.UserPosition memory) {
    return collateralPosition;
  }

  function setDebtReserveHub(IHub hub) public {
    debtReserve.hub = hub;
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

  function setBorrowingStatus(uint256 reserveId, bool status) public {
    positionStatus.setBorrowing(reserveId, status);
  }

  function getDebtReserve() public view returns (DataTypes.Reserve memory) {
    return debtReserve;
  }

  function getDebtPosition() public view returns (DataTypes.UserPosition memory) {
    return debtPosition;
  }

  function getBorrowingStatus(uint256 reserveId) public view returns (bool) {
    return positionStatus.isBorrowing(reserveId);
  }

  function calculateLiquidationBonus(
    DataTypes.CalculateLiquidationBonusParams memory params
  ) public pure returns (uint256) {
    return LiquidationLogic.calculateLiquidationBonus(params);
  }

  function validateLiquidationCall(
    LiquidationLogic.ValidateLiquidationCallParams memory params
  ) public pure {
    LiquidationLogic._validateLiquidationCall(params);
  }

  function calculateDebtToRestoreTargetHealthFactor(
    LiquidationLogic.CalculateDebtToRestoreTargetHealthFactorParams memory params
  ) public pure returns (uint256) {
    return LiquidationLogic._calculateDebtToRestoreTargetHealthFactor(params);
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

  function assessDeficit(
    LiquidationLogic.AssessDeficitParams memory params
  ) public pure returns (bool) {
    return LiquidationLogic._assessDeficit(params);
  }

  function liquidateCollateral(
    LiquidationLogic.LiquidateCollateralParams memory params
  ) public returns (bool) {
    return LiquidationLogic._liquidateCollateral(collateralReserve, collateralPosition, params);
  }

  function liquidateDebt(LiquidationLogic.LiquidateDebtParams memory params) public returns (bool) {
    return LiquidationLogic._liquidateDebt(debtReserve, debtPosition, positionStatus, params);
  }
}
