// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployUtils} from 'tests/helpers/deploy/DeployUtils.sol';

contract DeployWrapper {
  function deploySpokeImplementation(
    address oracle,
    uint16 maxUserReservesLimit
  ) external returns (address) {
    return address(DeployUtils.deploySpokeImplementation(oracle, maxUserReservesLimit, ''));
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

  function deployHub(address authority, address proxyAdminOwner) external returns (address) {
    return address(DeployUtils.deployHub({authority: authority, proxyAdminOwner: proxyAdminOwner}));
  }
}
