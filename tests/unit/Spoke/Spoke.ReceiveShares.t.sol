// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeReceiveSharesTest is SpokeBase {
  function setUp() public override {
    super.setUp();
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _openSupplyPosition(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _openSupplyPosition(spoke1, _usdyReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _openSupplyPosition(spoke1, _wbtcReserveId(spoke1), MAX_SUPPLY_AMOUNT);

    _openDebtPosition(spoke1, _wbtcReserveId(spoke1), MAX_SUPPLY_AMOUNT / 2, true);
    _openDebtPosition(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT / 2, true);
    _openDebtPosition(spoke1, _usdyReserveId(spoke1), MAX_SUPPLY_AMOUNT / 2, true);
    _openDebtPosition(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT / 2, true);

    skip(1);
  }

  function test_spoke_receive_shares() public {
    console.log('supply ex rate %e', hub1.previewRemoveByShares(wbtcAssetId, MAX_SUPPLY_AMOUNT));
    console.log('debt ex rate %e', hub1.previewRestoreByShares(wbtcAssetId, MAX_SUPPLY_AMOUNT));

    Utils.supplyCollateral(spoke1, _wbtcReserveId(spoke1), alice, 1e10, alice);
    _borrowToBeAtHf(spoke1, alice, _usdxReserveId(spoke1), 0.9e18);

    for (uint256 i = 0; i < 1000; i++) {
      // console.log('block.timestamp %e', vm.getBlockTimestamp());

      // Utils.borrow(spoke1, _wbtcReserveId(spoke1), alice, 1e3, alice);

      // console.log('balance %e', tokenList.wbtc.balanceOf(alice));
      // console.log('debt %e', spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), alice));
      // console.log('hf %e', _getUserHealthFactor(spoke1, alice));

      // _mockReservePrice(spoke1, _usdxReserveId(spoke1), 0.5e8);

      vm.prank(bob);
      spoke1.liquidationCall(_wbtcReserveId(spoke1), _usdxReserveId(spoke1), alice, 1, true);
    }

    console.log('debt %e', spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice));
    console.log('hf %e', _getUserHealthFactor(spoke1, alice));
  }
}
