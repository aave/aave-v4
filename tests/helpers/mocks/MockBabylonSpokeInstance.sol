// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BabylonSpoke} from 'src/spoke/BabylonSpoke.sol';

contract MockBabylonSpokeInstance is BabylonSpoke {
  bool public constant IS_TEST = true;

  uint64 public immutable SPOKE_REVISION;

  /**
   * @dev Constructor.
   * @dev It sets the spoke revision and disables the initializers.
   * @param spokeRevision_ The revision of the spoke contract.
   * @param oracle_ The address of the oracle.
   * @param liquidationManager_ The only address allowed to perform liquidations on this Spoke.
   * @param managedCollateralReserveId_ The identifier of the only reserve usable as collateral.
   */
  constructor(
    uint64 spokeRevision_,
    address oracle_,
    address liquidationManager_,
    uint256 managedCollateralReserveId_
  ) BabylonSpoke(oracle_, liquidationManager_, managedCollateralReserveId_) {
    SPOKE_REVISION = spokeRevision_;
    _disableInitializers();
  }

  /// @notice Initializer.
  /// @param authority The address of the authority contract which manages permissions.
  function initialize(address authority) external override reinitializer(SPOKE_REVISION) {
    emit SetSpokeImmutables(ORACLE, MAX_USER_RESERVES_LIMIT);
    emit SetBabylonSpokeImmutables(LIQUIDATION_MANAGER, MANAGED_COLLATERAL_RESERVE_ID);
    _validateManagedCollateralReserve(MANAGED_COLLATERAL_RESERVE_ID);

    require(authority != address(0), InvalidAddress());
    __AccessManaged_init(authority);
    if (_liquidationConfig.targetHealthFactor == 0) {
      _liquidationConfig.targetHealthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
      emit UpdateLiquidationConfig(_liquidationConfig);
    }
  }
}
