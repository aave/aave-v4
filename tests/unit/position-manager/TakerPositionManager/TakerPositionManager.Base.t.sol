// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract TakerPositionManagerBaseTest is SpokeBase {
  TakerPositionManager public positionManager;
  TestReturnValues public returnValues;

  function setUp() public virtual override {
    super.setUp();

    positionManager = new TakerPositionManager(address(ADMIN));

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);

    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), true);

    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);
  }

  function _withdrawPermitData(
    address spender,
    address onBehalfOf,
    uint256 deadline
  ) internal returns (ITakerPositionManager.WithdrawPermit memory) {
    return
      ITakerPositionManager.WithdrawPermit({
        spoke: address(spoke1),
        reserveId: _randomReserveId(spoke1),
        owner: onBehalfOf,
        spender: spender,
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        nonce: positionManager.nonces(onBehalfOf, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _approveBorrowData(
    address spender,
    address onBehalfOf,
    uint256 deadline
  ) internal returns (ITakerPositionManager.BorrowPermit memory) {
    return
      ITakerPositionManager.BorrowPermit({
        spoke: address(spoke1),
        reserveId: _randomReserveId(spoke1),
        owner: onBehalfOf,
        spender: spender,
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        nonce: positionManager.nonces(onBehalfOf, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _getTypedDataHash(
    ITakerPositionManager _positionManager,
    ITakerPositionManager.WithdrawPermit memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(_positionManager, vm.eip712HashStruct('WithdrawPermit', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ITakerPositionManager _positionManager,
    ITakerPositionManager.BorrowPermit memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(_positionManager, vm.eip712HashStruct('BorrowPermit', abi.encode(_params)));
  }

  function _typedDataHash(
    ITakerPositionManager _positionManager,
    bytes32 typeHash
  ) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', _positionManager.DOMAIN_SEPARATOR(), typeHash));
  }
}
