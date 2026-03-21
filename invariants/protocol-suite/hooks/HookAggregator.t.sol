// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {DefaultBeforeAfterHooks} from './DefaultBeforeAfterHooks.t.sol';

// Utils
import {ErrorHandlers} from '../../shared/utils/ErrorHandlers.sol';

/// @title HookAggregator
/// @notice Helper contract to aggregate all before / after hook contracts, inherited on each handler
abstract contract HookAggregator is DefaultBeforeAfterHooks {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          SETUP                                            //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Initializer for the hooks
  function _setUpHooks() internal {
    _setUpDefaultHooks();
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          HOOKS                                            //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Before hook for the handlers
  function _before() internal {
    _defaultHooksBefore();
  }

  /// @notice After hook for the handlers
  function _after() internal {
    _defaultHooksAfter();

    // POST-CONDITIONS
    _checkPostConditions();

    // Reset the state
    _resetState();
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   POSTCONDITION CHECKS                                    //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Postconditions for the handlers
  function _checkPostConditions() internal {
    // Store the message signature to avoid losing it inside the checkPostConditions call context
    _cacheCurrentActionSignature();

    try this.checkPostConditions() {} catch (bytes memory ret) {
      ErrorHandlers.handleAssertionError(false, ret, true, GPOST_CHECK_FAILED);
    }
  }

  /// @dev postconditions checks entrypoint, should be self-called
  function checkPostConditions() external {
    // Hub postconditions
    _hubPostConditions();
    // Spoke postconditions
    _spokePostConditions();
  }

  function _hubPostConditions() internal {
    // Iterate through all users to check
    for (uint256 i; i < usersToCheck.length; i++) {
      address spoke = usersToCheck[i].spoke;
      uint256 reserveId = usersToCheck[i].reserveId;

      // CHECK_ALL_RESERVES actions should check all reserves for that spoke
      if (reserveId == CHECK_ALL_RESERVES) {
        uint256 reserveCount = ISpoke(spoke).getReserveCount();
        for (uint256 j; j < reserveCount; j++) {
          uint256 assetId = _getAssetId(spoke, j);
          address hub = _getHubAddress(spoke, j);

          assert_GPOST_HUB_A(hub, assetId);
          assert_GPOST_HUB_B(hub, assetId);
          assert_GPOST_HUB_C(hub, assetId);
          assert_GPOST_HUB_D(hub, assetId);
          assert_GPOST_HUB_EF(hub, assetId, spoke);
          assert_GPOST_HUB_G(hub, assetId);
        }
      } else {
        uint256 assetId = _getAssetId(spoke, reserveId);
        address hub = _getHubAddress(spoke, reserveId);

        assert_GPOST_HUB_A(hub, assetId);
        assert_GPOST_HUB_B(hub, assetId);
        assert_GPOST_HUB_C(hub, assetId);
        assert_GPOST_HUB_D(hub, assetId);
        assert_GPOST_HUB_EF(hub, assetId, spoke);
        assert_GPOST_HUB_G(hub, assetId);
      }
    }
  }

  function _spokePostConditions() internal {
    // Iterate through all users to check
    for (uint256 i; i < usersToCheck.length; i++) {
      address spoke = usersToCheck[i].spoke;
      uint256 reserveId = usersToCheck[i].reserveId;
      address user = usersToCheck[i].user;

      // Check properties for the spoke
      assert_GPOST_LIQ_G(spoke, user);
      assert_GPOST_SP_LIQ_H(spoke, user);

      // Check properties for all reserves of the spoke, used after actions: updateUserRiskPremium, updateUserDynamicConfig
      if (reserveId == CHECK_ALL_RESERVES) {
        uint256 reserveCount = ISpoke(spoke).getReserveCount();
        for (uint256 j; j < reserveCount; j++) {
          assert_GPOST_SP_A(spoke, j, user);
          assert_GPOST_SP_B(spoke, j, user);
          assert_GPOST_SP_E(spoke, j, user);
        }
      } else {
        // Check properties for a specific reserve of the spoke, used after actions: supply, withdraw, borrow, repay, setUsingAsCollateral
        assert_GPOST_SP_A(spoke, reserveId, user);
        assert_GPOST_SP_B(spoke, reserveId, user);
        assert_GPOST_SP_E(spoke, reserveId, user);
      }
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          HELPERS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Resets the state of the handlers
  function _resetState() internal {
    delete usersToCheck;
    delete currentActionSignature;
  }
}
