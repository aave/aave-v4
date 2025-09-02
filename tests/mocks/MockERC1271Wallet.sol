// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.24;

import {ECDSA} from 'src/dependencies/openzeppelin/ECDSA.sol';
import {IERC1271} from 'src/dependencies/openzeppelin/IERC1271.sol';

contract MockERC1271Wallet is IERC1271 {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }

    function isValidSignature(bytes32 _hash, bytes memory _signature) public view returns (bytes4) {
        return ECDSA.recover(_hash, _signature) == owner ? this.isValidSignature.selector : bytes4(0);
    }
}