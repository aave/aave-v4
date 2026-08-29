// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Spoke.MaxReservesBase.t.sol';

/// forge-config: default.isolate = true
contract SpokeMaxReservesTest is SpokeMaxReservesBaseTest {
  function test_spokeMaxReserves() public {
    uint256 i;
    uint256 gasUsed;
    uint256 gasUsedPrev;
    // Supply x collaterals
    for (i = 0; i < spoke1.getReserveCount(); i++) {
      Utils.supplyCollateral(spoke1, i, alice, 1000e18, alice);

      skip(1 days); // Ensure interest accrual

      vm.prank(alice);
      spoke1.borrow(i, 500e18, alice);
      gasUsed = vm.snapshotGasLastCall('Spoke.Investigation', 'borrow');

      if (gasUsed > MAX_TX_GAS) {
        console.log('OOG at', i + 1, 'collaterals');
        break;
      }

      console.log('Alice could borrow using', i + 1, 'collaterals');
      console.log('Cost', gasUsed);

      if (i + 1 == 10 || i + 1 == 50 || i + 1 == 100 || i + 1 == 150) {
        gasUsedPrev = gasUsed;
      } else if (i + 1 == 11 || i + 1 == 51 || i + 1 == 101 || i + 1 == 151) {
        uint256 gasDiff = gasUsed - gasUsedPrev;
        console.log('Gas increase from ', i);
        console.log(' to ', i + 1);
        console.log(' collaterals: ', gasDiff);
      }
    }

    skip(10000 days);
    // Alice can be liquidated
    assertLe(
      spoke1.getUserAccountData(alice).healthFactor,
      LiquidationLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    console.log('Attempting liquidation with alice at ', i, ' collaterals');
    vm.prank(bob);
    spoke1.liquidationCall(0, 1, alice, 1, false);
    gasUsed = vm.snapshotGasLastCall('Spoke.Investigation', 'liquidationCall');
    if (gasUsed > MAX_TX_GAS) {
      console.log('Liquidation OOG at ', i, ' collaterals');
      return;
    }
    console.log('Liquidation succeeded with alice at ', i, ' collaterals');
    console.log('Cost', gasUsed);
  }

  /// @dev Analyzes the gast cost of liquidating a user with 1 additional reserve in steps
  function test_liquidation_cost_additional_collaterals() public {
    uint256 gasUsed = _liquidationTestHelper(10);
    vm.revertTo(setupSnapshot);
    console.log(
      'Gas diff from liquidating 11 vs 10 collaterals: ',
      _liquidationTestHelper(11) - gasUsed
    );
    vm.revertTo(setupSnapshot);

    gasUsed = _liquidationTestHelper(50);
    vm.revertTo(setupSnapshot);
    console.log(
      'Gas diff from liquidating 51 vs 50 collaterals: ',
      _liquidationTestHelper(51) - gasUsed
    );
    vm.revertTo(setupSnapshot);

    gasUsed = _liquidationTestHelper(100);
    vm.revertTo(setupSnapshot);
    console.log(
      'Gas diff from liquidating 101 vs 100 collaterals: ',
      _liquidationTestHelper(101) - gasUsed
    );
  }

  function test_quote_oracles() public {
    // Check gas price of mock oracle
    IAaveOracle oracle = IAaveOracle(spoke1.ORACLE());
    oracle.getReservePrice(0);
    uint256 gasUsed = vm.snapshotGasLastCall('Spoke.Investigation', 'getReservePrice');
    console.log('Mock oracle gas cost:', gasUsed);

    // Check gas price of chainlink oracle
    vm.createSelectFork('mainnet', 23931982);
    address ethUsdFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    AggregatorV3Interface priceFeed = AggregatorV3Interface(ethUsdFeed);
    priceFeed.latestRoundData();
    gasUsed = vm.snapshotGasLastCall('Spoke.Investigation', 'latestRoundData');
    console.log('Chainlink oracle gas cost:', gasUsed);
  }
}
