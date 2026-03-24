// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';

library Create2Utils {
  // https://github.com/safe-global/safe-singleton-factory
  address public constant CREATE2_FACTORY = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;

  error MissingCreate2Factory();
  error Create2AddressDerivationFailure();
  error FailedCreate2FactoryCall();
  error ContractAlreadyDeployed();

  function create2Deploy(bytes32 salt, bytes memory bytecode) internal returns (address) {
    require(isContractDeployed(CREATE2_FACTORY), MissingCreate2Factory());
    address computed = computeCreate2Address({salt: salt, bytecode: bytecode});
    require(!isContractDeployed(computed), ContractAlreadyDeployed());
    bytes memory creationBytecode = abi.encodePacked(salt, bytecode);
    (bool success, bytes memory returnData) = CREATE2_FACTORY.call(creationBytecode);
    require(success, FailedCreate2FactoryCall());
    address deployedAt = address(uint160(bytes20(returnData)));
    require(deployedAt == computed, Create2AddressDerivationFailure());
    return deployedAt;
  }

  function proxify(
    bytes32 salt,
    address logic,
    address initialOwner,
    bytes memory data
  ) internal returns (address) {
    return
      create2Deploy(
        salt,
        abi.encodePacked(
          type(TransparentUpgradeableProxy).creationCode,
          abi.encode(logic, initialOwner, data)
        )
      );
  }

  function isContractDeployed(address _addr) internal view returns (bool isContract) {
    return (_addr.code.length > 0);
  }

  function computeCreate2Address(
    bytes32 salt,
    bytes32 initcodeHash
  ) internal pure returns (address) {
    return
      addressFromLast20Bytes(
        keccak256(abi.encodePacked(bytes1(0xff), CREATE2_FACTORY, salt, initcodeHash))
      );
  }

  function computeCreate2Address(
    bytes32 salt,
    bytes memory bytecode
  ) internal pure returns (address) {
    return computeCreate2Address(salt, keccak256(bytecode));
  }

  function addressFromLast20Bytes(bytes32 bytesValue) internal pure returns (address) {
    return address(uint160(uint256(bytesValue)));
  }
}
