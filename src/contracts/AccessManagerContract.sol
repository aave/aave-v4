// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';

/**
 * @title AccessManagerContract
 * @author Aave Labs
 * @notice Contract to manage access control
 * @dev Contracts wishing to use access control should inherit from this contract
 * @dev We have grantRole() and revokeRole() functions to manage roles
 * @dev We have hasRole() function to check if an address has a role
 * @dev By default, the deployer of the contract has DEFAULT_ADMIN_ROLE and can grant and revoke any role
 * @dev We define role admins to grant and revoke the corresponding role
 * @dev We have onlyRole() modifier to restrict access to functions based on roles
 */
contract AccessManagerContract is AccessControl {
  bytes32 public constant RESERVE_CONTROLLER = keccak256('RESERVE_CONTROLLER');
  bytes32 public constant RESERVE_CONTROLLER_ADMIN = keccak256('RESERVE_CONTROLLER_ADMIN');
  bytes32 public constant POOL_MANAGER = keccak256('POOL_MANAGER');
  bytes32 public constant POOL_MANAGER_ADMIN = keccak256('POOL_MANAGER_ADMIN');
  bytes32 public constant EMERGENCY_MANAGER = keccak256('EMERGENCY_MANAGER');
  bytes32 public constant EMERGENCY_MANAGER_ADMIN = keccak256('EMERGENCY_MANAGER_ADMIN');
  bytes32 public constant RISK_MANAGER = keccak256('RISK_MANAGER');
  bytes32 public constant RISK_MANAGER_ADMIN = keccak256('RISK_MANAGER_ADMIN');
  bytes32 public constant FLASH_BORROWER = keccak256('FLASH_BORROWER');
  bytes32 public constant FLASH_BORROWER_ADMIN = keccak256('FLASH_BORROWER_ADMIN');
  bytes32 public constant BRIDGE = keccak256('BRIDGE');
  bytes32 public constant BRIDGE_ADMIN = keccak256('BRIDGE_ADMIN');
  bytes32 public constant ASSET_LISTER = keccak256('ASSET_LISTER');
  bytes32 public constant ASSET_LISTER_ADMIN = keccak256('ASSET_LISTER_ADMIN');
  bytes32 public constant POOL_CONFIGURATOR = keccak256('POOL_CONFIGURATOR');
  bytes32 public constant POOL_CONFIGURATOR_ADMIN = keccak256('POOL_CONFIGURATOR_ADMIN');
  bytes32 public constant ISOLATED_COLLATERAL_SUPPLIER = keccak256('ISOLATED_COLLATERAL_SUPPLIER');
  bytes32 public constant ISOLATED_COLLATERAL_SUPPLIER_ADMIN =
    keccak256('ISOLATED_COLLATERAL_SUPPLIER_ADMIN');
  bytes32 public constant FUNDS_MANAGER = keccak256('FUNDS_MANAGER');
  bytes32 public constant FUNDS_MANAGER_ADMIN = keccak256('FUNDS_MANAGER_ADMIN');
  bytes32 public constant MARKET_OWNER = keccak256('MARKET_OWNER'); // Ensure this is used like a role
  bytes32 public constant MARKET_OWNER_ADMIN = keccak256('MARKET_OWNER_ADMIN');
  bytes32 public constant EMISSION_MANAGER = keccak256('EMISSION_MANAGER');
  bytes32 public constant EMISSION_MANAGER_ADMIN = keccak256('EMISSION_MANAGER_ADMIN');
  bytes32 public constant REWARDS_MANAGER = keccak256('REWARDS_MANAGER');
  bytes32 public constant REWARDS_MANAGER_ADMIN = keccak256('REWARDS_MANAGER_ADMIN');
  bytes32 public constant INCENTIVES_CONTROLLER = keccak256('INCENTIVES_CONTROLLER');
  bytes32 public constant INCENTIVES_CONTROLLER_ADMIN = keccak256('INCENTIVES_CONTROLLER_ADMIN');

  /**
   * @dev Only pool manager can call functions marked by this modifier.
   */
  modifier onlyPoolManager() {
    require(hasRole(POOL_MANAGER, msg.sender), 'NOT_POOL_MANAGER');
    _;
  }

  /**
   * @dev Only emergency manager can call functions marked by this modifier.
   */
  modifier onlyEmergencyManager() {
    require(hasRole(EMERGENCY_MANAGER, msg.sender), 'NOT_EMERGENCY_MANAGER');
    _;
  }

  /**
   * @dev Only bridge can call functions marked by this modifier.
   */
  modifier onlyBridge() {
    require(hasRole(BRIDGE, msg.sender), 'NOT_BRIDGE');
    _;
  }

  /**
   * @dev Only pool configurator can call functions marked by this modifier.
   */
  modifier onlyPoolConfigurator() {
    require(hasRole(POOL_CONFIGURATOR, msg.sender), 'NOT_POOL_CONFIGURATOR');
    _;
  }

  /**
   * @dev Only isolated collateral supplier can call functions marked by this modifier.
   */
  modifier onlyIsolatedCollateralSupplier() {
    require(hasRole(ISOLATED_COLLATERAL_SUPPLIER, msg.sender), 'NOT_ISOLATED_COLLATERAL_SUPPLIER');
    _;
  }

  /**
   * @dev Only funds manager can call functions marked by this modifier.
   */
  modifier onlyFundsManager() {
    require(hasRole(FUNDS_MANAGER, msg.sender), 'NOT_FUNDS_MANAGER');
    _;
  }

  /**
   * @dev Only emission manager can call functions marked by this modifier.
   */
  modifier onlyEmissionManager() {
    require(hasRole(EMISSION_MANAGER, msg.sender), 'NOT_EMISSION_MANAGER');
    _;
  }

  /**
   * @dev Modifier for rewards manager only functions
   */
  modifier onlyRewardsManager() {
    require(hasRole(REWARDS_MANAGER, msg.sender), 'ONLY_REWARDS_MANAGER');
    _;
  }

  /**
   * @dev Modifier for incentives controller only functions
   */
  modifier onlyIncentivesController() {
    require(hasRole(INCENTIVES_CONTROLLER, msg.sender), 'CALLER_NOT_INCENTIVES_CONTROLLER');
    _;
  }

  /**
   * @dev Only asset lister or pool manager can call functions marked by this modifier.
   */
  modifier onlyAssetListerOrPoolManager() {
    require(
      hasRole(ASSET_LISTER, msg.sender) || hasRole(POOL_MANAGER, msg.sender),
      'NOT_ASSET_LISTER_OR_POOL_MANAGER'
    );
    _;
  }

  /**
   * @dev Only emergency or pool manager can call functions marked by this modifier.
   */
  modifier onlyEmergencyOrPoolManager() {
    require(
      hasRole(EMERGENCY_MANAGER, msg.sender) || hasRole(POOL_MANAGER, msg.sender),
      'NOT_EMERGENCY_OR_POOL_MANAGER'
    );
    _;
  }

  /**
   * @dev Only risk or pool manager can call functions marked by this modifier.
   */
  modifier onlyRiskOrPoolManager() {
    require(
      hasRole(RISK_MANAGER, msg.sender) || hasRole(POOL_MANAGER, msg.sender),
      'NOT_RISK_OR_POOL_MANAGER'
    );
    _;
  }

  /**
   * @dev Only risk or pool or emergency manager can call functions marked by this modifier.
   */
  modifier onlyRiskOrPoolOrEmergencyManager() {
    require(
      hasRole(RISK_MANAGER, msg.sender) ||
        hasRole(POOL_MANAGER, msg.sender) ||
        hasRole(EMERGENCY_MANAGER, msg.sender),
      'NOT_RISK_OR_POOL_OR_EMERGENCY_MANAGER'
    );
    _;
  }

  constructor() {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function setRoleAdmin(bytes32 role, bytes32 adminRole) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setRoleAdmin(role, adminRole);
  }
}
