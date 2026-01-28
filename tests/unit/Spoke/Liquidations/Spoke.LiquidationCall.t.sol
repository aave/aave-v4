// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.LiquidationCall.Base.t.sol';

abstract contract SpokeLiquidationCallHelperTest is SpokeLiquidationCallBaseTest {
  using WadRayMath for uint256;

  ISpoke spoke;
  address liquidator = makeAddr('liquidator');

  function setUp() public virtual override {
    super.setUp();
    spoke = spoke1;

    vm.prank(SPOKE_ADMIN);
    spoke.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: 0.7e18,
        liquidationBonusFactor: 20_00
      })
    );
  }

  function _baseAmountValue() internal virtual returns (uint256);

  function _processAdditionalConfigs(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user
  ) internal virtual {}

  function _processAdditionalCollateralReserves(address user, uint256 amountValue) internal {
    uint256 count = vm.randomUint(1, 10);
    for (uint256 i = 0; i < count; i++) {
      uint256 reserveId = vm.randomUint(0, spoke.getReserveCount() - 1);
      uint256 amount = _convertValueToAmount(spoke, reserveId, amountValue);
      _increaseCollateralSupply(spoke, reserveId, amount, user);
    }
  }

  function _processAdditionalDebtReserves(address user, uint256 amountValue) internal {
    uint256 count = vm.randomUint(1, 10);
    for (uint256 i = 0; i < count; i++) {
      uint256 reserveId = vm.randomUint(0, spoke.getReserveCount() - 1);
      uint256 amount = _convertValueToAmount(spoke, reserveId, amountValue);
      _increaseReserveDebt(spoke, reserveId, amount, user);
    }
  }

  function _testLiquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool isSolvent,
    bool receiveShares
  ) internal virtual {
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);

    uint256 newHealthFactor; // new health factor of user, just before liquidation
    if (isSolvent) {
      // health factor of user should be at least its average collateral factor
      newHealthFactor = vm.randomUint(
        userAccountData.avgCollateralFactor + 0.01e18,
        PercentageMath.PERCENTAGE_FACTOR.bpsToWad() - 0.01e18
      );
    } else {
      newHealthFactor = vm.randomUint(0.01e18, userAccountData.avgCollateralFactor - 0.01e18);
    }
    _makeUserLiquidatable(spoke, user, debtReserveId, newHealthFactor);

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
        isSolvent: isSolvent,
        receiveShares: receiveShares
      })
    );
  }

  function test_liquidationCall_fuzz_OneCollateral_OneDebt_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalConfigs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _testLiquidationCall(
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      true,
      receiveShares
    );
  }

  function test_liquidationCall_fuzz_OneCollateral_OneDebt_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalConfigs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );
    // user enables more collaterals, but still has deficit given that only one collateral is supplied
    for (uint256 reserveId = 0; reserveId < spoke.getReserveCount(); reserveId++) {
      if (vm.randomBool()) {
        Utils.setUsingAsCollateral(spoke, reserveId, user, true, user);
      }
    }

    _testLiquidationCall(
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      false,
      receiveShares
    );
  }

  function test_liquidationCall_fuzz_ManyCollaterals_OneDebt_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalConfigs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _processAdditionalCollateralReserves(user, 1e26);

    _testLiquidationCall(
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      true,
      receiveShares
    );
  }

  function test_liquidationCall_fuzz_ManyCollaterals_OneDebt_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalConfigs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _processAdditionalCollateralReserves(user, 1e26);

    _testLiquidationCall(
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      false,
      receiveShares
    );
  }

  function test_liquidationCall_fuzz_OneCollateral_ManyDebts_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalConfigs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _processAdditionalDebtReserves(user, 1e26);

    _testLiquidationCall(
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      true,
      receiveShares
    );
  }

  function test_liquidationCall_fuzz_OneCollateral_ManyDebts_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalConfigs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _processAdditionalDebtReserves(user, 1e26);

    _testLiquidationCall(
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      false,
      receiveShares
    );
  }

  function test_liquidationCall_fuzz_ManyCollaterals_ManyDebts_UserSolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalConfigs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _processAdditionalCollateralReserves(user, 1e26);
    _processAdditionalDebtReserves(user, 1e26);

    _testLiquidationCall(
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      true,
      receiveShares
    );
  }

  function test_liquidationCall_fuzz_ManyCollaterals_ManyDebts_UserInsolvent(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares
  ) public virtual {
    (collateralReserveId, debtReserveId, user) = _boundAssume(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      liquidator
    );

    _processAdditionalConfigs(collateralReserveId, debtReserveId, user);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    _processAdditionalCollateralReserves(user, 1e26);
    _processAdditionalDebtReserves(user, 1e26);

    _testLiquidationCall(
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      false,
      receiveShares
    );
  }

  function test_validateLiquidationCall_revertsWith_ReserveNotListed_CollateralReserve(
    uint256 collateralId,
    uint256 debtId
  ) public {
    collateralId = vm.randomUint(spoke.getReserveCount(), UINT256_MAX);
    debtId = vm.randomUint(spoke.getReserveCount(), UINT256_MAX);
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    spoke.liquidationCall(
      collateralId,
      debtId,
      vm.randomAddress(),
      vm.randomUint(),
      vm.randomBool()
    );
  }

  function test_validateLiquidationCall_revertsWith_ReserveNotListed_DebtReserve(
    uint256 collateralId,
    uint256 debtId
  ) public {
    collateralId = vm.randomUint(0, spoke.getReserveCount() - 1);
    debtId = vm.randomUint(spoke.getReserveCount(), UINT256_MAX);
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    spoke.liquidationCall(
      collateralId,
      debtId,
      vm.randomAddress(),
      vm.randomUint(),
      vm.randomBool()
    );
  }

  function test_validateLiquidationCall_revertsWith_CannotReceiveShares(
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
    _updateReserveReceiveSharesEnabledFlag(spoke, collateralReserveId, false);

    _increaseCollateralSupply(
      spoke,
      collateralReserveId,
      _convertValueToAmount(spoke, collateralReserveId, _baseAmountValue()),
      user
    );

    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    uint256 newHealthFactor = vm.randomUint(
      userAccountData.avgCollateralFactor + 0.01e18,
      PercentageMath.PERCENTAGE_FACTOR.bpsToWad() - 0.01e18
    );
    _makeUserLiquidatable(spoke, user, debtReserveId, newHealthFactor);
    debtToCover = _boundDebtToCoverNoDustRevert(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator
    );

    vm.expectRevert(ISpoke.CannotReceiveShares.selector);
    vm.prank(liquidator);
    spoke.liquidationCall(collateralReserveId, debtReserveId, user, debtToCover, true);
  }
}

