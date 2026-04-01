// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpokeHelpers} from 'tests/helpers/spoke/SpokeHelpers.sol';
import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title Assertions
/// @notice Assertion helpers for SignatureGateway tests.
abstract contract Assertions is SpokeHelpers {
  function _assertGatewayHasNoBalanceOrAllowance(
    ISpoke spoke,
    ISignatureGateway _gateway,
    address who
  ) internal {
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); ++reserveId) {
      _assertEntityHasNoBalanceOrAllowance({
        underlying: _underlying(spoke, reserveId),
        entity: address(_gateway),
        user: who
      });
    }
  }

  function _assertGatewayHasNoActivePosition(
    ISpoke spoke,
    ISignatureGateway _gateway
  ) internal view {
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); ++reserveId) {
      assertEq(spoke.getUserSuppliedShares(reserveId, address(_gateway)), 0);
      assertEq(spoke.getUserTotalDebt(reserveId, address(_gateway)), 0);
      assertFalse(_isUsingAsCollateral(spoke, reserveId, address(_gateway)));
      assertFalse(_isBorrowing(spoke, reserveId, address(_gateway)));
    }
  }
}
