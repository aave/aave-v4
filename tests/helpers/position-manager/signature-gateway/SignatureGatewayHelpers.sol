// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EIP712Helpers} from 'tests/helpers/position-manager/signature-gateway/EIP712Helpers.sol';
import {SetupHelpers} from 'tests/helpers/position-manager/signature-gateway/SetupHelpers.sol';
import {Assertions} from 'tests/helpers/position-manager/signature-gateway/Assertions.sol';

/// @title SignatureGatewayHelpers
/// @notice Aggregates all SignatureGateway test helpers.
///
/// Inheritance tree:
///   SignatureGatewayHelpers
///   ├── EIP712Helpers
///   │   └── Test
///   ├── SetupHelpers
///   │   └── SpokeHelpers
///   └── Assertions
///       └── SpokeHelpers (shared)
abstract contract SignatureGatewayHelpers is EIP712Helpers, SetupHelpers, Assertions {}
