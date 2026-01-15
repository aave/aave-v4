// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';

library Create2Utils {
  error NoCreate2Factory();
  error Create2DeploymentFailed();

  // https://github.com/safe-global/safe-singleton-factory
  address public constant CREATE2_FACTORY = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;
  bytes internal constant CREATE2_FACTORY_BYTECODE =
    hex'7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3';

  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  function loadCreate2Factory() internal {
    if (_isContractDeployed(CREATE2_FACTORY)) {
      return;
    }
    vm.etch(CREATE2_FACTORY, CREATE2_FACTORY_BYTECODE);
  }

  function create2Deploy(bytes32 salt, bytes memory bytecode) internal returns (address) {
    require(_isContractDeployed(CREATE2_FACTORY), NoCreate2Factory());

    address computed = computeCreate2Address(salt, bytecode);

    if (_isContractDeployed(computed)) {
      return computed;
    } else {
      bytes memory creationBytecode = abi.encodePacked(salt, bytecode);
      bytes memory returnData;
      (, returnData) = CREATE2_FACTORY.call(creationBytecode);

      address deployedAt = address(uint160(bytes20(returnData)));
      require(deployedAt == computed, Create2DeploymentFailed());

      return deployedAt;
    }
  }

  function _isContractDeployed(address instance) internal view returns (bool) {
    return (instance.code.length > 0);
  }

  function computeCreate2Address(
    bytes32 salt,
    bytes32 initcodeHash
  ) internal pure returns (address) {
    return
      address(
        uint160(
          uint256(keccak256(abi.encodePacked(bytes1(0xff), CREATE2_FACTORY, salt, initcodeHash)))
        )
      );
  }

  function computeCreate2Address(
    bytes32 salt,
    bytes memory bytecode
  ) internal pure returns (address) {
    return computeCreate2Address(salt, keccak256(abi.encodePacked(bytecode)));
  }
}
