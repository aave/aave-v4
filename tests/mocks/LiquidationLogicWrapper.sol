// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';

contract LiquidationLogicWrapper {
  using SafeCast for *;
  using SafeERC20 for IERC20;
  using PositionStatusMap for ISpoke.PositionStatus;

  mapping(address user => mapping(uint256 reserveId => ISpoke.UserPosition))
    internal _userPositions;
  mapping(uint256 reserveId => ISpoke.Reserve) internal _reserves;
  mapping(address user => ISpoke.PositionStatus) internal _positionStatuses;
  address internal _borrower;
  address internal _liquidator;
  uint256 internal _collateralReserveId;
  uint256 internal _debtReserveId;

  ISpoke.LiquidationConfig internal liquidationConfig;
  ISpoke.DynamicReserveConfig internal dynamicCollateralConfig;

  constructor(address borrower_, address liquidator_) {
    _borrower = borrower_;
    _liquidator = liquidator_;
  }

  function setBorrower(address borrower) public {
    _borrower = borrower;
  }

  function setLiquidator(address liquidator) public {
    _liquidator = liquidator;
  }

  function setCollateralReserveHub(IHub hub) public {
    _reserves[_collateralReserveId].hub = hub;
  }

  function setCollateralReserveDecimals(uint256 decimals) public {
    _reserves[_collateralReserveId].decimals = decimals.toUint8();
  }

  function setCollateralReserveAssetId(uint256 assetId) public {
    _reserves[_collateralReserveId].assetId = assetId.toUint16();
  }

  function setCollateralReserveId(uint256 reserveId) public {
    _collateralReserveId = reserveId;
  }

  function setCollateralPositionSuppliedShares(uint256 suppliedShares) public {
    _userPositions[_borrower][_collateralReserveId].suppliedShares = suppliedShares.toUint120();
  }

  function setLiquidatorPositionSuppliedShares(address liquidator, uint256 suppliedShares) public {
    _userPositions[liquidator][_collateralReserveId].suppliedShares = suppliedShares.toUint120();
  }

  function getCollateralReserve() public view returns (ISpoke.Reserve memory) {
    return _reserves[_collateralReserveId];
  }

  function getCollateralPosition(address user) public view returns (ISpoke.UserPosition memory) {
    return _userPositions[user][_collateralReserveId];
  }

  function setDebtReserveHub(IHub hub) public {
    _reserves[_debtReserveId].hub = hub;
  }

  function setDebtReserveDecimals(uint256 decimals) public {
    _reserves[_debtReserveId].decimals = decimals.toUint8();
  }

  function setDebtReserveAssetId(uint256 assetId) public {
    _reserves[_debtReserveId].assetId = assetId.toUint16();
  }

  function setDebtReserveId(uint256 reserveId) public {
    _debtReserveId = reserveId;
  }

  function setDebtReserveUnderlying(address underlying) public {
    _reserves[_debtReserveId].underlying = underlying;
  }

  function setDebtPositionDrawnShares(uint256 drawnShares) public {
    _userPositions[_borrower][_debtReserveId].drawnShares = drawnShares.toUint120();
  }

  function setDebtPositionPremiumShares(uint256 premiumShares) public {
    _userPositions[_borrower][_debtReserveId].premiumShares = premiumShares.toUint120();
  }

  function setDebtPositionPremiumOffsetRay(int256 premiumOffsetRay) public {
    _userPositions[_borrower][_debtReserveId].premiumOffsetRay = premiumOffsetRay.toInt200();
  }

  function setBorrowerCollateralStatus(uint256 reserveId, bool status) public {
    _positionStatuses[_borrower].setUsingAsCollateral(reserveId, status);
  }

  function setBorrowerBorrowingStatus(uint256 reserveId, bool status) public {
    _positionStatuses[_borrower].setBorrowing(reserveId, status);
  }

  function setLiquidatorCollateralStatus(uint256 reserveId, bool status) public {
    _positionStatuses[_liquidator].setUsingAsCollateral(reserveId, status);
  }

  function setLiquidatorBorrowingStatus(uint256 reserveId, bool status) public {
    _positionStatuses[_liquidator].setBorrowing(reserveId, status);
  }

  function getDebtReserve() public view returns (ISpoke.Reserve memory) {
    return _reserves[_debtReserveId];
  }

  function getDebtPosition(address user) public view returns (ISpoke.UserPosition memory) {
    return _userPositions[user][_debtReserveId];
  }

  function getBorrowerCollateralStatus(uint256 reserveId) public view returns (bool) {
    return _positionStatuses[_borrower].isUsingAsCollateral(reserveId);
  }

  function getBorrowerBorrowingStatus(uint256 reserveId) public view returns (bool) {
    return _positionStatuses[_borrower].isBorrowing(reserveId);
  }

  function getLiquidatorCollateralStatus(uint256 reserveId) public view returns (bool) {
    return _positionStatuses[_liquidator].isUsingAsCollateral(reserveId);
  }

  function getLiquidatorBorrowingStatus(uint256 reserveId) public view returns (bool) {
    return _positionStatuses[_liquidator].isBorrowing(reserveId);
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
  ) public pure returns (LiquidationLogic.LiquidationAmounts memory) {
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
  ) public returns (uint256, uint256, bool) {
    return
      LiquidationLogic._liquidateCollateral(
        _reserves[_collateralReserveId],
        _userPositions[_borrower][_collateralReserveId],
        _userPositions[_liquidator][_collateralReserveId],
        params
      );
  }

  function liquidateDebt(
    LiquidationLogic.LiquidateDebtParams memory params
  ) public returns (uint256, IHubBase.PremiumDelta memory, bool) {
    return
      LiquidationLogic._liquidateDebt(
        _reserves[_debtReserveId],
        _userPositions[_borrower][_debtReserveId],
        _positionStatuses[_borrower],
        params
      );
  }

  function liquidateUser(LiquidationLogic.LiquidateUserParams memory params) public returns (bool) {
    return
      LiquidationLogic.liquidateUser(
        _reserves[_collateralReserveId],
        _reserves[_debtReserveId],
        _userPositions,
        _positionStatuses,
        liquidationConfig,
        dynamicCollateralConfig,
        params
      );
  }
}
