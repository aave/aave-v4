// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {BabylonLiquidationLogic} from 'src/spoke/libraries/BabylonLiquidationLogic.sol';
import {ReserveFlags} from 'src/spoke/libraries/ReserveFlagsMap.sol';

/// @dev Mirrors `LiquidationLogicWrapper` for the babylon liquidation library: holds the spoke
/// storage the library operates on and exposes its internal functions.
contract BabylonLiquidationLogicWrapper {
  bool public IS_TEST = true;

  using SafeCast for *;
  using PositionStatusMap for ISpoke.PositionStatus;

  mapping(uint256 reserveId => ISpoke.Reserve) internal _reserves;
  mapping(address user => mapping(uint256 reserveId => ISpoke.UserPosition))
    internal _userPositions;
  mapping(address user => ISpoke.PositionStatus) internal _positionStatuses;
  mapping(uint256 reserveId => mapping(uint32 dynamicConfigKey => ISpoke.DynamicReserveConfig))
    internal _dynamicConfig;
  address internal _borrower;
  address internal _liquidator;
  uint256 internal _collateralReserveId;
  uint256 internal _debtReserveId;

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

  function setCollateralReserveId(uint256 reserveId) public {
    _collateralReserveId = reserveId;
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

  function setCollateralReserveFlags(ReserveFlags flags) public {
    _reserves[_collateralReserveId].flags = flags;
  }

  function setDynamicCollateralConfig(
    ISpoke.DynamicReserveConfig memory newDynamicCollateralConfig
  ) public {
    uint32 dynamicConfigKey = _userPositions[_borrower][_collateralReserveId].dynamicConfigKey;
    _dynamicConfig[_collateralReserveId][dynamicConfigKey] = newDynamicCollateralConfig;
  }

  function setCollateralPositionSuppliedShares(uint256 suppliedShares) public {
    _userPositions[_borrower][_collateralReserveId].suppliedShares = suppliedShares.toUint120();
  }

  function setLiquidatorPositionSuppliedShares(address liquidator, uint256 suppliedShares) public {
    _userPositions[liquidator][_collateralReserveId].suppliedShares = suppliedShares.toUint120();
  }

  function setDebtReserveId(uint256 reserveId) public {
    _debtReserveId = reserveId;
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

  function setDebtReserveUnderlying(address underlying) public {
    _reserves[_debtReserveId].underlying = underlying;
  }

  function setDebtReserveFlags(ReserveFlags flags) public {
    _reserves[_debtReserveId].flags = flags;
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

  function executeLiquidation(
    BabylonLiquidationLogic.ExecuteLiquidationParams memory params
  ) public returns (BabylonLiquidationLogic.LiquidationResult memory) {
    return
      BabylonLiquidationLogic._executeLiquidation(
        _userPositions[_borrower][_collateralReserveId],
        _userPositions[_borrower][_debtReserveId],
        _userPositions[_liquidator][_collateralReserveId],
        _positionStatuses[_borrower],
        params
      );
  }

  function liquidateUser(
    BabylonLiquidationLogic.LiquidateUserParams memory params
  ) public returns (BabylonLiquidationLogic.LiquidationResult memory) {
    return
      BabylonLiquidationLogic.liquidateUser(
        _reserves,
        _userPositions,
        _positionStatuses,
        _dynamicConfig,
        params
      );
  }

  function calculateLiquidationAmounts(
    BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public view returns (BabylonLiquidationLogic.LiquidationAmounts memory) {
    return BabylonLiquidationLogic._calculateLiquidationAmounts(params);
  }

  function getCollateralPosition(address user) public view returns (ISpoke.UserPosition memory) {
    return _userPositions[user][_collateralReserveId];
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
}
