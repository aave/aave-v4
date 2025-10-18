// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {GatewayBase} from 'src/position-manager/GatewayBase.sol';

contract GatewayBaseWrapper is GatewayBase {
  constructor(address initialOwner_) GatewayBase(initialOwner_) {}
}
