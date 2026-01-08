// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.LiquidationCall.t.sol';

contract SpokeLiquidationCallPremiumTest is SpokeLiquidationCallHelperTest {
  using SafeCast for uint256;

  uint256 internal baseAmountValue;

  // function setUp() public virtual override {
  //   super.setUp();
  //   baseAmountValue = vm.randomUint(MIN_AMOUNT_IN_BASE_CURRENCY, MAX_AMOUNT_IN_BASE_CURRENCY);
  // }

  function _baseAmountValue() internal virtual override returns (uint256) {
    return vm.randomUint(MIN_AMOUNT_IN_BASE_CURRENCY, MAX_AMOUNT_IN_BASE_CURRENCY);
  }

  function _processAdditionalConfigs(
    uint256 collateralReserveId,
    uint256 /*debtReserveId*/,
    address /*user*/
  ) internal virtual override {
    uint256 targetHealthFactor = vm.randomUint(MIN_CLOSE_FACTOR, MAX_CLOSE_FACTOR);
    _updateTargetHealthFactor(spoke, targetHealthFactor.toUint120());

    uint256 liquidationFee = vm.randomUint(MIN_LIQUIDATION_FEE, MAX_LIQUIDATION_FEE);
    _updateLiquidationFee(spoke, collateralReserveId, liquidationFee.toUint16());

    uint256 liquidationBonus = _randomMaxLiquidationBonus(spoke, collateralReserveId);
    _updateMaxLiquidationBonus(spoke, collateralReserveId, liquidationBonus.toUint32());

    _updateCollateralRisk(
      spoke,
      collateralReserveId,
      vm.randomUint(MIN_COLLATERAL_RISK_BPS, MAX_COLLATERAL_RISK_BPS).toUint24()
    );
  }

  function _execBeforeLiquidation(CheckedLiquidationCallParams memory) internal virtual override {
    skip(vm.randomUint(1, MAX_SKIP_TIME / 10)); // avoid overflow
  }

  function _assertBeforeLiquidation(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory /*accountsInfoBefore*/,
    LiquidationMetadata memory /*liquidationMetadata*/
  ) internal virtual override {
    (, uint256 premiumDebt) = params.spoke.getUserDebt(params.debtReserveId, params.user);
    assertGt(premiumDebt, 0, 'premiumDebt: before liquidation, healthy');
  }

  // ---------------------------------------------------------------------------
  // CI repro helpers (panic 0x11 + SafeCast overflows)
  // ---------------------------------------------------------------------------

  function test_repro_ci_panic_manyCollaterals_oneDebt_userInsolvent() public {
    test_liquidationCall_fuzz_ManyCollaterals_OneDebt_UserInsolvent(
      58772587721916056567562,
      292342093363992737667148,
      0x3584b3d733335d3c6903aC58A8651dB758B48966,
      500405680772182772897261902255508377524207968628742969,
      true
    );
  }

  function test_repro_ci_panic_oneCollateral_manyDebts_userInsolvent() public {
    test_liquidationCall_fuzz_OneCollateral_ManyDebts_UserInsolvent(
      9504659555424275796710634647,
      1361541,
      0x7dc67597E5A8caA54B9BE96D342E1C7b04d40Be1,
      2487062459615347113680506620776306258668972807594082251659504390525267061113,
      true
    );
  }

  function test_repro_ci_panic_oneCollateral_oneDebt_userInsolvent() public {
    test_liquidationCall_fuzz_OneCollateral_OneDebt_UserInsolvent(
      3993306322,
      357948625336496608172820008382955474586869789760581921,
      0xd3f2E8A5B9379d0df84461cCa01C37e2A0e1CE50,
      232864733351832222011267087489755378219690878717987539,
      false
    );
  }
}
