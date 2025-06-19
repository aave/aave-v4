// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

library Roles {
  uint64 public constant DEFAULT_ADMIN_ROLE = 0;
  uint64 public constant HUB_ADMIN_ROLE = 1;
  uint64 public constant SPOKE_ADMIN_ROLE = 2;
  uint64 public constant TREASURY_ADMIN_ROLE = 3;
  uint64 public constant SPOKE_ROLE = 4;
  uint64 public constant GOVERNOR_ROLE = 5;

  // TODO: Remove the following
  uint64 public constant RESTRICTED_ROLE = 100;
  uint64 public constant RESTRICTED_ROLE_ADMIN = 101;
}
