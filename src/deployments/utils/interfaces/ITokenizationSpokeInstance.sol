// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

interface ITokenizationSpokeInstance is ITokenizationSpoke {
  function initialize(string memory shareName, string memory shareSymbol) external;

  function SPOKE_REVISION() external view returns (uint64);
}
