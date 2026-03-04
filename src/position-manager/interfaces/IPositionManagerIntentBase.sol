// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IIntentConsumer} from 'src/interfaces/IIntentConsumer.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

/// @title IPositionManagerIntentBase
/// @author Aave Labs
/// @notice Interface to extend PositionManagerBase with intent consuming capabilities.
interface IPositionManagerIntentBase is IIntentConsumer, IPositionManagerBase {}
