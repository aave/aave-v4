// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations-new/Spoke.LiquidationCall.Base.t.sol';

abstract contract SpokeLiquidationCallHelperTest is SpokeLiquidationCallBaseTest {
  using WadRayMath for uint256;

  ISpoke spoke;
  address liquidator = makeAddr('liquidator');

  uint256 internal BASE_AMOUNT_IN_BASE_CURRENCY;

  function setUp() public virtual override {
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

  function test_liquidationCall(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    address liquidator,
    bool isSolvent
  ) internal {
    DataTypes.UserAccountData memory userAccountData = spoke.getUserAccountData(user);

    uint256 targetHealthFactor;
    if (isSolvent) {
      // health factor of user should be at least its average collateral factor
      targetHealthFactor =
        (userAccountData.avgCollateralFactor + PercentageMath.PERCENTAGE_FACTOR.bpsToWad()) /
        2;
    } else {
      targetHealthFactor = (userAccountData.avgCollateralFactor * 2) / 3;
    }
    _makeUserLiquidatable(spoke, user, collateralReserveId, debtReserveId, targetHealthFactor);

    debtToCover = _boundDebtToCoverNoDustRevert(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator
    );

    _checkedLiquidationCall(
      CheckedLiquidationCallParams({
        spoke: spoke,
        collateralReserveId: collateralReserveId,
        debtReserveId: debtReserveId,
        user: user,
        debtToCover: debtToCover,
        liquidator: liquidator,
        isSolvent: isSolvent
      })
    );
  }

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

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, BASE_AMOUNT_IN_BASE_CURRENCY),
      user
    );

    test_liquidationCall(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator,
      true
    );
  }

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

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, BASE_AMOUNT_IN_BASE_CURRENCY),
      user
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
      false
    );
  }

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

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, BASE_AMOUNT_IN_BASE_CURRENCY),
      user
    );
    vm.assume(additionalCollateralReserveIds.length > 0);
    additionalCollateralReserveIds = abi.decode(
      _bound(spoke, additionalCollateralReserveIds, collateralReserveId, 10),
      (uint256[])
    );
    _increaseCollateralSupplies(spoke, additionalCollateralReserveIds, 1e26, user);

    test_liquidationCall(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator,
      true
    );
  }

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

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, BASE_AMOUNT_IN_BASE_CURRENCY),
      user
    );
    vm.assume(additionalCollateralReserveIds.length > 0);
    additionalCollateralReserveIds = abi.decode(
      _bound(spoke, additionalCollateralReserveIds, collateralReserveId, 10),
      (uint256[])
    );
    _increaseCollateralSupplies(spoke, additionalCollateralReserveIds, 1e26, user);

    test_liquidationCall(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator,
      false
    );
  }

  function test_liquidationCall_fuzz_OneCollateral_ManyDebts_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    uint256[] memory additionalDebtReserveIds
  ) public {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, 100e26),
      user
    );
    vm.assume(additionalDebtReserveIds.length > 0);
    additionalDebtReserveIds = abi.decode(
      _bound(spoke, additionalDebtReserveIds, debtReserveId, 10),
      (uint256[])
    );
    _increaseDebts(spoke, additionalDebtReserveIds, 1e26, user);

    test_liquidationCall(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator,
      true
    );
  }

  function test_liquidationCall_fuzz_OneCollateral_ManyDebts_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    uint256[] memory additionalDebtReserveIds
  ) public {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, 100e26),
      user
    );
    vm.assume(additionalDebtReserveIds.length > 0);
    additionalDebtReserveIds = abi.decode(
      _bound(spoke, additionalDebtReserveIds, debtReserveId, 10),
      (uint256[])
    );
    _increaseDebts(spoke, additionalDebtReserveIds, 1e26, user);

    test_liquidationCall(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator,
      false
    );
  }

  function test_liquidationCall_fuzz_ManyCollaterals_ManyDebts_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    uint256[] memory additionalCollateralReserveIds,
    uint256[] memory additionalDebtReserveIds
  ) public {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, BASE_AMOUNT_IN_BASE_CURRENCY),
      user
    );

    vm.assume(additionalCollateralReserveIds.length > 0);
    additionalCollateralReserveIds = abi.decode(
      _bound(spoke, additionalCollateralReserveIds, collateralReserveId, 10),
      (uint256[])
    );
    _increaseCollateralSupplies(spoke, additionalCollateralReserveIds, 1e26, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, 100e26),
      user
    );
    vm.assume(additionalDebtReserveIds.length > 0);
    additionalDebtReserveIds = abi.decode(
      _bound(spoke, additionalDebtReserveIds, debtReserveId, 10),
      (uint256[])
    );
    _increaseDebts(spoke, additionalDebtReserveIds, 1e26, user);

    test_liquidationCall(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator,
      true
    );
  }

  function test_liquidationCall_fuzz_ManyCollaterals_ManyDebts_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    uint256[] memory additionalCollateralReserveIds,
    uint256[] memory additionalDebtReserveIds
  ) public {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, BASE_AMOUNT_IN_BASE_CURRENCY),
      user
    );

    vm.assume(additionalCollateralReserveIds.length > 0);
    additionalCollateralReserveIds = abi.decode(
      _bound(spoke, additionalCollateralReserveIds, collateralReserveId, 10),
      (uint256[])
    );
    _increaseCollateralSupplies(spoke, additionalCollateralReserveIds, 1e26, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, 100e26),
      user
    );
    vm.assume(additionalDebtReserveIds.length > 0);
    additionalDebtReserveIds = abi.decode(
      _bound(spoke, additionalDebtReserveIds, debtReserveId, 10),
      (uint256[])
    );
    _increaseDebts(spoke, additionalDebtReserveIds, 1e26, user);

    test_liquidationCall(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator,
      false
    );
  }
}

