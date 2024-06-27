// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';

contract AccessManagerContract is AccessManager {
    constructor() AccessManager(address(this)) {}
}