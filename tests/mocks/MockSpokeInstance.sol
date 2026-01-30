// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Spoke} from 'src/spoke/Spoke.sol';

contract MockSpokeInstance is Spoke {
  bool public constant IS_TEST = true;

  uint64 public immutable SPOKE_REVISION;

  /**
   * @dev Constructor.
   * @dev It sets the spoke revision and disables the initializers.
   * @param spokeRevision_ The revision of the spoke contract.
   * @param oracle_ The address of the oracle.
   * @param maxUserReservesLimit_ The maximum number of reserves a user can have (both collaterals and borrows).
   */
  constructor(
    uint64 spokeRevision_,
    address oracle_,
    uint16 maxUserReservesLimit_
  ) Spoke(oracle_, maxUserReservesLimit_) {
    SPOKE_REVISION = spokeRevision_;
    _disableInitializers();
  }

  /// @inheritdoc Spoke
  function initialize(address _authority) external override reinitializer(SPOKE_REVISION) {
    emit UpdateOracle(ORACLE);
    emit UpdateMaxUserReservesLimit(MAX_USER_RESERVES_LIMIT);
    require(_authority != address(0), InvalidAddress());
    __AccessManaged_init(_authority);
    if (_liquidationConfig.targetHealthFactor == 0) {
      _liquidationConfig.targetHealthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
      emit UpdateLiquidationConfig(_liquidationConfig);
    }
  }
}
