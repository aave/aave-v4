// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.LiquidationCall.t.sol';

contract SpokeLiquidationCallPremiumTest is SpokeLiquidationCallHelperTest {
  using SafeCast for uint256;

  uint256 internal baseAmountValue;

  function setUp() public virtual override {
    super.setUp();
    baseAmountValue = vm.randomUint(MIN_AMOUNT_IN_BASE_CURRENCY, MAX_AMOUNT_IN_BASE_CURRENCY);
  }

  function _baseAmountValue() internal virtual override returns (uint256) {
    return baseAmountValue;
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
    skip(vm.randomUint(1, MAX_SKIP_TIME));
  }

  function _assertBeforeLiquidation(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory /*accountsInfoBefore*/,
    LiquidationMetadata memory /*liquidationMetadata*/
  ) internal virtual override {
    (, uint256 premiumDebt) = params.spoke.getUserDebt(params.debtReserveId, params.user);
    assertGt(premiumDebt, 0, 'premiumDebt: before liquidation, healthy');
  }
}