contract SpokeLiquidationCallTest_NoLiquidationBonus_SmallPosition is
  SpokeLiquidationCallHelperTest
{
  function setUp() public virtual override {
    super.setUp();
    BASE_AMOUNT_IN_BASE_CURRENCY = 100e26;
  }
}

contract SpokeLiquidationCallTest_NoLiquidationBonus_LargePosition is
  SpokeLiquidationCallHelperTest
{
  function setUp() public virtual override {
    super.setUp();
    BASE_AMOUNT_IN_BASE_CURRENCY = 10000e26;
  }
}

contract SpokeLiquidationCallTest_SmallLiquidationBonus_SmallPosition is
  SpokeLiquidationCallHelperTest
{
  function setUp() public virtual override {
    super.setUp();
    BASE_AMOUNT_IN_BASE_CURRENCY = 100e26;
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      DataTypes.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        i,
        spoke.getUserPosition(i, liquidator).configKey
      );
      dynConfig.liquidationBonus = 105_00;
      vm.prank(SPOKE_ADMIN);
      spoke.addDynamicReserveConfig(i, dynConfig);
    }
  }
}

contract SpokeLiquidationCallTest_SmallLiquidationBonus_LargePosition is
  SpokeLiquidationCallHelperTest
{
  function setUp() public virtual override {
    super.setUp();
    BASE_AMOUNT_IN_BASE_CURRENCY = 10000e26;
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      DataTypes.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        i,
        spoke.getUserPosition(i, liquidator).configKey
      );
      dynConfig.liquidationBonus = 105_00;
      vm.prank(SPOKE_ADMIN);
      spoke.addDynamicReserveConfig(i, dynConfig);
    }
  }
}

contract SpokeLiquidationCallTest_LargeLiquidationBonus_SmallPosition is
  SpokeLiquidationCallHelperTest
{
  using PercentageMath for uint256;
  using SafeCast for uint256;

  function setUp() public virtual override {
    super.setUp();
    BASE_AMOUNT_IN_BASE_CURRENCY = 100e26;
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      DataTypes.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        i,
        spoke.getUserPosition(i, liquidator).configKey
      );
      dynConfig.liquidationBonus = (PercentageMath.PERCENTAGE_FACTOR - 1)
        .percentDivDown(dynConfig.collateralFactor)
        .toUint32();
      vm.prank(SPOKE_ADMIN);
      spoke.addDynamicReserveConfig(i, dynConfig);
    }
  }
}

contract SpokeLiquidationCallTest_LargeLiquidationBonus_LargePosition is
  SpokeLiquidationCallHelperTest
{
  using PercentageMath for uint256;
  using SafeCast for uint256;

  function setUp() public virtual override {
    super.setUp();
    BASE_AMOUNT_IN_BASE_CURRENCY = 10000e26;
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      DataTypes.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        i,
        spoke.getUserPosition(i, liquidator).configKey
      );
      dynConfig.liquidationBonus = (PercentageMath.PERCENTAGE_FACTOR - 1)
        .percentDivDown(dynConfig.collateralFactor)
        .toUint32();
      vm.prank(SPOKE_ADMIN);
      spoke.addDynamicReserveConfig(i, dynConfig);
    }
  }
}
