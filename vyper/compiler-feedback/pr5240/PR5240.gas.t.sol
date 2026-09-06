// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract PR5240GasTest is Base {
  function test_accessManagerGas() public {
    IAccessManager manager = IAccessManager(hub1.authority());
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHub.mintFeeShares.selector;
    vm.startPrank(ADMIN);
    uint256 beforeGas = gasleft();
    manager.setTargetFunctionRole(address(hub1), selectors, 777);
    emit log_named_uint('setTargetFunctionRole', beforeGas - gasleft());
    manager.grantRole(777, alice, 100);
    vm.stopPrank();
    bytes memory data = abi.encodeCall(IHub.mintFeeShares, (daiAssetId));
    vm.prank(alice);
    beforeGas = gasleft();
    (bytes32 operationId,) = manager.schedule(address(hub1), data, 0);
    emit log_named_uint('schedule', beforeGas - gasleft());
    vm.warp(block.timestamp + 100);
    vm.prank(alice);
    beforeGas = gasleft();
    hub1.mintFeeShares(daiAssetId);
    emit log_named_uint('managed call including consumeScheduledOp', beforeGas - gasleft());
    assertEq(manager.getSchedule(operationId), 0);
  }
}
