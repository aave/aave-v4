  
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Roles
 * @author Aave Labs
 * @notice Defines the roles for the AccessManagerContract
 */
 library Roles { 
  uint8 public constant RESERVE_CONTROLLER = 1;
  uint8 public constant POOL_MANAGER = 2;
  uint8 public constant EMERGENCY_MANAGER = 3;
  uint8 public constant RISK_MANAGER = 4;
  uint8 public constant FLASH_BORROWER = 5;
  uint8 public constant BRIDGE = 6;
  uint8 public constant ASSET_LISTER = 7;
  uint8 public constant POOL_CONFIGURATOR = 8;
  uint8 public constant ISOLATED_COLLATERAL_SUPPLIER = 9;
  uint8 public constant FUNDS_MANAGER = 10;
  uint8 public constant MARKET_OWNER = 11;
  uint8 public constant EMISSION_MANAGER = 12;
  uint8 public constant REWARDS_MANAGER = 13;
  uint8 public constant INCENTIVES_CONTROLLER = 14;
 }