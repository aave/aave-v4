// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/config-engine/BaseConfigEngine.t.sol';

contract AaveV4ConfigEngineTest is BaseConfigEngineTest {
  function test_entryPoints_revertWith_OnlyDelegateCall_onDirectCall() public {
    bytes4[21] memory selectors = [
      IAaveV4ConfigEngine.executeHubAssetListings.selector,
      IAaveV4ConfigEngine.executeHubAssetConfigUpdates.selector,
      IAaveV4ConfigEngine.executeHubSpokeToAssetsAdditions.selector,
      IAaveV4ConfigEngine.executeHubSpokeConfigUpdates.selector,
      IAaveV4ConfigEngine.executeHubAssetHalts.selector,
      IAaveV4ConfigEngine.executeHubAssetDeactivations.selector,
      IAaveV4ConfigEngine.executeHubAssetCapsResets.selector,
      IAaveV4ConfigEngine.executeHubSpokeDeactivations.selector,
      IAaveV4ConfigEngine.executeHubSpokeCapsResets.selector,
      IAaveV4ConfigEngine.executeSpokeReserveListings.selector,
      IAaveV4ConfigEngine.executeSpokeReserveConfigUpdates.selector,
      IAaveV4ConfigEngine.executeSpokeLiquidationConfigUpdates.selector,
      IAaveV4ConfigEngine.executeSpokeDynamicReserveConfigAdditions.selector,
      IAaveV4ConfigEngine.executeSpokeDynamicReserveConfigUpdates.selector,
      IAaveV4ConfigEngine.executeSpokePositionManagerUpdates.selector,
      IAaveV4ConfigEngine.executePositionManagerSpokeRegistrations.selector,
      IAaveV4ConfigEngine.executePositionManagerRoleRenouncements.selector,
      IAaveV4ConfigEngine.executeRoleMemberships.selector,
      IAaveV4ConfigEngine.executeRoleUpdates.selector,
      IAaveV4ConfigEngine.executeTargetFunctionRoleUpdates.selector,
      IAaveV4ConfigEngine.executeTargetAdminDelayUpdates.selector
    ];

    for (uint256 i; i < selectors.length; ++i) {
      // every entry point takes a single dynamic array; encode an empty one
      (bool success, bytes memory returnData) = address(engineImplementation).call(
        abi.encodeWithSelector(selectors[i], uint256(0x20), uint256(0))
      );
      assertFalse(success);
      assertEq(returnData, abi.encodeWithSelector(IAaveV4ConfigEngine.OnlyDelegateCall.selector));
    }
  }

  function test_executeRoleMemberships_revertsWith_OnlyDelegateCall_whenEngineHoldsRole() public {
    vm.prank(ADMIN);
    accessManager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(engineImplementation), 0);

    IAaveV4ConfigEngine.RoleMembership memory membership = IAaveV4ConfigEngine.RoleMembership({
      authority: address(accessManager),
      roleId: Roles.ACCESS_MANAGER_ADMIN_ROLE,
      account: USER,
      granted: true,
      executionDelay: 0
    });

    vm.expectRevert(IAaveV4ConfigEngine.OnlyDelegateCall.selector);
    vm.prank(USER);
    engineImplementation.executeRoleMemberships(_toRoleMembershipArray(membership));

    (bool isMember, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, USER);
    assertFalse(isMember);
  }
}
