// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/BabylonBase.t.sol';
import 'tests/gas/Spoke.Operations.gas.t.sol';

/// forge-config: default.isolate = true
contract BabylonSpokeOperations_Gas_Tests is BabylonBase, SpokeOperations_Gas_Tests {
  function setUp() public override(BabylonBase, SpokeOperations_Gas_Tests) {
    super.setUp();
    NAMESPACE = 'BabylonSpoke.Operations';

    // the inherited suite runs against the engine-deployed babylon spoke; bob acts as the
    // liquidation manager over the usdx managed collateral, matching the canonical liquidation
    // reserves so the snapshots stay comparable
    spoke = spoke4;
    reserveId = _getReserveIds(spoke);
    vm.prank(ADMIN);
    babylonSpoke.updateBabylonLiquidationConfig(bob, reserveId.usdx);
  }

  function test_liquidation_partial() public override {
    _liquidationSetup(85_00);

    vm.startPrank(bob);
    babylonSpoke.liquidationCall(_arr(reserveId.dai), _arr(100_000e18), alice, 2_000_000e6);
    vm.snapshotGasLastFrame(NAMESPACE, 'liquidationCall: partial');
    vm.stopPrank();
  }

  function test_liquidation_full() public override {
    _liquidationSetup(85_00);

    vm.startPrank(bob);
    babylonSpoke.liquidationCall(_arr(reserveId.dai), _arr(UINT256_MAX), alice, 2_000_000e6);
    vm.snapshotGasLastFrame(NAMESPACE, 'liquidationCall: full');
    vm.stopPrank();
  }

  function test_liquidation_collateralCapEnforced_partial() public {
    _liquidationSetup(85_00);

    vm.startPrank(bob);
    babylonSpoke.liquidationCall(_arr(reserveId.dai), _arr(100_000e18), alice, 50_000e6);
    vm.snapshotGasLastFrame(NAMESPACE, 'liquidationCall (collateralCapEnforced): partial');
    vm.stopPrank();
  }

  function test_liquidation_multiDebt_partial() public {
    _updateMaxLiquidationBonus(spoke, _usdxReserveId(spoke), 105_00);
    _updateLiquidationFee(spoke, _usdxReserveId(spoke), 10_00);

    vm.prank(bob);
    spoke.supply(reserveId.dai, 1_000_000e18, bob);

    vm.startPrank(alice);
    spoke.supply(reserveId.usdx, 1_000_000e6, alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);
    spoke.borrow(reserveId.weth, 1e18, alice);
    vm.stopPrank();

    _borrowToBeLiquidatableWithPriceChange(
      spoke,
      alice,
      reserveId.dai,
      reserveId.usdx,
      1.05e18,
      85_00
    );
    skip(100);

    vm.startPrank(bob);
    babylonSpoke.liquidationCall(
      _arr(reserveId.weth, reserveId.dai),
      _arr(UINT256_MAX, 100_000e18),
      alice,
      2_000_000e6
    );
    vm.snapshotGasLastFrame(NAMESPACE, 'liquidationCall (multiDebt): partial');
    vm.stopPrank();
  }

  function test_liquidation_reportDeficit_full() public override {
    _liquidationSetup(45_00);

    vm.startPrank(bob);
    babylonSpoke.liquidationCall(_arr(reserveId.dai), _arr(UINT256_MAX), alice, 2_000_000e6);
    vm.snapshotGasLastFrame(NAMESPACE, 'liquidationCall (reportDeficit): full');
    vm.stopPrank();
  }

  /// @dev Only the managed collateral reserve (usdx) can be registered as collateral.
  function test_supply() public override {
    vm.startPrank(alice);
    spoke.supply(reserveId.usdx, 1000e6, alice);
    vm.snapshotGasLastFrame(NAMESPACE, 'supply: 0 borrows, collateral disabled');

    spoke.supply(reserveId.usdx, 1000e6, alice);
    vm.snapshotGasLastFrame(NAMESPACE, 'supply: second action, same reserve');

    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);
    spoke.supply(reserveId.usdx, 1000e6, alice);
    vm.snapshotGasLastFrame(NAMESPACE, 'supply: 0 borrows, collateral enabled');
    vm.stopPrank();
  }

  /// @dev Only the managed collateral reserve (usdx) can be registered as collateral.
  function test_borrow() public override {
    vm.startPrank(bob);
    spoke.supply(reserveId.dai, 1000e18, bob);
    spoke.supply(reserveId.usdx, 1000e6, bob);
    spoke.setUsingAsCollateral(reserveId.usdx, true, bob);
    spoke.borrow(reserveId.dai, 500e18, bob);
    skip(100);
    spoke.borrow(reserveId.dai, 1e18, bob);
    vm.stopPrank();

    skip(100);

    vm.startPrank(alice);
    spoke.supply(reserveId.usdx, 1000e6, alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);

    spoke.borrow(reserveId.dai, 500e18, alice);
    vm.snapshotGasLastFrame(NAMESPACE, 'borrow: first');

    skip(100);

    spoke.borrow(reserveId.dai, 1e18, alice);
    vm.snapshotGasLastFrame(NAMESPACE, 'borrow: second action, same reserve');
    vm.stopPrank();
  }

  /// @dev A single collateral can be registered on the BabylonSpoke, and it cannot be disabled
  /// while backing a borrow: enable and disable are measured with no borrows.
  function test_usingAsCollateral() public override {
    vm.startPrank(alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);
    vm.snapshotGasLastFrame(NAMESPACE, 'usingAsCollateral: 0 borrows, enable');

    spoke.setUsingAsCollateral(reserveId.usdx, false, alice);
    vm.snapshotGasLastFrame(NAMESPACE, 'usingAsCollateral: 0 borrows, disable');
    vm.stopPrank();
  }

  /// @dev A single collateral can be registered on the BabylonSpoke.
  function test_updateUserDynamicConfig() public override {
    vm.startPrank(alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);
    _updateLiquidationFee(spoke, reserveId.usdx, 10_00);

    spoke.updateUserDynamicConfig(alice);
    vm.snapshotGasLastFrame(NAMESPACE, 'updateUserDynamicConfig: 1 collateral');
    vm.stopPrank();
  }

  /// @dev A single collateral can be registered on the BabylonSpoke: the wbtc supply-and-enable
  /// multicall is not measured.
  function test_multicall_ops() public override {
    vm.startPrank(bob);
    spoke.supply(reserveId.dai, 1000e18, bob);
    spoke.supply(reserveId.usdx, 1000e6, bob);

    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(ISpoke.supply, (reserveId.usdx, 1000e6, bob));
    calls[1] = abi.encodeCall(ISpoke.setUsingAsCollateral, (reserveId.usdx, true, bob));

    spoke.multicall(calls);
    vm.snapshotGasLastFrame(NAMESPACE, 'supply + enable collateral (multicall)');

    // supplyWithPermit (dai)
    tokenList.dai.approve(address(spoke), 0);
    EIP712Types.Permit memory permit = EIP712Types.Permit({
      owner: bob,
      spender: address(spoke),
      value: 1000e6,
      nonce: tokenList.dai.nonces(bob),
      deadline: vm.getBlockTimestamp()
    });
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, _getTypedDataHash(tokenList.dai, permit));
    calls[0] = abi.encodeCall(
      ISpoke.permitReserve,
      (reserveId.dai, permit.owner, permit.value, permit.deadline, v, r, s)
    );
    calls[1] = abi.encodeCall(ISpoke.supply, (reserveId.dai, permit.value, permit.owner));
    spoke.multicall(calls);
    vm.snapshotGasLastFrame(NAMESPACE, 'permitReserve + supply (multicall)');

    spoke.borrow(reserveId.usdx, 500e6, bob);

    // repayWithPermit (usdx)
    tokenList.usdx.approve(address(spoke), 0);
    permit = EIP712Types.Permit({
      owner: bob,
      spender: address(spoke),
      value: 500e6,
      nonce: tokenList.usdx.nonces(bob),
      deadline: vm.getBlockTimestamp()
    });
    (v, r, s) = vm.sign(bobPk, _getTypedDataHash(tokenList.usdx, permit));
    calls[0] = abi.encodeCall(
      ISpoke.permitReserve,
      (reserveId.usdx, permit.owner, permit.value, permit.deadline, v, r, s)
    );
    calls[1] = abi.encodeCall(ISpoke.repay, (reserveId.usdx, permit.value, permit.owner));
    spoke.multicall(calls);
    vm.snapshotGasLastFrame(NAMESPACE, 'permitReserve + repay (multicall)');

    vm.stopPrank();
  }

  /// @dev The liquidator always receives underlying assets on the BabylonSpoke.
  function test_liquidation_receiveShares_partial() public override {}

  /// @dev The liquidator always receives underlying assets on the BabylonSpoke.
  function test_liquidation_receiveShares_full() public override {}
}