/// forge-config: pr.fuzz.runs = 1000
contract SpokeLiquidationCallTest_NoLiquidationBonus_SmallPosition is
  SpokeLiquidationCallHelperTest
{
  function _baseAmountValue() internal virtual override returns (uint256) {
    return 100e26;
  }
}

/// forge-config: pr.fuzz.runs = 1000
contract SpokeLiquidationCallTest_NoLiquidationBonus_LargePosition is
  SpokeLiquidationCallHelperTest
{
  function _baseAmountValue() internal virtual override returns (uint256) {
    return 10000e26;
  }
}

/// forge-config: pr.fuzz.runs = 1000
contract SpokeLiquidationCallTest_SmallLiquidationBonus_SmallPosition is
  SpokeLiquidationCallHelperTest
{
  function setUp() public virtual override {
    super.setUp();
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      ISpoke.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        i,
        spoke.getUserPosition(i, liquidator).dynamicConfigKey
      );
      dynConfig.maxLiquidationBonus = 105_00;
      vm.prank(SPOKE_ADMIN);
      spoke.addDynamicReserveConfig(i, dynConfig);
    }
  }

  function _baseAmountValue() internal virtual override returns (uint256) {
    return 100e26;
  }
}

/// forge-config: pr.fuzz.runs = 1000
contract SpokeLiquidationCallTest_SmallLiquidationBonus_LargePosition is
  SpokeLiquidationCallHelperTest
{
  function setUp() public virtual override {
    super.setUp();
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      ISpoke.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        i,
        spoke.getUserPosition(i, liquidator).dynamicConfigKey
      );
      dynConfig.maxLiquidationBonus = 105_00;
      vm.prank(SPOKE_ADMIN);
      spoke.addDynamicReserveConfig(i, dynConfig);
    }
  }

  function _baseAmountValue() internal virtual override returns (uint256) {
    return 10000e26;
  }
}

