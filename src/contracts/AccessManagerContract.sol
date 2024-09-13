// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Authority} from '../dependencies/solmate/Auth.sol';
import {RolesAuthority} from '../dependencies/solmate/RolesAuthority.sol';

/**
 * @title AccessManagerContract
 * @author Aave Labs
 * @notice Handles access management for Aave V4
 * @dev Contracts requiring access control should inherit from this contract
 * @dev Restricted functions should use the `requiresAuth` modifier
 */
contract AccessManagerContract is RolesAuthority {
  constructor() RolesAuthority(msg.sender, Authority(address(this))) {}
}
