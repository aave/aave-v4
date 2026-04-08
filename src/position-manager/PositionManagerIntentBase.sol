// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {IntentConsumer} from 'src/utils/IntentConsumer.sol';
import {IPositionManagerIntentBase} from 'src/position-manager/interfaces/IPositionManagerIntentBase.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';

/// @title PositionManagerIntentBase
/// @author Aave Labs
/// @notice Extension of PositionManagerBase powered with intents consumption functionality.
/// @dev This extension is needed for all Position Manager using EIP-712 signatures to verify and consume intents.
abstract contract PositionManagerIntentBase is
  IPositionManagerIntentBase,
  PositionManagerBase,
  IntentConsumer
{
  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address initialOwner_) PositionManagerBase(initialOwner_) {}
}
