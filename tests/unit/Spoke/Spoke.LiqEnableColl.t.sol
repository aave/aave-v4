// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeLiqEnableColl is SpokeBase {
  function test_liquidation_base() public {
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1_000_000e18, bob);

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1_000_000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    vm.stopPrank();

    _borrowToBeAtHf(spoke1, alice, _daiReserveId(spoke1), 0.9e18);

    skip(100);

    vm.startPrank(bob);

    spoke1.liquidationCall(_usdxReserveId(spoke1), _daiReserveId(spoke1), alice, type(uint256).max);
    console.log(
      'gas base case',
      vm.snapshotGasLastCall('Spoke.Operations', 'liquidationCall: full')
    );

    vm.stopPrank();
  }

  function test_liquidation_enableColls() public {
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1_000_000e18, bob);

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1_000_000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    vm.stopPrank();

    _borrowToBeAtHf(spoke1, alice, _daiReserveId(spoke1), 0.9e18);

    skip(100);

    _enableColls();

    vm.startPrank(bob);
    spoke1.liquidationCall(_usdxReserveId(spoke1), _daiReserveId(spoke1), alice, type(uint256).max);
    console.log(
      'gas with enabled colls',
      vm.snapshotGasLastCall('Spoke.Operations', 'liquidationCall: full')
    );

    vm.stopPrank();
  }

  function _enableColls() internal {
    vm.startPrank(alice);
    for (uint256 i = 0; i < spoke1.getReserveCount(); i++) {
      spoke1.setUsingAsCollateral(i, true, alice);
    }
    vm.stopPrank();

    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
    for (uint256 i = 0; i < 150; i++) {
      TestnetERC20 asset = (new TestnetERC20('asset', 'asset', 18));
      uint256 assetId = _addAsset({
        hub: hub1,
        underlying: address(asset),
        feeReceiver: ITreasurySpoke(new TreasurySpoke(TREASURY_ADMIN, address(hub1))),
        irStrategy: irStrategy,
        liquidityFee: 5_00,
        encodedIrData: encodedIrData
      });
      uint256 reserveId = (
        _addReserveAndSpoke({
          hub: hub1,
          spoke: spoke1,
          assetId: assetId,
          collateralRisk: 15_00,
          collateralFactor: 80_00,
          maxLiquidationBonus: 100_00,
          liquidationFee: 0,
          oraclePrice: 1000e8
        })
      ).reserveId;
      vm.prank(alice);
      spoke1.setUsingAsCollateral(reserveId, true, alice);
    }
  }
}
