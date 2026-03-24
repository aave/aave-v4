// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';

interface IHubInstance is IHub {
  function initialize(address authority) external;

  function HUB_REVISION() external view returns (uint64);
}
