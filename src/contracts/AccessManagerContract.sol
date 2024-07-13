// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Authority, Auth} from '@solmate/auth/Auth.sol';
import {RolesAuthority} from '@solmate/auth/authorities/RolesAuthority.sol';

contract AccessManagerContract is RolesAuthority {
    uint8 public constant RESERVE_CONTROLLER = 1;
    uint8 public constant INTEREST_RATE_CONTROLLER = 2;
    uint8 public constant RISK_CONTROLLER = 3;

    constructor() RolesAuthority(msg.sender, Authority(address(this))) {}
}