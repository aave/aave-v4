// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

library Roles {
  uint64 public constant DEFAULT_ADMIN_ROLE = 0;
  uint64 public constant HUB_ADMIN_ROLE = 1;
  uint64 public constant SPOKE_ADMIN_ROLE = 2;
  uint64 public constant USER_RP_UPDATER_ROLE = 3;
}
