// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {DeployUtils} from 'tests/DeployUtils.sol';

contract DeployWrapper {
  function deploySpokeImplementation(
    address oracle,
    uint16 maxUserReservesLimit
  ) external returns (address) {
    return address(DeployUtils.deploySpokeImplementation(oracle, maxUserReservesLimit));
  }

  function deploySpokeImplementation(
    address oracle,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) external returns (address) {
    return address(DeployUtils.deploySpokeImplementation(oracle, maxUserReservesLimit, salt));
  }

  function deploySpoke(
    address oracle,
    uint16 maxUserReservesLimit,
    address proxyAdminOwner,
    bytes calldata initData
  ) external returns (address) {
    return
      address(DeployUtils.deploySpoke(oracle, maxUserReservesLimit, proxyAdminOwner, initData));
  }

  function deploySpoke(
    address oracle,
    uint16 maxUserReservesLimit,
    address proxyAdminOwner,
    bytes32 salt,
    bytes calldata initData
  ) external returns (address) {
    return
      address(
        DeployUtils.deploySpoke(oracle, maxUserReservesLimit, proxyAdminOwner, salt, initData)
      );
  }

  function deployHub(address authority) external returns (address) {
    return address(DeployUtils.deployHub(authority));
  }

  function deployHub(address authority, bytes32 salt) external returns (address) {
    return address(DeployUtils.deployHub(authority, salt));
  }
}
