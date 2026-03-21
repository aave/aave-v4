// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Interfaces
import {ISpoke, ISpokeBase} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeHandler} from '../interfaces/ISpokeHandler.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

// Libraries
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {Constants} from 'tests/Constants.sol';

// Test Contracts
import {Actor} from '../../../shared/utils/Actor.sol';
import {BaseHandler} from '../../base/BaseHandler.t.sol';

/// @title SpokeHandler
/// @notice Handler test contract for a set of actions
contract SpokeHandler is BaseHandler, ISpokeHandler {
  using WadRayMath for uint256;
  using MathUtils for uint256;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      STATE VARIABLES                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  struct LiquidationVars {
    // Spoke
    address violator;
    address liquidator;
    address spoke;
    address underlying;
    // Debt reserve
    uint256 debtReserveId;
    uint256 collateralReserveId;
    // Liquidation
    uint256 debtToCover;
    uint256 debtLiquidated;
    uint256 totalDebtValueBefore;
    // Liquidator
    uint256 liquidatorCollateralBalanceBefore;
    uint256 liquidatorCollateralBalanceAfter;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          ACTIONS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function supply(uint256 amount, uint8 i, uint8 j, uint8 k) external setup {
    address onBehalfOf = _getRandomActor(i);
    address spoke = _getRandomSpoke(j);
    uint256 reserveId = _getRandomReserveId(spoke, k);
    _registerUserToCheck(spoke, reserveId, onBehalfOf); // register user to check post conditions

    _tryMintAndApprove(_underlying(spoke, reserveId), address(actor), spoke, amount);

    _before();
    (bool ok, ) = actor.proxy(
      spoke,
      abi.encodeCall(ISpokeBase.supply, (reserveId, amount, onBehalfOf))
    );

    if (ok) {
      _after();
    } else {
      vm.assume(false);
    }
  }

  function withdraw(uint256 amount, uint8 i, uint8 j, uint8 k) external setup {
    address onBehalfOf = _getRandomActor(i);
    address spoke = _getRandomSpoke(j);
    uint256 reserveId = _getRandomReserveId(spoke, k);
    _registerUserToCheck(spoke, reserveId, onBehalfOf); // register user to check post conditions
    bool healthyBefore = _isHealthy(spoke, onBehalfOf);

    _before();
    (bool ok, ) = actor.proxy(
      spoke,
      abi.encodeCall(ISpokeBase.withdraw, (reserveId, amount, onBehalfOf))
    );

    if (ok) {
      _after();

      assertTrue(healthyBefore, GPOST_SP_H);
      assertTrue(_isHealthy(spoke, onBehalfOf), HSPOST_SP_I);
    } else {
      vm.assume(false);
    }
  }

  function borrow(uint256 amount, uint8 i, uint8 j, uint8 k) external setup {
    address onBehalfOf = _getRandomActor(i);
    address spoke = _getRandomSpoke(j);
    uint256 reserveId = _getRandomReserveId(spoke, k);
    _registerUserToCheck(spoke, reserveId, onBehalfOf); // register user to check post conditions
    bool healthyBefore = _isHealthy(spoke, onBehalfOf);

    _before();
    (bool ok, ) = actor.proxy(
      spoke,
      abi.encodeCall(ISpokeBase.borrow, (reserveId, amount, onBehalfOf))
    );

    if (ok) {
      _after();

      assertTrue(healthyBefore, HSPOST_SP_D);
      assertTrue(_isHealthy(spoke, onBehalfOf), HSPOST_SP_I);
    } else {
      vm.assume(false);
    }
  }

  function repay(uint256 amount, uint8 i, uint8 j, uint8 k) external setup {
    address onBehalfOf = _getRandomActor(i);
    address spoke = _getRandomSpoke(j);
    uint256 reserveId = _getRandomReserveId(spoke, k);
    _registerUserToCheck(spoke, reserveId, onBehalfOf); // register user to check post conditions

    _tryMintAndApprove(_underlying(spoke, reserveId), address(actor), spoke, amount);

    _before();
    (bool ok, ) = actor.proxy(
      spoke,
      abi.encodeCall(ISpokeBase.repay, (reserveId, amount, onBehalfOf))
    );

    if (ok) {
      _after();

      assertLe(
        _userVarsAfter(spoke, reserveId, onBehalfOf).debt.owed,
        _userVarsBefore(spoke, reserveId, onBehalfOf).debt.owed,
        HSPOST_SP_C
      );
    } else {
      vm.assume(false);
    }
  }

  function liquidationCall(
    uint256 debtToCover,
    bool receiveShares,
    uint8 i,
    uint8 j,
    uint8 k,
    uint8 l
  ) external setup {
    LiquidationVars memory liquidationVars;
    liquidationVars.spoke = _getRandomSpoke(j);
    liquidationVars.debtToCover = debtToCover;

    liquidationVars.violator = _getRandomActor(i);
    liquidationVars.liquidator = address(actor);

    liquidationVars.collateralReserveId = _getRandomReserveId(liquidationVars.spoke, k);
    liquidationVars.debtReserveId = _getRandomReserveId(liquidationVars.spoke, l);
    liquidationVars.underlying = ISpoke(liquidationVars.spoke)
      .getReserve(liquidationVars.collateralReserveId)
      .underlying;

    uint256 violatorCollateralBalanceBefore = ISpoke(liquidationVars.spoke).getUserSuppliedAssets(
      liquidationVars.collateralReserveId,
      liquidationVars.violator
    );

    liquidationVars.totalDebtValueBefore = ISpoke(liquidationVars.spoke)
      .getUserAccountData(liquidationVars.violator)
      .totalDebtValueRay
      .fromRayUp();

    if (receiveShares) {
      liquidationVars.liquidatorCollateralBalanceBefore = ISpoke(liquidationVars.spoke)
        .getUserSuppliedAssets(liquidationVars.collateralReserveId, address(actor));
    } else {
      liquidationVars.liquidatorCollateralBalanceBefore = IERC20(liquidationVars.underlying)
        .balanceOf(address(actor));
    }

    // register users to check post conditions: liquidated user and liquidator for both reserves
    _registerUserToCheck(
      liquidationVars.spoke,
      liquidationVars.debtReserveId,
      liquidationVars.violator
    );
    _registerUserToCheck(
      liquidationVars.spoke,
      liquidationVars.collateralReserveId,
      liquidationVars.violator
    );
    _registerUserToCheck(
      liquidationVars.spoke,
      liquidationVars.debtReserveId,
      liquidationVars.liquidator
    );
    _registerUserToCheck(
      liquidationVars.spoke,
      liquidationVars.collateralReserveId,
      liquidationVars.liquidator
    );

    _tryMintAndApprove(
      _underlying(liquidationVars.spoke, liquidationVars.debtReserveId),
      address(actor),
      liquidationVars.spoke,
      debtToCover
    );

    _before();
    (bool ok, ) = actor.proxy(
      liquidationVars.spoke,
      abi.encodeCall(
        ISpokeBase.liquidationCall,
        (
          liquidationVars.collateralReserveId,
          liquidationVars.debtReserveId,
          liquidationVars.violator,
          liquidationVars.debtToCover,
          receiveShares
        )
      )
    );

    if (ok) {
      _after();

      // Calculate the debt liquidated from user-level snapshots (not reserve-level, which
      // includes interest accrual on other users' debt and would be inaccurate)
      UserVars memory violatorDebtVarsBefore = _userVarsBefore(
        liquidationVars.spoke,
        liquidationVars.debtReserveId,
        liquidationVars.violator
      );
      UserVars memory violatorDebtVarsAfter = _userVarsAfter(
        liquidationVars.spoke,
        liquidationVars.debtReserveId,
        liquidationVars.violator
      );
      liquidationVars.debtLiquidated = violatorDebtVarsBefore.debt.owed.zeroFloorSub(
        violatorDebtVarsAfter.debt.owed
      );

      if (receiveShares) {
        liquidationVars.liquidatorCollateralBalanceAfter = ISpoke(liquidationVars.spoke)
          .getUserSuppliedAssets(liquidationVars.collateralReserveId, address(actor));
      } else {
        liquidationVars.liquidatorCollateralBalanceAfter = IERC20(liquidationVars.underlying)
          .balanceOf(address(actor));
      }

      /// HSPOST ///
      assertLe(liquidationVars.debtLiquidated, violatorDebtVarsBefore.debt.owed, HSPOST_SP_LIQ_A);

      if (
        liquidationVars.liquidatorCollateralBalanceAfter >
        liquidationVars.liquidatorCollateralBalanceBefore
      ) {
        assertLe(
          liquidationVars.liquidatorCollateralBalanceAfter -
            liquidationVars.liquidatorCollateralBalanceBefore,
          violatorCollateralBalanceBefore,
          HSPOST_SP_LIQ_B
        );
      }

      if (liquidationVars.totalDebtValueBefore < Constants.DUST_LIQUIDATION_THRESHOLD) {
        assertEq(violatorDebtVarsAfter.debt.owed, 0, HSPOST_SP_LIQ_C);
      }

      assertGe(liquidationVars.debtToCover, liquidationVars.debtLiquidated, HSPOST_SP_LIQ_D);

      assertLt(
        _userAccountDataVarsBefore(liquidationVars.spoke, liquidationVars.violator)
          .data
          .healthFactor,
        Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
        HSPOST_SP_LIQ_E
      );

      if (violatorDebtVarsAfter.debt.owed > 0) {
        assertGt(
          _userAccountDataVarsAfter(liquidationVars.spoke, liquidationVars.violator)
            .data
            .healthFactor,
          _userAccountDataVarsBefore(liquidationVars.spoke, liquidationVars.violator)
            .data
            .healthFactor,
          HSPOST_SP_LIQ_G
        );
      }
    } else {
      vm.assume(false);
    }
  }

  function setUsingAsCollateral(bool usingAsCollateral, uint8 i, uint8 j) external setup {
    address onBehalfOf = address(actor);
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);

    (bool isUsingAsCollateral, ) = ISpoke(spoke).getUserReserveStatus(reserveId, onBehalfOf);
    vm.assume(usingAsCollateral != isUsingAsCollateral); // usingAsCollateral is a noop

    // register user to check post conditions
    /// @dev setUsingAsCollateral(reserveId, FALSE) all reserves in user position should be refreshed,
    ///      so we check all reserves in user position
    ///      setUsingAsCollateral(reserveId, TRUE) only reserveId in user position should be refreshed,
    ///      so we check only the reserveId in user position
    _registerUserToCheck(spoke, (usingAsCollateral ? reserveId : CHECK_ALL_RESERVES), onBehalfOf);

    _before();
    (bool ok, ) = actor.proxy(
      spoke,
      abi.encodeCall(ISpoke.setUsingAsCollateral, (reserveId, usingAsCollateral, onBehalfOf))
    );

    if (ok) {
      _after();
    } else {
      vm.assume(false);
    }
  }

  function updateUserRiskPremium(uint8 i) external setup {
    address onBehalfOf = address(actor);
    address spoke = _getRandomSpoke(i);
    _registerUserToCheck(spoke, CHECK_ALL_RESERVES, onBehalfOf); // register user to check post conditions

    _before();
    (bool ok, ) = actor.proxy(spoke, abi.encodeCall(ISpoke.updateUserRiskPremium, (onBehalfOf)));

    if (ok) {
      _after();
      /// HSPOST ///
      uint256 reserveCount = ISpoke(spoke).getReserveCount();
      for (uint256 j; j < reserveCount; j++) {
        UserVars memory varsBefore = _userVarsBefore(spoke, j, onBehalfOf);
        UserVars memory varsAfter = _userVarsAfter(spoke, j, onBehalfOf);
        assertEq(varsBefore.debt.premiumRay, varsAfter.debt.premiumRay, HSPOST_HUB_M);
        assertEq(varsBefore.debt.owed, varsAfter.debt.owed, HSPOST_SP_F);
      }
    } else {
      vm.assume(false);
    }
  }

  function updateUserDynamicConfig(uint8 i) external setup {
    address onBehalfOf = address(actor);
    address spoke = _getRandomSpoke(i);

    _registerUserToCheck(spoke, CHECK_ALL_RESERVES, onBehalfOf);

    _before();
    (bool ok, ) = actor.proxy(spoke, abi.encodeCall(ISpoke.updateUserDynamicConfig, (onBehalfOf)));

    if (ok) {
      _after();
      assertTrue(_isHealthy(spoke, onBehalfOf), HSPOST_SP_I);
    } else {
      vm.assume(false);
    }
  }

  function setUserPositionManager(bool approve, uint8 i, uint8 j) external setup {
    address spoke = _getRandomSpoke(i);
    address positionManager = _getRandomActor(j);

    _before();
    (bool ok, ) = actor.proxy(
      spoke,
      abi.encodeCall(ISpoke.setUserPositionManager, (positionManager, approve))
    );

    if (ok) {
      _after();
    } else {
      vm.assume(false);
    }
  }

  // todo check decoded ret

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         OWNER ACTIONS                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////
}
