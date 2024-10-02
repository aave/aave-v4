// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Authority} from 'src/dependencies/solmate/Auth.sol';
import {RolesAuthority} from 'src/dependencies/solmate/RolesAuthority.sol';

/**
 * @title AaveAuthority
 * @author Aave Labs
 * @notice Handles access management for Aave V4
 * @dev This contract may be replaced if required to change access management patterns
 */
contract AaveAuthority is RolesAuthority {
  constructor(address owner) RolesAuthority(owner, Authority(address(this))) {}
}
