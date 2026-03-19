// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TreasurySpoke} from 'src/spoke/TreasurySpoke.sol';

contract MockTreasurySpokeInstance is TreasurySpoke {
  bool public constant IS_TEST = true;

  uint64 public immutable SPOKE_REVISION;

  /**
   * @dev Constructor.
   * @dev It sets the spoke revision and disables the initializers.
   * @param spokeRevision_ The revision of the spoke contract.
   */
  constructor(uint64 spokeRevision_) {
    SPOKE_REVISION = spokeRevision_;
    _disableInitializers();
  }

  /// @inheritdoc TreasurySpoke
  function initialize(address owner) external override reinitializer(SPOKE_REVISION) {
    __Ownable_init(owner);
    __Ownable2Step_init();
  }
}
