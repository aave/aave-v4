// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

import {PositionManagerBaseWrapper} from 'tests/mocks/PositionManagerBaseWrapper.sol';

contract PositionManagerEngineTest is BaseConfigEngineTest {
  function setUp() public override {
    super.setUp();
    _seedFullEnvironment();
  }

  function test_executePositionManagerSpokeRegistrations_concrete() public {
    engine.executePositionManagerSpokeRegistrations(
      _toSpokeRegistrationArray(
        IAaveV4ConfigEngine.SpokeRegistration({
          positionManager: address(positionManager),
          spoke: address(spokes[0]),
          registered: true
        })
      )
    );

    assertTrue(positionManager.isSpokeRegistered(address(spokes[0])));
  }

  function test_executePositionManagerSpokeRegistrations_deregister() public {
    engine.executePositionManagerSpokeRegistrations(
      _toSpokeRegistrationArray(
        IAaveV4ConfigEngine.SpokeRegistration({
          positionManager: address(positionManager),
          spoke: address(spokes[0]),
          registered: true
        })
      )
    );
    assertTrue(positionManager.isSpokeRegistered(address(spokes[0])));

    engine.executePositionManagerSpokeRegistrations(
      _toSpokeRegistrationArray(
        IAaveV4ConfigEngine.SpokeRegistration({
          positionManager: address(positionManager),
          spoke: address(spokes[0]),
          registered: false
        })
      )
    );
    assertFalse(positionManager.isSpokeRegistered(address(spokes[0])));
  }

  function test_executePositionManagerSpokeRegistrations_fuzz(bool registered) public {
    engine.executePositionManagerSpokeRegistrations(
      _toSpokeRegistrationArray(
        IAaveV4ConfigEngine.SpokeRegistration({
          positionManager: address(positionManager),
          spoke: address(spokes[0]),
          registered: registered
        })
      )
    );

    assertEq(positionManager.isSpokeRegistered(address(spokes[0])), registered);
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
          spoke: address(spokes[0]),
          registered: true
        })
      )
    );
  }

  function test_executePositionManagerRoleRenouncements_concrete() public {
    engine.executePositionManagerSpokeRegistrations(
      _toSpokeRegistrationArray(
        IAaveV4ConfigEngine.SpokeRegistration({
          positionManager: address(positionManager),
          spoke: address(spokes[0]),
          registered: true
        })
      )
    );

    engine.executeSpokePositionManagerUpdates(
      _toPositionManagerUpdateArray(
        IAaveV4ConfigEngine.PositionManagerUpdate({
          spokeConfigurator: spokeConfigurator,
          spoke: address(spokes[0]),
          positionManager: address(positionManager),
          active: true
        })
      )
    );

    vm.prank(USER);
    spokes[0].setUserPositionManager(address(positionManager), true);

    engine.executePositionManagerRoleRenouncements(
      _toPositionManagerRoleRenouncementArray(
        IAaveV4ConfigEngine.PositionManagerRoleRenouncement({
          positionManager: address(positionManager),
          spoke: address(spokes[0]),
          user: USER
        })
      )
    );

    assertFalse(spokes[0].isPositionManager(USER, address(positionManager)));
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
          spoke: address(spokes[0]),
          user: USER
        })
      )
    );
  }
}
