// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from 'forge-std/Test.sol';
import {KeyValueList} from 'src/spoke/libraries/KeyValueList.sol';
import {RiskTierList} from 'src/spoke/libraries/RiskTierList.sol';

contract RiskTierListTest is Test {
  using KeyValueList for KeyValueList.List;
  using RiskTierList for RiskTierList.List;

  struct Collateral {
    uint256 tier;
    uint256 risk;
    uint256 value;
  }

  function test_fuzz_matchesSortedRiskPremium(
    uint256 seed,
    uint8 count,
    uint8 tierCount,
    uint256 debtValue
  ) public pure {
    tierCount = uint8(bound(tierCount, 1, 255));
    Collateral[] memory collaterals = _collaterals(seed, count, tierCount);
    debtValue = bound(debtValue, 0, 1e40);
    assertEq(_premiumTiered(collaterals, debtValue), _premiumSorted(collaterals, debtValue));
  }

  function test_gas_comparison() public {
    uint8[6] memory counts = [4, 8, 16, 32, 64, 128];
    uint8[3] memory tierCounts = [8, 32, 128];
    for (uint256 i; i < counts.length; ++i) {
      for (uint256 j; j < tierCounts.length; ++j) {
        Collateral[] memory collaterals = _collaterals(i * 31 + j, counts[i], tierCounts[j]);
        // debt above total collateral forces the full premium loop
        uint256 debtValue = type(uint128).max;

        uint256 gasBefore = gasleft();
        uint256 sorted = _premiumSorted(collaterals, debtValue);
        uint256 sortedGas = gasBefore - gasleft();

        gasBefore = gasleft();
        uint256 tiered = _premiumTiered(collaterals, debtValue);
        uint256 tieredGas = gasBefore - gasleft();

        gasBefore = gasleft();
        _baseline(collaterals);
        uint256 baselineGas = gasBefore - gasleft();

        assertEq(tiered, sorted);
        console2.log('collaterals %d tiers %d', counts[i], tierCounts[j]);
        console2.log('  sort %d tier %d', sortedGas - baselineGas, tieredGas - baselineGas);
      }
    }
  }

  /// @dev Distinct risks inserted in ascending and descending order, the OZ quicksort worst cases.
  function test_gas_comparison_sortedInput() public {
    uint8[3] memory counts = [16, 64, 128];
    for (uint256 i; i < counts.length; ++i) {
      for (uint256 descending; descending < 2; ++descending) {
        Collateral[] memory collaterals = new Collateral[](counts[i]);
        for (uint256 c; c < counts[i]; ++c) {
          uint256 tier = descending == 1 ? counts[i] - 1 - c : c;
          collaterals[c] = Collateral({tier: tier, risk: tier * 250, value: 1e20 + c});
        }
        uint256 debtValue = type(uint128).max;

        uint256 gasBefore = gasleft();
        uint256 sorted = _premiumSorted(collaterals, debtValue);
        uint256 sortedGas = gasBefore - gasleft();

        gasBefore = gasleft();
        uint256 tiered = _premiumTiered(collaterals, debtValue);
        uint256 tieredGas = gasBefore - gasleft();

        gasBefore = gasleft();
        _baseline(collaterals);
        uint256 baselineGas = gasBefore - gasleft();

        assertEq(tiered, sorted);
        console2.log('collaterals %d descending %d', counts[i], descending);
        console2.log('  sort %d tier %d', sortedGas - baselineGas, tieredGas - baselineGas);
      }
    }
  }

  function _premiumSorted(
    Collateral[] memory collaterals,
    uint256 debtValue
  ) internal pure returns (uint256 premium) {
    KeyValueList.List memory list = KeyValueList.init(collaterals.length);
    for (uint256 i; i < collaterals.length; ++i) {
      list.add(i, collaterals[i].risk, collaterals[i].value);
    }
    list.sortByKey();
    for (uint256 i; i < list.length() && debtValue > 0; ++i) {
      (uint256 risk, uint256 value) = list.uncheckedAt(i);
      value = value < debtValue ? value : debtValue;
      premium += value * risk;
      debtValue -= value;
    }
  }

  function _premiumTiered(
    Collateral[] memory collaterals,
    uint256 debtValue
  ) internal pure returns (uint256 premium) {
    RiskTierList.List memory list = RiskTierList.init();
    for (uint256 i; i < collaterals.length; ++i) {
      list.add(collaterals[i].tier, collaterals[i].risk, collaterals[i].value);
    }
    while (debtValue > 0) {
      (bool found, uint256 risk, uint256 value) = list.popLowest();
      if (!found) break;
      value = value < debtValue ? value : debtValue;
      premium += value * risk;
      debtValue -= value;
    }
  }

  /// @dev Reads every collateral like both strategies do, to subtract harness overhead.
  function _baseline(Collateral[] memory collaterals) internal pure returns (uint256 acc) {
    for (uint256 i; i < collaterals.length; ++i) {
      acc += collaterals[i].tier + collaterals[i].risk + collaterals[i].value;
    }
  }

  /// @dev Tier `t` maps to risk `t * 250` so tiers are a dense, ascending rank of distinct risks.
  function _collaterals(
    uint256 seed,
    uint256 count,
    uint256 tierCount
  ) internal pure returns (Collateral[] memory collaterals) {
    collaterals = new Collateral[](count);
    for (uint256 i; i < count; ++i) {
      uint256 rand = uint256(keccak256(abi.encode(seed, i)));
      uint256 tier = rand % tierCount;
      collaterals[i] = Collateral({tier: tier, risk: tier * 250, value: (rand >> 128) % 1e30});
    }
  }
}
