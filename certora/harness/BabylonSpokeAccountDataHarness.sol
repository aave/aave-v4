// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BabylonSpokeHarness} from './BabylonSpokeHarness.sol';

/// @notice Exposes the real account-data computation as its own external function.
/// @dev Spoke._calculateUserAccountData(user) is, by definition, _processUserAccountData(user, false).
/// helpers/PointerAnalysisSummaries.spec routes _calculateUserAccountData here, so the same code runs
/// outside the struct literal in BabylonSpoke.liquidationCall that the Prover's pointer analysis
/// cannot handle.
contract BabylonSpokeAccountDataHarness is BabylonSpokeHarness {
  constructor(
    address oracle_,
    address liquidationManager_,
    uint256 managedCollateralReserveId_
  ) BabylonSpokeHarness(oracle_, liquidationManager_, managedCollateralReserveId_) {}

  function harnessAccountData(address user) external returns (UserAccountData memory) {
    return _processUserAccountData(user, false);
  }
}
