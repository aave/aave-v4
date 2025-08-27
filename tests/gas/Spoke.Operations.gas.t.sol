// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

/// forge-config: default.isolate = true
contract SpokeOperations_Gas_Tests is Base {
  function setUp() public override {
    deployFixtures();
    initEnvironment();

    vm.startPrank(address(spoke2));
    hub1.add(daiAssetId, 1000e18, bob);
    hub1.add(wethAssetId, 1000e18, bob);
    hub1.add(usdxAssetId, 1000e6, bob);
    hub1.add(wbtcAssetId, 1000e8, bob);
    vm.stopPrank();
  }

  function test_supply() public {
    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply: 0 borrows, collateral disabled');
    skip(100);

    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), true, alice);
    spoke1.supply(_wethReserveId(spoke1), 1e18, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply: 0 borrows, collateral enabled');
    skip(100);

    spoke1.supply(_wethReserveId(spoke1), 1e18, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply: second action, same reserve');
    skip(100);

    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    spoke1.borrow(_daiReserveId(spoke1), 100e18, alice);
    skip(100);

    spoke1.supply(_wbtcReserveId(spoke1), 1e18, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply: 1 borrow');
    vm.stopPrank();
  }

  function test_usingAsCollateral() public {
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, bob);

    vm.startPrank(alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'usingAsCollateral: 0 borrows, enable');

    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.borrow(_daiReserveId(spoke1), 100e18, alice);

    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'usingAsCollateral: 1 borrow, enable');

    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), true, alice);

    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), false, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'usingAsCollateral: 1 borrow, disable');
    vm.stopPrank();
  }

  function test_withdraw() public {
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, bob);

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);

    spoke1.withdraw(_usdxReserveId(spoke1), 500e6, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'withdraw: 0 borrows, partial');

    skip(100);

    spoke1.withdraw(_usdxReserveId(spoke1), 500e6, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'withdraw: 0 borrows, full');

    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.borrow(_daiReserveId(spoke1), 10e18, alice);
    skip(100);

    spoke1.withdraw(_usdxReserveId(spoke1), 500e6, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'withdraw: 1 borrow, partial');
    vm.stopPrank();
  }

  function test_borrow() public {
    vm.startPrank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, bob);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true, bob);
    spoke1.borrow(_daiReserveId(spoke1), 500e18, bob);
    vm.stopPrank();

    skip(100);

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);

    spoke1.borrow(_daiReserveId(spoke1), 500e18, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'borrow: first');

    skip(60);

    spoke1.borrow(_daiReserveId(spoke1), 1e18, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'borrow: second action, same reserve');
    vm.stopPrank();
  }

  function test_restore() public {
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, bob);

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    spoke1.borrow(_daiReserveId(spoke1), 500e18, alice);

    skip(1000);

    spoke1.repay(_daiReserveId(spoke1), 200e18, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'repay: partial');

    skip(1000);
    spoke1.repay(_daiReserveId(spoke1), type(uint256).max, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'repay: full');
    vm.stopPrank();
  }

  function test_liquidation() public {
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1_000_000e18, bob);

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1_000_000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    vm.stopPrank();

    _borrowToBeBelowHf(spoke1, alice, _daiReserveId(spoke1), 0.9e18);

    skip(100);

    vm.startPrank(bob);
    spoke1.liquidationCall(_usdxReserveId(spoke1), _daiReserveId(spoke1), alice, 100_000e18);
    vm.snapshotGasLastCall('Spoke.Operations', 'liquidationCall: partial');

    spoke1.liquidationCall(_usdxReserveId(spoke1), _daiReserveId(spoke1), alice, type(uint256).max);
    vm.snapshotGasLastCall('Spoke.Operations', 'liquidationCall: full');
    vm.stopPrank();
  }

  function test_updateRiskPremium() public {
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, bob);

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 2000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);

    spoke1.borrow(_daiReserveId(spoke1), 500e18, alice);

    spoke1.updateUserRiskPremium(alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'updateUserRiskPremium: 1 borrow');

    spoke1.borrow(_usdxReserveId(spoke1), 500e6, alice);

    spoke1.updateUserRiskPremium(alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'updateUserRiskPremium: 2 borrows');
    vm.stopPrank();
  }

  function test_updateUserDynamicConfig() public {
    vm.startPrank(alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    updateLiquidationFee(spoke1, _usdxReserveId(spoke1), 10_00);

    spoke1.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'updateUserDynamicConfig: 1 collateral');

    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true, alice);
    updateLiquidationFee(spoke1, _daiReserveId(spoke1), 15_00);

    spoke1.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'updateUserDynamicConfig: 2 collaterals');
    vm.stopPrank();
  }

  function test_multicall_ops() public {
    vm.startPrank(alice);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, alice);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.supply(_wbtcReserveId(spoke1), 1e18, alice);
    vm.stopPrank();
    skip(100);
    vm.startPrank(bob);

    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(ISpokeBase.supply, (_daiReserveId(spoke1), 1000e18, bob));
    calls[1] = abi.encodeCall(ISpoke.setUsingAsCollateral, (_daiReserveId(spoke1), true, bob));

    spoke1.multicall(calls);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply + enable collateral (multicall)');

    // supplyWithPermit (dai)
    IHub hub = spoke1.getReserve(_daiReserveId(spoke1)).hub;
    tokenList.dai.approve(address(hub), 0);
    (, uint256 bobPk) = makeAddrAndKey('bob');
    EIP712Types.Permit memory permit = EIP712Types.Permit({
      owner: bob,
      spender: address(hub),
      value: 1000e6,
      nonce: tokenList.dai.nonces(bob),
      deadline: vm.getBlockTimestamp()
    });
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, _getTypedDataHash(tokenList.dai, permit));
    calls[0] = abi.encodeCall(
      ISpoke.permitReserve,
      (_daiReserveId(spoke1), permit.owner, permit.value, permit.deadline, v, r, s)
    );
    calls[1] = abi.encodeCall(
      ISpokeBase.supply,
      (_daiReserveId(spoke1), permit.value, permit.owner)
    );
    spoke1.multicall(calls);
    vm.snapshotGasLastCall('Spoke.Operations', 'permitReserve + supply (multicall)');

    spoke1.borrow(_usdxReserveId(spoke1), 500e6, bob);
    skip(100);

    // repayWithPermit (usdx)
    hub = spoke1.getReserve(_usdxReserveId(spoke1)).hub;
    tokenList.usdx.approve(address(hub), 0);
    permit = EIP712Types.Permit({
      owner: bob,
      spender: address(hub),
      value: 500e6,
      nonce: tokenList.usdx.nonces(bob),
      deadline: vm.getBlockTimestamp()
    });
    (v, r, s) = vm.sign(bobPk, _getTypedDataHash(tokenList.usdx, permit));
    calls[0] = abi.encodeCall(
      ISpoke.permitReserve,
      (_usdxReserveId(spoke1), permit.owner, permit.value, permit.deadline, v, r, s)
    );
    calls[1] = abi.encodeCall(
      ISpokeBase.repay,
      (_usdxReserveId(spoke1), permit.value, permit.owner)
    );
    spoke1.multicall(calls);
    vm.snapshotGasLastCall('Spoke.Operations', 'permitReserve + repay (multicall)');

    skip(100);

    // supplyWithPermitAndEnableCollateral (wbtc)
    calls = new bytes[](3);
    hub = spoke1.getReserve(_wbtcReserveId(spoke1)).hub;
    tokenList.wbtc.approve(address(hub), 0);
    (, bobPk) = makeAddrAndKey('bob');
    permit = EIP712Types.Permit({
      owner: bob,
      spender: address(hub),
      value: 1000e6,
      nonce: tokenList.wbtc.nonces(bob),
      deadline: vm.getBlockTimestamp()
    });
    (v, r, s) = vm.sign(bobPk, _getTypedDataHash(tokenList.wbtc, permit));
    calls[0] = abi.encodeCall(
      ISpoke.permitReserve,
      (_wbtcReserveId(spoke1), permit.owner, permit.value, permit.deadline, v, r, s)
    );
    calls[1] = abi.encodeCall(
      ISpokeBase.supply,
      (_wbtcReserveId(spoke1), permit.value, permit.owner)
    );
    calls[2] = abi.encodeCall(
      ISpoke.setUsingAsCollateral,
      (_wbtcReserveId(spoke1), true, permit.owner)
    );
    spoke1.multicall(calls);
    vm.snapshotGasLastCall(
      'Spoke.Operations',
      'permitReserve + supply + enable collateral (multicall)'
    );

    vm.stopPrank();
  }
}
