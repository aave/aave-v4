// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';

contract AccessManagerContract is AccessControl {
    bytes32 public constant RESERVE_CONTROLLER = keccak256("RESERVE_CONTROLLER");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}