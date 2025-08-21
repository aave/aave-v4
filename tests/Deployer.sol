// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

library Deployer {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

    function deploySpoke(address authority, bytes memory salt) internal returns (ISpoke spoke) {
        bytes memory args = abi.encode(authority);
        bytes memory initcode = abi.encodePacked(vm.getCode('contracts/Spoke.sol:Spoke'), args);
        assembly {
            spoke := create2(0, add(initcode, 0x20), mload(initcode), salt)
        }
    }
}