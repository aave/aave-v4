// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';

contract AaveV4DeployProcedureBase {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));
}
