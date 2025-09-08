// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations-new/Spoke.LiquidationCall.Base.t.sol';

abstract contract SpokeLiquidationCallHelperTest is SpokeLiquidationCallBaseTest {
  using WadRayMath for uint256;

  ISpoke spoke;
  address liquidator = makeAddr('liquidator');

  function setUp() public virtual override {
    super.setUp();
    spoke = spoke1;

    vm.prank(SPOKE_ADMIN);
    spoke.updateLiquidationConfig(
      DataTypes.LiquidationConfig({
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: 0.7e18,
        liquidationBonusFactor: 20_00
      })
    );
  }

  function _baseAmountInBaseCurrency() internal virtual returns (uint256);

  function _processAdditionalInputs(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user
  ) internal virtual {}

  function test_liquidationCall(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    address liquidator,
    bool isSolvent
  ) internal virtual {
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
    uint256 debtToCover,
    bytes memory additionalInputs
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalInputs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, _baseAmountInBaseCurrency()),
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
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalInputs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, _baseAmountInBaseCurrency()),
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
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalInputs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, _baseAmountInBaseCurrency()),
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
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalInputs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, _baseAmountInBaseCurrency()),
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
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalInputs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, _baseAmountInBaseCurrency()),
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
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalInputs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, _baseAmountInBaseCurrency()),
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
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalInputs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, _baseAmountInBaseCurrency()),
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
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, _baseAmountInBaseCurrency()),
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
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalInputs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, _baseAmountInBaseCurrency()),
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
      _convertBaseCurrencyToAmount(spoke, collateralReserveId, _baseAmountInBaseCurrency()),
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
  function _baseAmountInBaseCurrency() internal virtual override returns (uint256) {
    return 100e26;
  }
}

contract SpokeLiquidationCallTest_NoLiquidationBonus_LargePosition is
  SpokeLiquidationCallHelperTest
{
  function _baseAmountInBaseCurrency() internal virtual override returns (uint256) {
    return 10000e26;
  }
}

contract SpokeLiquidationCallTest_SmallLiquidationBonus_SmallPosition is
  SpokeLiquidationCallHelperTest
{
  function setUp() public virtual override {
    super.setUp();
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      DataTypes.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        i,
        spoke.getUserPosition(i, liquidator).configKey
      );
      dynConfig.maxLiquidationBonus = 105_00;
      vm.prank(SPOKE_ADMIN);
      spoke.addDynamicReserveConfig(i, dynConfig);
    }
  }

  function _baseAmountInBaseCurrency() internal virtual override returns (uint256) {
    return 100e26;
  }
}

contract SpokeLiquidationCallTest_SmallLiquidationBonus_LargePosition is
  SpokeLiquidationCallHelperTest
{
  function setUp() public virtual override {
    super.setUp();
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      DataTypes.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        i,
        spoke.getUserPosition(i, liquidator).configKey
      );
      dynConfig.maxLiquidationBonus = 105_00;
      vm.prank(SPOKE_ADMIN);
      spoke.addDynamicReserveConfig(i, dynConfig);
    }
  }

  function _baseAmountInBaseCurrency() internal virtual override returns (uint256) {
    return 10000e26;
  }
}

contract SpokeLiquidationCallTest_LargeLiquidationBonus_SmallPosition is
  SpokeLiquidationCallHelperTest
{
  using PercentageMath for uint256;
  using SafeCast for uint256;

  function setUp() public virtual override {
    super.setUp();
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      DataTypes.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        i,
        spoke.getUserPosition(i, liquidator).configKey
      );
      dynConfig.maxLiquidationBonus = (PercentageMath.PERCENTAGE_FACTOR - 1)
        .percentDivDown(dynConfig.collateralFactor)
        .toUint32();
      vm.prank(SPOKE_ADMIN);
      spoke.addDynamicReserveConfig(i, dynConfig);
    }
  }

  function _baseAmountInBaseCurrency() internal virtual override returns (uint256) {
    return 100e26;
  }
}

contract SpokeLiquidationCallTest_LargeLiquidationBonus_LargePosition is
  SpokeLiquidationCallHelperTest
{
  using PercentageMath for uint256;
  using SafeCast for uint256;

  function setUp() public virtual override {
    super.setUp();
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      DataTypes.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        i,
        spoke.getUserPosition(i, liquidator).configKey
      );
      dynConfig.maxLiquidationBonus = (PercentageMath.PERCENTAGE_FACTOR - 1)
        .percentDivDown(dynConfig.collateralFactor)
        .toUint32();
      vm.prank(SPOKE_ADMIN);
      spoke.addDynamicReserveConfig(i, dynConfig);
    }
  }

  function _baseAmountInBaseCurrency() internal virtual override returns (uint256) {
    return 10000e26;
  }
}

contract SpokeLiquidationCallTest_TargetHealthFactor_LiquidationFee is
  SpokeLiquidationCallHelperTest
{
  using PercentageMath for uint256;
  using SafeCast for uint256;

  uint256 internal baseAmountInBaseCurrency;

  function _baseAmountInBaseCurrency() internal virtual override returns (uint256) {
    return baseAmountInBaseCurrency;
  }

  function _processAdditionalInputs(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user
  ) internal virtual override {
    uint256 targetHealthFactor = vm.randomUint(MIN_CLOSE_FACTOR, MAX_CLOSE_FACTOR);
    _updateTargetHealthFactor(spoke, targetHealthFactor.toUint128());

    uint256 liquidationFee = vm.randomUint(MIN_LIQUIDATION_FEE, MAX_LIQUIDATION_FEE);
    _updateLiquidationFee(spoke, collateralReserveId, liquidationFee.toUint16());

    baseAmountInBaseCurrency = vm.randomUint(
      MIN_AMOUNT_IN_BASE_CURRENCY,
      MAX_AMOUNT_IN_BASE_CURRENCY
    );
  }
}
