// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Spoke} from 'src/contracts/Spoke.sol';

/**
 * @title SpokeInstance
 * @author Aave Labs
 * @notice Implementation contract for the Spoke.
 */
contract SpokeInstance is Spoke {
  uint64 public constant SPOKE_REVISION = 1;

  constructor(address oracle_) Spoke(oracle_) {
    _disableInitializers();
  }

  /// @inheritdoc Spoke
  function initialize(address _authority) external override reinitializer(SPOKE_REVISION) {
    require(_authority != address(0), InvalidAddress());
    __AccessManaged_init(_authority);
    if (_liquidationConfig.targetHealthFactor == 0) {
      _liquidationConfig.targetHealthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
      emit UpdateLiquidationConfig(_liquidationConfig);
    }
  }
}
