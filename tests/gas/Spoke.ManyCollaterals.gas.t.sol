// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

/// forge-config: default.isolate = true
contract SpokeManyCollaterals_Gas_Tests is Base {
  string internal constant NAMESPACE = 'Spoke.ManyCollaterals';
  uint256 internal constant NEW_RESERVES = 128;

  uint256 internal firstNewReserveId;

  /// @dev Strictly ascending risk by reserveId, the quicksort worst case.
  function test_ascendingRisk() external {
    _listReserves(NEW_RESERVES);
    _measure('ascending risk');
  }

  function test_eightRisks() external {
    _listReserves(8);
    _measure('8 risks');
  }

  function test_governance() external {
    _listReserves(NEW_RESERVES);
    string memory reserveCount = vm.toString(spoke1.getReserveCount());

    ISpoke.ReserveConfig memory config = spoke1.getReserveConfig(firstNewReserveId);
    config.collateralRisk = 999_00;
    vm.prank(ADMIN);
    spoke1.updateReserveConfig(firstNewReserveId, config);
    vm.snapshotGasLastCall(
      NAMESPACE,
      string.concat('updateReserveConfig, risk change, reserves: ', reserveCount)
    );

    config.paused = true;
    vm.prank(ADMIN);
    spoke1.updateReserveConfig(firstNewReserveId, config);
    vm.snapshotGasLastCall(
      NAMESPACE,
      string.concat('updateReserveConfig, same risk, reserves: ', reserveCount)
    );

    TestnetERC20 token = new TestnetERC20('TKN', 'TKN', 18);
    vm.prank(ADMIN);
    uint256 assetId = hub1.addAsset(
      address(token),
      18,
      address(treasurySpoke),
      address(irStrategy),
      abi.encode(_defaultIrData)
    );
    address priceSource = _deployMockPriceFeed(spoke1, 1e8);
    vm.prank(ADMIN);
    spoke1.addReserve(
      address(hub1),
      assetId,
      priceSource,
      _getDefaultReserveConfig(5_00),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 10_00
      })
    );
    vm.snapshotGasLastCall(NAMESPACE, string.concat('addReserve, reserves: ', reserveCount));
  }

  function _measure(string memory label) internal {
    uint8[6] memory collateralCounts = [1, 4, 16, 32, 64, 128];
    for (uint256 i; i < collateralCounts.length; ++i) {
      uint256 count = collateralCounts[i];
      uint256 snapshot = vm.snapshotState();

      for (uint256 j; j < count; ++j) {
        SpokeActions.supplyCollateral(spoke1, firstNewReserveId + j, alice, 1000e18, alice);
      }

      vm.prank(alice);
      spoke1.borrow(firstNewReserveId, 1e18, alice);
      vm.snapshotGasLastCall(
        NAMESPACE,
        string.concat(label, ': borrow, collaterals: ', vm.toString(count))
      );

      spoke1.getUserAccountData(alice);
      vm.snapshotGasLastCall(
        NAMESPACE,
        string.concat(label, ': getUserAccountData, collaterals: ', vm.toString(count))
      );

      vm.revertToState(snapshot);
    }
  }

  /// @dev Lists `NEW_RESERVES` reserves on spoke1, cycling through `distinctRisks` ascending risks.
  function _listReserves(uint256 distinctRisks) internal {
    firstNewReserveId = spoke1.getReserveCount();
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: MAX_ALLOWED_SPOKE_CAP,
      drawCap: MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: MAX_ALLOWED_COLLATERAL_RISK
    });
    ISpoke.DynamicReserveConfig memory dynamicConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 80_00,
      maxLiquidationBonus: 105_00,
      liquidationFee: 10_00
    });
    bytes memory irData = abi.encode(_defaultIrData);

    for (uint256 i; i < NEW_RESERVES; ++i) {
      TestnetERC20 token = new TestnetERC20('TKN', 'TKN', 18);
      deal(address(token), alice, MAX_SUPPLY_AMOUNT);
      vm.prank(alice);
      token.approve(address(spoke1), UINT256_MAX);

      vm.startPrank(ADMIN);
      uint256 assetId = hub1.addAsset(
        address(token),
        18,
        address(treasurySpoke),
        address(irStrategy),
        irData
      );
      hub1.addSpoke(assetId, address(spoke1), spokeConfig);
      spoke1.addReserve(
        address(hub1),
        assetId,
        _deployMockPriceFeed(spoke1, 1e8),
        _getDefaultReserveConfig(uint24(10_00 + (i % distinctRisks) * 10)),
        dynamicConfig
      );
      vm.stopPrank();
    }
  }
}
