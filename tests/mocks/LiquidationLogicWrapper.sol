// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {console2 as console} from 'forge-std/console2.sol';

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';

contract LiquidationLogicWrapper {
  using SafeCast for uint256;
  using PositionStatusMap for ISpoke.PositionStatus;

  ISpoke.Reserve internal collateralReserve;
  ISpoke.Reserve internal debtReserve;

  mapping(address user => mapping(uint256 reserveId => ISpoke.UserPosition))
    internal _userPositions;
  address internal _borrower;
  uint256 internal _collateralReserveId;
  uint256 internal _debtReserveId;

  ISpoke.PositionStatus internal positionStatus;

  ISpoke.LiquidationConfig internal liquidationConfig;
  ISpoke.DynamicReserveConfig internal dynamicCollateralConfig;

  constructor(address borrower) {
    _borrower = borrower;
  }

  function setBorrower(address borrower) public {
    _borrower = borrower;
  }

  function setCollateralReserveHub(IHub hub) public {
    collateralReserve.hub = hub;
  }

  function setCollateralReserveDecimals(uint256 decimals) public {
    collateralReserve.decimals = decimals.toUint8();
  }

  function setCollateralReserveAssetId(uint256 assetId) public {
    collateralReserve.assetId = assetId.toUint16();
  }

  function setCollateralReserveId(uint256 reserveId) public {
    _collateralReserveId = reserveId;
  }

  function setCollateralPositionSuppliedShares(uint256 suppliedShares) public {
    _userPositions[_borrower][_collateralReserveId].suppliedShares = suppliedShares.toUint128();
  }

  function setLiquidatorPositionSuppliedShares(address liquidator, uint256 suppliedShares) public {
    _userPositions[liquidator][_collateralReserveId].suppliedShares = suppliedShares.toUint128();
  }

  function getCollateralReserve() public view returns (ISpoke.Reserve memory) {
    return collateralReserve;
  }

  function getCollateralPosition() public view returns (ISpoke.UserPosition memory) {
    return _userPositions[_borrower][_collateralReserveId];
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

  function setDebtReserveId(uint256 reserveId) public {
    _debtReserveId = reserveId;
  }

  function setDebtPositionDrawnShares(uint256 drawnShares) public {
    _userPositions[_borrower][_debtReserveId].drawnShares = drawnShares.toUint128();
  }

  function setDebtPositionPremiumShares(uint256 premiumShares) public {
    _userPositions[_borrower][_debtReserveId].premiumShares = premiumShares.toUint128();
  }

  function setDebtPositionPremiumOffset(uint256 premiumOffset) public {
    _userPositions[_borrower][_debtReserveId].premiumOffset = premiumOffset.toUint128();
  }

  function setDebtPositionRealizedPremium(uint256 realizedPremium) public {
    _userPositions[_borrower][_debtReserveId].realizedPremium = realizedPremium.toUint128();
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
    return _userPositions[_borrower][_debtReserveId];
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

  function calculateDebtToLiquidate(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) public pure returns (uint256) {
    return LiquidationLogic._calculateDebtToLiquidate(params);
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
    return
      LiquidationLogic._liquidateCollateral(
        collateralReserve,
        _userPositions[_borrower][_collateralReserveId],
        _userPositions[params.liquidator][_collateralReserveId],
        params
      );
  }

  function liquidateDebt(LiquidationLogic.LiquidateDebtParams memory params) public returns (bool) {
    return
      LiquidationLogic._liquidateDebt(
        debtReserve,
        _userPositions[_borrower][_debtReserveId],
        positionStatus,
        params
      );
  }

  function liquidateUser(LiquidationLogic.LiquidateUserParams memory params) public returns (bool) {
    return
      LiquidationLogic.liquidateUser(
        collateralReserve,
        debtReserve,
        _userPositions,
        positionStatus,
        liquidationConfig,
        dynamicCollateralConfig,
        params
      );
  }
}