/// forge-config: pr.fuzz.runs = 1000
contract SpokeLiquidationCallTest_LargeLiquidationBonus_SmallPosition is
  SpokeLiquidationCallHelperTest
{
  using PercentageMath for uint256;
  using SafeCast for uint256;

  function setUp() public virtual override {
    super.setUp();
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      ISpoke.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        i,
        spoke.getUserPosition(i, liquidator).dynamicConfigKey
      );
      dynConfig.maxLiquidationBonus = _randomMaxLiquidationBonus(spoke, i);
      vm.prank(SPOKE_ADMIN);
      spoke.addDynamicReserveConfig(i, dynConfig);
    }
  }

  function _baseAmountValue() internal virtual override returns (uint256) {
    return 100e26;
  }
}

/// forge-config: pr.fuzz.runs = 1000
contract SpokeLiquidationCallTest_LargeLiquidationBonus_LargePosition is
  SpokeLiquidationCallHelperTest
{
  using PercentageMath for uint256;
  using SafeCast for uint256;

  function setUp() public virtual override {
    super.setUp();
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      ISpoke.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        i,
        spoke.getUserPosition(i, liquidator).dynamicConfigKey
      );
      dynConfig.maxLiquidationBonus = _randomMaxLiquidationBonus(spoke, i);
      vm.prank(SPOKE_ADMIN);
      spoke.addDynamicReserveConfig(i, dynConfig);
    }
  }

  function _baseAmountValue() internal virtual override returns (uint256) {
    return 10000e26;
  }
}

/// forge-config: pr.fuzz.runs = 1000
contract SpokeLiquidationCallTest_TargetHealthFactor_LiquidationFee is
  SpokeLiquidationCallHelperTest
{
  using PercentageMath for uint256;
  using SafeCast for uint256;

  uint256 internal baseAmountValue;

  function setUp() public virtual override {
    super.setUp();
    baseAmountValue = vm.randomUint(MIN_AMOUNT_IN_BASE_CURRENCY, MAX_AMOUNT_IN_BASE_CURRENCY);
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      ISpoke.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        i,
        spoke.getUserPosition(i, liquidator).dynamicConfigKey
      );
      dynConfig.maxLiquidationBonus = _randomMaxLiquidationBonus(spoke, i);
      vm.prank(SPOKE_ADMIN);
      spoke.addDynamicReserveConfig(i, dynConfig);
    }
  }

  function _baseAmountValue() internal virtual override returns (uint256) {
    return baseAmountValue;
  }

  function _processAdditionalConfigs(
    uint256 collateralReserveId,
    uint256,
    address
  ) internal virtual override {
    uint256 targetHealthFactor = vm.randomUint(MIN_CLOSE_FACTOR, MAX_CLOSE_FACTOR);
    _updateTargetHealthFactor(spoke, targetHealthFactor.toUint128());

    uint32 maxLiquidationBonus = _randomMaxLiquidationBonus(spoke, collateralReserveId);
    _updateMaxLiquidationBonus(spoke, collateralReserveId, maxLiquidationBonus);

    uint256 liquidationFee = vm.randomUint(MIN_LIQUIDATION_FEE, MAX_LIQUIDATION_FEE);
    _updateLiquidationFee(spoke, collateralReserveId, liquidationFee.toUint16());
  }
}
