// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations-new/Spoke.LiquidationCall.Base.t.sol';

contract SpokeLiquidationCallTest is SpokeLiquidationCallBaseTest {
  ISpoke spoke;
  address liquidator = makeAddr('liquidator');

  function setUp() public override {
    super.setUp();
    spoke = spoke1;

    vm.prank(SPOKE_ADMIN);
    spoke.updateLiquidationConfig(
      DataTypes.LiquidationConfig({
        closeFactor: 1.05e18,
        healthFactorForMaxBonus: 0.7e18,
        liquidationBonusFactor: 20_00
      })
    );
  }

  // User solvent, no deficit
  function test_liquidationCall_fuzz_OneCollateral_OneDebt_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) public {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );
    test_liquidationCall(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator,
      true,
      false
    );
  }

  // User insolvent, has deficit
  function test_liquidationCall_fuzz_OneCollateral_OneDebt_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) public {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );
    // user enables more collaterals, but still has deficit given that only one collateral is supplied
    for (uint256 reserveId = 0; reserveId < spoke.getReserveCount(); reserveId++) {
      if (vm.randomBool()) {
        Utils.setUsingAsCollateral(spoke, reserveId, user, true, user);
      }
    }
    test_liquidationCall(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator,
      false,
      true
    );
  }

  // User solvent, no deficit
  function test_liquidationCall_fuzz_ManyCollaterals_OneDebt_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    uint256[] memory additionalCollateralReserveIds
  ) public {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );
    vm.assume(additionalCollateralReserveIds.length > 0);
    for (uint256 i = 0; i < additionalCollateralReserveIds.length; i++) {
      additionalCollateralReserveIds[i] = bound(
        additionalCollateralReserveIds[i],
        0,
        spoke.getReserveCount() - 2
      );
      if (additionalCollateralReserveIds[i] >= collateralReserveId) {
        additionalCollateralReserveIds[i] += 1;
      }
      _increaseCollateralSupply(
        spoke,
        additionalCollateralReserveIds[i],
        _convertBaseCurrencyToAmount(spoke, additionalCollateralReserveIds[i], 100e26),
        user
      );
    }
    test_liquidationCall(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator,
      true,
      false
    );
  }

  // User insolvent, no deficit
  function test_liquidationCall_fuzz_ManyCollaterals_OneDebt_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    uint256[] memory additionalCollateralReserveIds
  ) public {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );
    vm.assume(additionalCollateralReserveIds.length > 0);
    for (uint256 i = 0; i < additionalCollateralReserveIds.length; i++) {
      additionalCollateralReserveIds[i] = bound(
        additionalCollateralReserveIds[i],
        0,
        spoke.getReserveCount() - 2
      );
      if (additionalCollateralReserveIds[i] >= collateralReserveId) {
        additionalCollateralReserveIds[i] += 1;
      }
      _increaseCollateralSupply(
        spoke,
        additionalCollateralReserveIds[i],
        _convertBaseCurrencyToAmount(spoke, additionalCollateralReserveIds[i], 100e26),
        user
      );
    }
    test_liquidationCall(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator,
      false,
      false
    );
  }
}
