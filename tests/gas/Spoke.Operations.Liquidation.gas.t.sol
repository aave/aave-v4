// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/gas/Spoke.Operations.base.gas.t.sol';

/// forge-config: default.isolate = true
contract SpokeOperations_Liquidation_Gas_Tests is SpokeOperationsGasBase {
  function setUp() public override {
    super.setUp();
    _liquidationSetup();
  }

  function test_liquidation_partial() public {
    vm.startPrank(bob);
    spoke.liquidationCall(reserveId.usdx, reserveId.dai, alice, 100_000e18, false);
    vm.snapshotGasLastCall(NAMESPACE, 'liquidationCall: partial');
    vm.stopPrank();
  }

  function test_liquidation_full() public {
    vm.startPrank(bob);
    spoke.liquidationCall(reserveId.usdx, reserveId.dai, alice, UINT256_MAX, false);
    vm.snapshotGasLastCall(NAMESPACE, 'liquidationCall: full');
    vm.stopPrank();
  }

  function test_liquidation_receiveShares_partial() public {
    vm.startPrank(bob);
    spoke.liquidationCall(reserveId.usdx, reserveId.dai, alice, 100_000e18, true);
    vm.snapshotGasLastCall(NAMESPACE, 'liquidationCall (receiveShares): partial');
    vm.stopPrank();
  }

  function test_liquidation_receiveShares_full() public {
    vm.startPrank(bob);
    spoke.liquidationCall(reserveId.usdx, reserveId.dai, alice, UINT256_MAX, true);
    vm.snapshotGasLastCall(NAMESPACE, 'liquidationCall (receiveShares): full');
    vm.stopPrank();
  }

  function _liquidationSetup() internal {
    _updateMaxLiquidationBonus(spoke, _usdxReserveId(spoke), 105_00);
    _updateLiquidationFee(spoke, _usdxReserveId(spoke), 10_00);

    vm.prank(bob);
    spoke.supply(reserveId.dai, 1_000_000e18, bob);

    vm.startPrank(alice);
    spoke.supply(reserveId.usdx, 1_000_000e6, alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);
    vm.stopPrank();

    ISpoke.UserAccountData memory userAccountData = _borrowToBeLiquidatableWithPriceChange(
      spoke,
      alice,
      reserveId.dai,
      reserveId.usdx,
      1.05e18,
      85_00
    );

    skip(100);

    if (keccak256(bytes(NAMESPACE)) == keccak256(bytes('Spoke.Operations.ZeroRiskPremium'))) {
      assertEq(userAccountData.riskPremium, 0); // rp after borrow should be 0
    } else {
      assertGt(userAccountData.riskPremium, 0); // rp after borrow should be non zero
    }
    vm.mockCallRevert(
      address(hub1),
      abi.encodeWithSelector(IHubBase.reportDeficit.selector),
      'deficit'
    );
  }
}

/// forge-config: default.isolate = true
contract SpokeOperations_Liquidation_ZeroRiskPremium_Gas_Tests is
  SpokeOperations_Liquidation_Gas_Tests
{
  function _afterSetUp() internal override {
    NAMESPACE = 'Spoke.Operations.ZeroRiskPremium';

    _updateCollateralRisk(spoke, reserveId.dai, 0);
    _updateCollateralRisk(spoke, reserveId.weth, 0);
    _updateCollateralRisk(spoke, reserveId.usdx, 0);
    _updateCollateralRisk(spoke, reserveId.wbtc, 0);
  }
}
