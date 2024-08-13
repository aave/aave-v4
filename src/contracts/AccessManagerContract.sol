// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Authority, Auth} from '@solmate/auth/Auth.sol';
import {RolesAuthority} from '@solmate/auth/authorities/RolesAuthority.sol';

contract AccessManagerContract is RolesAuthority {
  uint8 public constant RESERVE_CONTROLLER = 1;
  uint8 public constant INTEREST_RATE_CONTROLLER = 2;
  uint8 public constant RISK_CONTROLLER = 3;

  uint8 public constant POOL_MANAGER = 4;
  uint8 public constant EMERGENCY_MANAGER = 5;
  uint8 public constant RISK_MANAGER = 6;
  uint8 public constant FLASH_BORROWER = 7;
  uint8 public constant BRIDGE = 8;
  uint8 public constant ASSET_LISTER = 9;
  uint8 public constant POOL_CONFIGURATOR = 10;
  uint8 public constant ISOLATED_COLLATERAL_SUPPLIER = 11;
  uint8 public constant FUNDS_MANAGER = 12;
  uint8 public constant MARKET_OWNER = 13;
  uint8 public constant EMISSION_MANAGER = 14;
  uint8 public constant REWARDS_MANAGER = 15;
  uint8 public constant INCENTIVES_CONTROLLER = 16;

  constructor() RolesAuthority(msg.sender, Authority(address(this))) {}
}
