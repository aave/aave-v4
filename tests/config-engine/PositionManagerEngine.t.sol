// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/config-engine/BaseConfigEngine.t.sol';

contract PositionManagerEngineTest is BaseConfigEngineTest {
  function setUp() public override {
    super.setUp();
    _seedFullEnvironment();
  }

  function test_executePositionManagerSpokeRegistrations() public {
    vm.expectCall(
      address(positionManager),
      abi.encodeCall(IPositionManagerBase.registerSpoke, (address(spoke1()), true))
    );

    vm.expectEmit(address(positionManager));
    emit IPositionManagerBase.SpokeRegistered(address(spoke1()), true);

    engine.executePositionManagerSpokeRegistrations(
      _toSpokeRegistrationArray(
        IAaveV4ConfigEngine.SpokeRegistration({
          positionManager: address(positionManager),
          spoke: address(spoke1()),
          registered: true
        })
      )
    );

    assertTrue(positionManager.isSpokeRegistered(address(spoke1())));
  }

  function test_executePositionManagerSpokeRegistrations_deregister() public {
    engine.executePositionManagerSpokeRegistrations(
      _toSpokeRegistrationArray(
        IAaveV4ConfigEngine.SpokeRegistration({
          positionManager: address(positionManager),
          spoke: address(spoke1()),
          registered: true
        })
      )
    );
    assertTrue(positionManager.isSpokeRegistered(address(spoke1())));

    vm.expectEmit(address(positionManager));
    emit IPositionManagerBase.SpokeRegistered(address(spoke1()), false);

    engine.executePositionManagerSpokeRegistrations(
      _toSpokeRegistrationArray(
        IAaveV4ConfigEngine.SpokeRegistration({
          positionManager: address(positionManager),
          spoke: address(spoke1()),
          registered: false
        })
      )
    );
    assertFalse(positionManager.isSpokeRegistered(address(spoke1())));
  }

  function test_fuzz_executePositionManagerSpokeRegistrations(bool registered) public {
    engine.executePositionManagerSpokeRegistrations(
      _toSpokeRegistrationArray(
        IAaveV4ConfigEngine.SpokeRegistration({
          positionManager: address(positionManager),
          spoke: address(spoke1()),
          registered: registered
        })
      )
    );

    assertEq(positionManager.isSpokeRegistered(address(spoke1())), registered);
  }

  function test_executePositionManagerSpokeRegistrations_revert() public {
    PositionManagerBaseWrapper otherPm = new PositionManagerBaseWrapper(address(0xdead));

    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(engine))
    );
    engine.executePositionManagerSpokeRegistrations(
      _toSpokeRegistrationArray(
        IAaveV4ConfigEngine.SpokeRegistration({
          positionManager: address(otherPm),
          spoke: address(spoke1()),
          registered: true
        })
      )
    );
  }

  function test_executePositionManagerRoleRenouncements() public {
    engine.executePositionManagerSpokeRegistrations(
      _toSpokeRegistrationArray(
        IAaveV4ConfigEngine.SpokeRegistration({
          positionManager: address(positionManager),
          spoke: address(spoke1()),
          registered: true
        })
      )
    );

    engine.executeSpokePositionManagerUpdates(
      _toPositionManagerUpdateArray(
        IAaveV4ConfigEngine.PositionManagerUpdate({
          spokeConfigurator: spokeConfigurator,
          spoke: address(spoke1()),
          positionManager: address(positionManager),
          active: true
        })
      )
    );

    vm.prank(USER);
    spoke1().setUserPositionManager(address(positionManager), true);

    vm.expectCall(
      address(positionManager),
      abi.encodeCall(IPositionManagerBase.renouncePositionManagerRole, (address(spoke1()), USER))
    );

    vm.expectEmit(address(spoke1()));
    emit ISpoke.SetUserPositionManager(USER, address(positionManager), false);

    engine.executePositionManagerRoleRenouncements(
      _toPositionManagerRoleRenouncementArray(
        IAaveV4ConfigEngine.PositionManagerRoleRenouncement({
          positionManager: address(positionManager),
          spoke: address(spoke1()),
          user: USER
        })
      )
    );

    assertFalse(spoke1().isPositionManager(USER, address(positionManager)));
  }

  function test_executePositionManagerRoleRenouncements_revert() public {
    PositionManagerBaseWrapper otherPm = new PositionManagerBaseWrapper(address(0xdead));

    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(engine))
    );
    engine.executePositionManagerRoleRenouncements(
      _toPositionManagerRoleRenouncementArray(
        IAaveV4ConfigEngine.PositionManagerRoleRenouncement({
          positionManager: address(otherPm),
          spoke: address(spoke1()),
          user: USER
        })
      )
    );
  }
}
