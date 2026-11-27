// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/spoke/configurator/SpokeConfigurator.t.sol';

contract EmergencyStewardTest is SpokeConfiguratorBaseTest {
  function test_constructor() public view {
    assertEq(emergencySteward.SPOKE_CONFIGURATOR(), address(spokeConfigurator));
    assertEq(IAccessManaged(address(emergencySteward)).authority(), address(accessManager));
  }

  function test_constructor_revertsWith_InvalidAddress_authority() public {
    vm.expectRevert(IEmergencySteward.InvalidAddress.selector);
    new EmergencySteward(address(0), address(spokeConfigurator));
  }

  function test_constructor_revertsWith_InvalidAddress_spokeConfigurator() public {
    vm.expectRevert(IEmergencySteward.InvalidAddress.selector);
    new EmergencySteward(address(accessManager), address(0));
  }

  function test_bulkLevers_revertsWith_AccessManagedUnauthorized_withoutSpokeConfiguratorRole()
    public
  {
    _revokeSpokeConfiguratorEmergencyStewardRole();
    bytes memory expectedRevert = abi.encodeWithSelector(
      IAccessManaged.AccessManagedUnauthorized.selector,
      address(emergencySteward)
    );

    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    vm.expectRevert(expectedRevert);
    emergencySteward.pauseAllReserves(spokeAddr);
    vm.expectRevert(expectedRevert);
    emergencySteward.unpauseAllReserves(spokeAddr);
    vm.expectRevert(expectedRevert);
    emergencySteward.freezeSpoke(spokeAddr);
    vm.expectRevert(expectedRevert);
    emergencySteward.unfreezeSpoke(spokeAddr);
    vm.expectRevert(expectedRevert);
    emergencySteward.freezeAsset(hubAddr, underlying);
    vm.expectRevert(expectedRevert);
    emergencySteward.unfreezeAsset(hubAddr, underlying);
    vm.expectRevert(expectedRevert);
    emergencySteward.disableAssetBorrowing(hubAddr, underlying);
    vm.stopPrank();
  }

  function test_deactivatePositionManager_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    emergencySteward.deactivatePositionManager(_allSpokeAddresses(), makeAddr('POSITION_MANAGER'));
  }

  function test_deactivatePositionManager() public {
    address positionManager = makeAddr('POSITION_MANAGER');
    address[] memory spokes = _allSpokeAddresses();
    for (uint256 i; i < spokes.length; ++i) {
      _activatePositionManager(spokes[i], positionManager);
    }

    vm.recordLogs();
    for (uint256 i; i < spokes.length; ++i) {
      vm.expectCall(
        address(spokeConfigurator),
        abi.encodeCall(
          ISpokeConfigurator.updatePositionManager,
          (spokes[i], positionManager, false)
        )
      );
      vm.expectEmit(spokes[i]);
      emit ISpoke.UpdatePositionManager(positionManager, false);
      vm.expectEmit(address(spokeConfigurator));
      emit ISpokeConfigurator.PositionManagerUpdated(spokes[i], positionManager, true, false);
    }
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.deactivatePositionManager(spokes, positionManager);

    assertEq(_configuratorLogCount(), spokes.length);
    for (uint256 i; i < spokes.length; ++i) {
      assertFalse(ISpoke(spokes[i]).isPositionManagerActive(positionManager));
    }
  }

  function test_fuzz_deactivatePositionManager_skipsSpokesWherePositionManagerIsInactive(
    bool[3] memory active
  ) public {
    address positionManager = makeAddr('POSITION_MANAGER');
    address[] memory spokes = _allSpokeAddresses();
    uint256 activeCount;
    for (uint256 i; i < spokes.length; ++i) {
      if (active[i]) {
        _activatePositionManager(spokes[i], positionManager);
        ++activeCount;
      }
    }

    vm.recordLogs();
    for (uint256 i; i < spokes.length; ++i) {
      if (active[i]) {
        vm.expectEmit(address(spokeConfigurator));
        emit ISpokeConfigurator.PositionManagerUpdated(spokes[i], positionManager, true, false);
      } else {
        vm.expectCall(
          address(spokeConfigurator),
          abi.encodeCall(
            ISpokeConfigurator.updatePositionManager,
            (spokes[i], positionManager, false)
          ),
          0
        );
      }
    }
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.deactivatePositionManager(spokes, positionManager);

    assertEq(_configuratorLogCount(), activeCount);
    for (uint256 i; i < spokes.length; ++i) {
      assertFalse(ISpoke(spokes[i]).isPositionManagerActive(positionManager));
    }
  }

  function test_deactivatePositionManager_duplicateSpoke() public {
    address positionManager = makeAddr('POSITION_MANAGER');
    _activatePositionManager(spokeAddr, positionManager);
    address[] memory spokes = new address[](2);
    spokes[0] = spokeAddr;
    spokes[1] = spokeAddr;

    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.deactivatePositionManager(spokes, positionManager);

    assertEq(_configuratorLogCount(), 1);
    assertFalse(spoke.isPositionManagerActive(positionManager));
  }

  function test_deactivatePositionManager_keepsOtherPositionManagersActive() public {
    address positionManager = makeAddr('POSITION_MANAGER');
    address otherPositionManager = makeAddr('OTHER_POSITION_MANAGER');
    address[] memory spokes = _allSpokeAddresses();
    for (uint256 i; i < spokes.length; ++i) {
      _activatePositionManager(spokes[i], positionManager);
      _activatePositionManager(spokes[i], otherPositionManager);
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.deactivatePositionManager(spokes, positionManager);

    for (uint256 i; i < spokes.length; ++i) {
      assertFalse(ISpoke(spokes[i]).isPositionManagerActive(positionManager));
      assertTrue(ISpoke(spokes[i]).isPositionManagerActive(otherPositionManager));
    }
  }

  function test_deactivatePositionManager_blocksApprovedPositionManager_keepsUserApproval() public {
    address positionManager = makeAddr('POSITION_MANAGER');
    _activatePositionManager(spokeAddr, positionManager);
    vm.prank(alice);
    spoke.setUserPositionManager(positionManager, true);
    assertTrue(spoke.isPositionManager(alice, positionManager));

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.deactivatePositionManager(_singleSpokeAddress(spokeAddr), positionManager);

    assertFalse(spoke.isPositionManager(alice, positionManager));
    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(positionManager);
    spoke.setUsingAsCollateral(reserveId, true, alice);

    // re-activating restores access without a new user approval
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updatePositionManager(spokeAddr, positionManager, true);
    assertTrue(spoke.isPositionManager(alice, positionManager));
  }

  function test_deactivatePositionManager_revertsWith_AccessManagedUnauthorized_onSpoke() public {
    address positionManager = makeAddr('POSITION_MANAGER');
    IAccessManager spokeAuthority = IAccessManager(spoke.authority());
    vm.prank(ADMIN);
    spokeAuthority.revokeRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(spokeConfigurator));

    // a Spoke where the position manager is already inactive is skipped without calling it
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.deactivatePositionManager(_singleSpokeAddress(spokeAddr), positionManager);

    _activatePositionManager(spokeAddr, positionManager);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManaged.AccessManagedUnauthorized.selector,
        address(spokeConfigurator)
      )
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.deactivatePositionManager(_singleSpokeAddress(spokeAddr), positionManager);
  }

  function test_deactivatePositionManager_revertsWith_AccessManagedUnauthorized_withoutSpokeConfiguratorRole()
    public
  {
    address positionManager = makeAddr('POSITION_MANAGER');
    _activatePositionManager(spokeAddr, positionManager);
    _revokeSpokeConfiguratorEmergencyStewardRole();

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManaged.AccessManagedUnauthorized.selector,
        address(emergencySteward)
      )
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.deactivatePositionManager(_singleSpokeAddress(spokeAddr), positionManager);
  }

  function _activatePositionManager(address targetSpoke, address positionManager) internal {
    vm.prank(SPOKE_ADMIN);
    ISpoke(targetSpoke).updatePositionManager(positionManager, true);
  }

  function _allSpokeAddresses() internal view returns (address[] memory spokes) {
    spokes = new address[](3);
    spokes[0] = address(spoke1);
    spokes[1] = address(spoke2);
    spokes[2] = address(spoke3);
  }

  function _singleSpokeAddress(
    address targetSpoke
  ) internal pure returns (address[] memory spokes) {
    spokes = new address[](1);
    spokes[0] = targetSpoke;
  }

  function _revokeSpokeConfiguratorEmergencyStewardRole() internal {
    IAccessManager authority = IAccessManager(spoke.authority());
    vm.prank(ADMIN);
    authority.revokeRole(
      Roles.SPOKE_CONFIGURATOR_EMERGENCY_STEWARD_ROLE,
      address(emergencySteward)
    );
  }

  function test_pauseAllReserves_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    emergencySteward.pauseAllReserves(spokeAddr);
  }

  function test_pauseAllReserves() public {
    uint256 reserveCount = spoke.getReserveCount();
    vm.recordLogs();
    for (uint256 reserveIdx = 0; reserveIdx < reserveCount; ++reserveIdx) {
      ISpoke.Reserve memory reserve = spoke.getReserve(reserveIdx);
      ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(reserveIdx);
      bool oldPaused = reserveConfig.paused;
      reserveConfig.paused = true;
      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveIdx, reserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(reserveIdx, reserveConfig);
      vm.expectEmit(address(spokeConfigurator));
      emit ISpokeConfigurator.ReservePausedUpdated(
        spokeAddr,
        address(reserve.hub),
        reserve.underlying,
        reserveIdx,
        oldPaused,
        true
      );
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.pauseAllReserves(spokeAddr);

    assertEq(_configuratorLogCount(), reserveCount);
    for (uint256 reserveIdx; reserveIdx < reserveCount; ++reserveIdx) {
      assertEq(spoke.getReserveConfig(reserveIdx).paused, true);
      _assertPausedByBulkLevers(reserveIdx, true);
    }
  }

  function test_pauseAllReserves_skipsReservesAlreadyPaused() public {
    uint256 daiId = _daiReserveId(spoke);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.pauseReserve(spokeAddr, hubAddr, address(tokenList.dai));

    ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(daiId);
    vm.expectCall(spokeAddr, abi.encodeCall(ISpoke.updateReserveConfig, (daiId, reserveConfig)), 0);
    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.pauseAllReserves(spokeAddr);

    assertEq(_configuratorLogCount(), spoke.getReserveCount() - 1);
    for (uint256 id; id < spoke.getReserveCount(); ++id) {
      assertTrue(spoke.getReserveConfig(id).paused);
      _assertPausedByBulkLevers(id, id != daiId);
    }
  }

  function test_unpauseAllReserves_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    emergencySteward.unpauseAllReserves(spokeAddr);
  }

  function test_unpauseAllReserves() public {
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.pauseAllReserves(spokeAddr);

    uint256 reserveCount = spoke.getReserveCount();
    vm.recordLogs();
    for (uint256 id; id < reserveCount; ++id) {
      ISpoke.Reserve memory reserve = spoke.getReserve(id);
      ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(id);
      reserveConfig.paused = false;
      vm.expectCall(spokeAddr, abi.encodeCall(ISpoke.updateReserveConfig, (id, reserveConfig)));
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(id, reserveConfig);
      vm.expectEmit(address(spokeConfigurator));
      emit ISpokeConfigurator.ReservePausedUpdated(
        spokeAddr,
        address(reserve.hub),
        reserve.underlying,
        id,
        true,
        false
      );
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unpauseAllReserves(spokeAddr);

    assertEq(_configuratorLogCount(), reserveCount);
    _assertOnlyReservePaused(type(uint256).max);
    for (uint256 id; id < reserveCount; ++id) {
      _assertPausedByBulkLevers(id, false);
    }

    // a second call is a no-op on every reserve and does not revert
    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unpauseAllReserves(spokeAddr);
    assertEq(_configuratorLogCount(), 0);
  }

  function test_unpauseAllReserves_afterRepeatedPauseAllReserves() public {
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.pauseAllReserves(spokeAddr);
    emergencySteward.pauseAllReserves(spokeAddr);
    emergencySteward.unpauseAllReserves(spokeAddr);
    vm.stopPrank();

    _assertOnlyReservePaused(type(uint256).max);
  }

  function test_unpauseAllReserves_keepsReservesPausedBeforePauseAllReserves() public {
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.pauseReserve(spokeAddr, hubAddr, address(tokenList.dai));
    emergencySteward.pauseAllReserves(spokeAddr);
    emergencySteward.unpauseAllReserves(spokeAddr);
    vm.stopPrank();

    _assertOnlyReservePaused(_daiReserveId(spoke));
  }

  function test_unpauseAllReserves_keepsReservesPausedThroughPauseReserve() public {
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.pauseAllReserves(spokeAddr);
    spokeConfigurator.pauseReserve(spokeAddr, hubAddr, address(tokenList.dai));
    _assertPausedByBulkLevers(_daiReserveId(spoke), false);
    emergencySteward.unpauseAllReserves(spokeAddr);
    vm.stopPrank();

    _assertOnlyReservePaused(_daiReserveId(spoke));
  }

  function test_unpauseAllReserves_keepsReservesPausedThroughUpdatePaused() public {
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.pauseAllReserves(spokeAddr);
    spokeConfigurator.updatePaused(spokeAddr, hubAddr, address(tokenList.dai), true);
    _assertPausedByBulkLevers(_daiReserveId(spoke), false);
    emergencySteward.unpauseAllReserves(spokeAddr);
    vm.stopPrank();

    _assertOnlyReservePaused(_daiReserveId(spoke));
  }

  function test_unpauseAllReserves_skipsReservesUnpausedOnSpoke() public {
    uint256 daiId = _daiReserveId(spoke);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.pauseAllReserves(spokeAddr);
    ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(daiId);
    reserveConfig.paused = false;
    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(daiId, reserveConfig);

    vm.expectCall(spokeAddr, abi.encodeCall(ISpoke.updateReserveConfig, (daiId, reserveConfig)), 0);
    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unpauseAllReserves(spokeAddr);

    assertEq(_configuratorLogCount(), spoke.getReserveCount() - 1);
    _assertOnlyReservePaused(type(uint256).max);
  }

  function test_getPausedByBulkLevers() public {
    uint256 daiId = _daiReserveId(spoke);
    _assertPausedByBulkLevers(daiId, false);

    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.pauseAllReserves(spokeAddr);
    _assertPausedByBulkLevers(daiId, true);

    emergencySteward.unpauseAllReserves(spokeAddr);
    _assertPausedByBulkLevers(daiId, false);
    vm.stopPrank();
  }

  function test_freezeSpoke_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    emergencySteward.freezeSpoke(spokeAddr);
  }

  function test_freezeSpoke() public {
    uint256 reserveCount = spoke.getReserveCount();
    ISpoke.DynamicReserveConfig[] memory oldConfigs = new ISpoke.DynamicReserveConfig[](
      reserveCount
    );
    uint32[] memory oldKeys = new uint32[](reserveCount);

    vm.recordLogs();
    for (uint256 id; id < reserveCount; ++id) {
      ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(id);
      reserveConfig.frozen = true;
      oldKeys[id] = _latestKey(spoke, id);
      oldConfigs[id] = _getLatestDynamicReserveConfig(spoke, id);
      ISpoke.DynamicReserveConfig memory newConfig = _getLatestDynamicReserveConfig(spoke, id);
      newConfig.collateralFactor = 0;

      vm.expectCall(spokeAddr, abi.encodeCall(ISpoke.updateReserveConfig, (id, reserveConfig)));
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(id, reserveConfig);
      _expectReserveFrozenUpdated(spoke, id, false, true);
      _expectDynamicConfigUpdated(
        spoke,
        id,
        oldKeys[id],
        oldKeys[id] + 1,
        oldConfigs[id],
        newConfig
      );
      _expectSavedDynamicConfigKeyUpdated(spoke, id, 0, oldKeys[id]);
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeSpoke(spokeAddr);

    assertEq(_configuratorLogCount(), reserveCount * 5);
    for (uint256 id; id < reserveCount; ++id) {
      assertEq(spoke.getReserveConfig(id).frozen, true);
      assertEq(_latestKey(spoke, id), oldKeys[id] + 1);
      ISpoke.DynamicReserveConfig memory expectedConfig = oldConfigs[id];
      expectedConfig.collateralFactor = 0;
      assertEq(_getLatestDynamicReserveConfig(spoke, id), expectedConfig);
      assertEq(_savedKey(spoke, id), oldKeys[id]);
      _assertFrozenByBulkLevers(spoke, id, false, true);
    }
  }

  function test_freezeSpoke_mixedReserveStates() public {
    uint256 wethId = _wethReserveId(spoke);
    uint256 wbtcId = _wbtcReserveId(spoke);
    uint256 daiId = _daiReserveId(spoke);
    uint256 usdxId = _usdxReserveId(spoke);
    uint256 usdyId = _usdyReserveId(spoke);

    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    // wbtc: frozen with a non-zero collateral factor
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, address(tokenList.wbtc));
    uint32 wbtcLiftedKey = spokeConfigurator.addCollateralFactor(
      spokeAddr,
      hubAddr,
      address(tokenList.wbtc),
      60_00
    );
    // dai: not frozen with a zero collateral factor
    spokeConfigurator.zeroCollateralFactor(spokeAddr, hubAddr, address(tokenList.dai));
    // usdx: frozen with a zero collateral factor
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, address(tokenList.usdx));
    // weth, usdy: active collateral reserves
    vm.stopPrank();

    uint256 reserveCount = spoke.getReserveCount();
    ISpoke.DynamicReserveConfig[] memory before = new ISpoke.DynamicReserveConfig[](reserveCount);
    uint32[] memory beforeKeys = new uint32[](reserveCount);
    uint32[] memory beforeSaved = new uint32[](reserveCount);
    for (uint256 id; id < reserveCount; ++id) {
      before[id] = _getLatestDynamicReserveConfig(spoke, id);
      beforeKeys[id] = _latestKey(spoke, id);
      beforeSaved[id] = _savedKey(spoke, id);
    }

    vm.recordLogs();
    uint256 expectedLogs;
    for (uint256 id; id < reserveCount; ++id) {
      ISpoke.DynamicReserveConfig memory zeroed = _getLatestDynamicReserveConfig(spoke, id);
      zeroed.collateralFactor = 0;
      if (id == wethId || id == usdyId) {
        _expectReserveFrozenUpdated(spoke, id, false, true);
        _expectDynamicConfigUpdated(
          spoke,
          id,
          beforeKeys[id],
          beforeKeys[id] + 1,
          before[id],
          zeroed
        );
        _expectSavedDynamicConfigKeyUpdated(spoke, id, beforeSaved[id], beforeKeys[id]);
        expectedLogs += 5;
      } else if (id == wbtcId) {
        _expectDynamicConfigUpdated(
          spoke,
          id,
          wbtcLiftedKey,
          wbtcLiftedKey + 1,
          before[id],
          zeroed
        );
        _expectSavedDynamicConfigKeyUpdated(spoke, id, beforeSaved[id], wbtcLiftedKey);
        expectedLogs += 4;
      } else if (id == daiId) {
        _expectReserveFrozenUpdated(spoke, id, false, true);
        expectedLogs += 1;
      }
    }
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeSpoke(spokeAddr);

    assertEq(expectedLogs, 15);
    assertEq(_configuratorLogCount(), expectedLogs);

    for (uint256 id; id < reserveCount; ++id) {
      assertTrue(spoke.getReserveConfig(id).frozen);
      assertEq(_getLatestDynamicReserveConfig(spoke, id).collateralFactor, 0);
    }
    // weth, usdy: frozen and zeroed, saved key is the pre-freeze key
    assertEq(_latestKey(spoke, wethId), beforeKeys[wethId] + 1);
    assertEq(_savedKey(spoke, wethId), beforeKeys[wethId]);
    assertEq(_latestKey(spoke, usdyId), beforeKeys[usdyId] + 1);
    assertEq(_savedKey(spoke, usdyId), beforeKeys[usdyId]);
    // wbtc: zeroed only, saved key is the lifted key
    assertEq(_latestKey(spoke, wbtcId), wbtcLiftedKey + 1);
    assertEq(_savedKey(spoke, wbtcId), wbtcLiftedKey);
    ISpoke.DynamicReserveConfig memory wbtcZeroed = before[wbtcId];
    wbtcZeroed.collateralFactor = 0;
    assertEq(_getLatestDynamicReserveConfig(spoke, wbtcId), wbtcZeroed);
    // dai: flag only
    assertEq(_latestKey(spoke, daiId), beforeKeys[daiId]);
    assertEq(_savedKey(spoke, daiId), beforeSaved[daiId]);
    // usdx: untouched
    assertEq(_latestKey(spoke, usdxId), beforeKeys[usdxId]);
    assertEq(_savedKey(spoke, usdxId), beforeSaved[usdxId]);

    // a second call is a no-op on every reserve and does not revert
    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeSpoke(spokeAddr);
    assertEq(_configuratorLogCount(), 0);
  }

  function test_unfreezeSpoke_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    emergencySteward.unfreezeSpoke(spokeAddr);
  }

  function test_unfreezeSpoke() public {
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeSpoke(spokeAddr);

    uint256 reserveCount = spoke.getReserveCount();
    vm.recordLogs();
    for (uint256 id; id < reserveCount; ++id) {
      ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(id);
      reserveConfig.frozen = false;
      vm.expectCall(spokeAddr, abi.encodeCall(ISpoke.updateReserveConfig, (id, reserveConfig)));
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(id, reserveConfig);
      _expectReserveFrozenUpdated(spoke, id, true, false);
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unfreezeSpoke(spokeAddr);

    assertEq(_configuratorLogCount(), reserveCount);
    for (uint256 id; id < reserveCount; ++id) {
      assertEq(spoke.getReserveConfig(id).frozen, false);
      assertEq(_getLatestDynamicReserveConfig(spoke, id).collateralFactor, 0);
      _assertFrozenByBulkLevers(spoke, id, false, false);
    }
  }

  function test_unfreezeSpoke_afterRepeatedFreezeSpoke() public {
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeSpoke(spokeAddr);
    emergencySteward.freezeSpoke(spokeAddr);
    emergencySteward.unfreezeSpoke(spokeAddr);
    vm.stopPrank();

    _assertOnlyReserveFrozen(type(uint256).max);
  }

  function test_unfreezeSpoke_keepsReservesFrozenBeforeFreezeSpoke() public {
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, address(tokenList.dai));
    emergencySteward.freezeSpoke(spokeAddr);
    emergencySteward.unfreezeSpoke(spokeAddr);
    vm.stopPrank();

    _assertOnlyReserveFrozen(_daiReserveId(spoke));
  }

  /// @dev `freezeReserve` reverts on a reserve already frozen with a zero collateral factor, so the reserve is
  /// unfrozen first.
  function test_unfreezeSpoke_keepsReservesFrozenThroughFreezeReserve() public {
    address dai = address(tokenList.dai);
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeSpoke(spokeAddr);
    spokeConfigurator.unfreezeReserve(spokeAddr, hubAddr, dai);
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, dai);
    _assertFrozenByBulkLevers(spoke, _daiReserveId(spoke), false, false);
    emergencySteward.unfreezeSpoke(spokeAddr);
    vm.stopPrank();

    _assertOnlyReserveFrozen(_daiReserveId(spoke));
  }

  function test_unfreezeSpoke_keepsReservesFrozenThroughUpdateFrozen() public {
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeSpoke(spokeAddr);
    spokeConfigurator.updateFrozen(spokeAddr, hubAddr, address(tokenList.dai), true);
    _assertFrozenByBulkLevers(spoke, _daiReserveId(spoke), false, false);
    emergencySteward.unfreezeSpoke(spokeAddr);
    vm.stopPrank();

    _assertOnlyReserveFrozen(_daiReserveId(spoke));
  }

  function test_unfreezeSpoke_keepsReservesFrozenThroughFreezeAsset() public {
    address dai = address(tokenList.dai);
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeSpoke(spokeAddr);
    emergencySteward.freezeAsset(hubAddr, dai);
    _assertFrozenByBulkLevers(spoke, _daiReserveId(spoke), true, true);
    emergencySteward.unfreezeSpoke(spokeAddr);
    vm.stopPrank();

    _assertOnlyReserveFrozen(_daiReserveId(spoke));
    _assertFrozenByBulkLevers(spoke, _daiReserveId(spoke), true, false);

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unfreezeAsset(hubAddr, dai);

    for (uint256 i; i < daiSpokes.length; ++i) {
      assertFalse(_isDaiFrozen(daiSpokes[i]));
    }
  }

  function test_unfreezeSpoke_skipsReservesNotFrozenByFreezeSpoke() public {
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, address(tokenList.dai));

    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unfreezeSpoke(spokeAddr);

    assertEq(_configuratorLogCount(), 0);
    assertTrue(_isDaiFrozen(spoke));
  }

  function test_unfreezeSpoke_skipsReservesUnfrozenOnSpoke() public {
    uint256 daiId = _daiReserveId(spoke);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeSpoke(spokeAddr);
    ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(daiId);
    reserveConfig.frozen = false;
    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(daiId, reserveConfig);

    vm.expectCall(spokeAddr, abi.encodeCall(ISpoke.updateReserveConfig, (daiId, reserveConfig)), 0);
    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unfreezeSpoke(spokeAddr);

    assertEq(_configuratorLogCount(), spoke.getReserveCount() - 1);
    _assertOnlyReserveFrozen(type(uint256).max);
  }

  function test_unfreezeSpoke_mixedReserveStates() public {
    uint256 wethId = _wethReserveId(spoke);
    uint256 wbtcId = _wbtcReserveId(spoke);
    uint256 daiId = _daiReserveId(spoke);

    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    // weth: frozen before `freezeSpoke`, so it is not recorded and stays frozen
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, address(tokenList.weth));
    // wbtc: not frozen with a zero collateral factor before `freezeSpoke`
    spokeConfigurator.zeroCollateralFactor(spokeAddr, hubAddr, address(tokenList.wbtc));
    // usdx, usdy: active collateral reserves before `freezeSpoke`
    emergencySteward.freezeSpoke(spokeAddr);
    // dai: frozen by `freezeSpoke`, then given a non-zero collateral factor
    spokeConfigurator.addCollateralFactor(spokeAddr, hubAddr, address(tokenList.dai), 60_00);
    vm.stopPrank();

    uint256 reserveCount = spoke.getReserveCount();
    ISpoke.DynamicReserveConfig[] memory before = new ISpoke.DynamicReserveConfig[](reserveCount);
    uint32[] memory beforeKeys = new uint32[](reserveCount);
    uint32[] memory beforeSaved = new uint32[](reserveCount);
    for (uint256 id; id < reserveCount; ++id) {
      before[id] = _getLatestDynamicReserveConfig(spoke, id);
      beforeKeys[id] = _latestKey(spoke, id);
      beforeSaved[id] = _savedKey(spoke, id);
    }

    vm.recordLogs();
    for (uint256 id; id < reserveCount; ++id) {
      if (id != wethId) {
        _expectReserveFrozenUpdated(spoke, id, true, false);
      }
    }
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unfreezeSpoke(spokeAddr);

    assertEq(_configuratorLogCount(), reserveCount - 1);
    for (uint256 id; id < reserveCount; ++id) {
      assertEq(spoke.getReserveConfig(id).frozen, id == wethId);
      assertEq(_latestKey(spoke, id), beforeKeys[id]);
      assertEq(_getLatestDynamicReserveConfig(spoke, id), before[id]);
      assertEq(_savedKey(spoke, id), beforeSaved[id]);
    }
    assertEq(before[wethId].collateralFactor, 0);
    assertEq(before[daiId].collateralFactor, 60_00);
    assertEq(before[wbtcId].collateralFactor, 0);

    // a second call is a no-op on every reserve and does not revert
    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unfreezeSpoke(spokeAddr);
    assertEq(_configuratorLogCount(), 0);
  }

  function test_getFrozenByBulkLevers() public {
    address dai = address(tokenList.dai);
    uint256 daiId = _daiReserveId(spoke);
    _grantAssetSpokesRole(daiAssetId);
    _assertFrozenByBulkLevers(spoke, daiId, false, false);

    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeAsset(hubAddr, dai);
    _assertFrozenByBulkLevers(spoke, daiId, true, false);

    emergencySteward.freezeSpoke(spokeAddr);
    _assertFrozenByBulkLevers(spoke, daiId, true, true);

    emergencySteward.unfreezeAsset(hubAddr, dai);
    _assertFrozenByBulkLevers(spoke, daiId, false, true);

    emergencySteward.unfreezeSpoke(spokeAddr);
    _assertFrozenByBulkLevers(spoke, daiId, false, false);
    vm.stopPrank();
  }

  function test_freezeAsset_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    emergencySteward.freezeAsset(hubAddr, underlying);
  }

  /// @dev DAI on hub1 is also registered for the TreasurySpoke, which has no reserves and must be skipped.
  function test_freezeAsset() public {
    address dai = address(tokenList.dai);
    assertTrue(hub1.isSpokeListed(daiAssetId, address(treasurySpoke)), 'treasury spoke listed');
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    assertGt(daiSpokes.length, 1, 'dai reserve on several spokes');

    for (uint256 i; i < daiSpokes.length; ++i) {
      uint256 id = daiSpokes[i].getReserveId(hubAddr, daiAssetId);
      ISpoke.ReserveConfig memory reserveConfig = daiSpokes[i].getReserveConfig(id);
      reserveConfig.frozen = true;
      vm.expectCall(
        address(daiSpokes[i]),
        abi.encodeCall(ISpoke.updateReserveConfig, (id, reserveConfig))
      );
      _expectReserveFrozenUpdated(daiSpokes[i], id, false, true);
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeAsset(hubAddr, dai);

    for (uint256 i; i < daiSpokes.length; ++i) {
      uint256 id = daiSpokes[i].getReserveId(hubAddr, daiAssetId);
      assertTrue(daiSpokes[i].getReserveConfig(id).frozen);
      assertEq(_getLatestDynamicReserveConfig(daiSpokes[i], id).collateralFactor, 0);
      _assertFrozenByBulkLevers(daiSpokes[i], id, true, false);
    }
  }

  function test_freezeAsset_doesNotRecordReservesAlreadyFrozen() public {
    address dai = address(tokenList.dai);
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, dai);
    emergencySteward.freezeAsset(hubAddr, dai);
    vm.stopPrank();

    for (uint256 i; i < daiSpokes.length; ++i) {
      _assertFrozenByBulkLevers(
        daiSpokes[i],
        _daiReserveId(daiSpokes[i]),
        address(daiSpokes[i]) != spokeAddr,
        false
      );
    }
  }

  function test_freezeAsset_skipsSpokeWithReserveNotListed() public {
    address dai = address(tokenList.dai);
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    ISpoke unlistedSpoke = daiSpokes[0];
    vm.mockCallRevert(
      address(unlistedSpoke),
      abi.encodeCall(ISpoke.getReserveId, (hubAddr, daiAssetId)),
      abi.encodeWithSelector(ISpoke.ReserveNotListed.selector)
    );

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeAsset(hubAddr, dai);
    vm.clearMockedCalls();

    for (uint256 i; i < daiSpokes.length; ++i) {
      assertEq(_isDaiFrozen(daiSpokes[i]), daiSpokes[i] != unlistedSpoke);
    }
  }

  function test_freezeAsset_revertsWith_unexpectedReserveLookupError() public {
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    bytes memory unexpectedError = abi.encodeWithSelector(bytes4(keccak256('UnexpectedError()')));
    vm.mockCallRevert(
      address(daiSpokes[1]),
      abi.encodeCall(ISpoke.getReserveId, (hubAddr, daiAssetId)),
      unexpectedError
    );

    vm.expectRevert(unexpectedError);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeAsset(hubAddr, address(tokenList.dai));
  }

  function test_unfreezeAsset_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    emergencySteward.unfreezeAsset(hubAddr, underlying);
  }

  function test_unfreezeAsset() public {
    address dai = address(tokenList.dai);
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeAsset(hubAddr, dai);

    vm.recordLogs();
    for (uint256 i; i < daiSpokes.length; ++i) {
      uint256 id = daiSpokes[i].getReserveId(hubAddr, daiAssetId);
      ISpoke.ReserveConfig memory reserveConfig = daiSpokes[i].getReserveConfig(id);
      reserveConfig.frozen = false;
      vm.expectCall(
        address(daiSpokes[i]),
        abi.encodeCall(ISpoke.updateReserveConfig, (id, reserveConfig))
      );
      _expectReserveFrozenUpdated(daiSpokes[i], id, true, false);
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unfreezeAsset(hubAddr, dai);

    assertEq(_configuratorLogCount(), daiSpokes.length);
    for (uint256 i; i < daiSpokes.length; ++i) {
      uint256 id = daiSpokes[i].getReserveId(hubAddr, daiAssetId);
      assertFalse(daiSpokes[i].getReserveConfig(id).frozen);
      // only the flag is cleared; the collateral factor zeroed by the freeze stays zero
      assertEq(_getLatestDynamicReserveConfig(daiSpokes[i], id).collateralFactor, 0);
      _assertFrozenByBulkLevers(daiSpokes[i], id, false, false);
    }

    // a second call finds no recorded reserves and does not revert
    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unfreezeAsset(hubAddr, dai);
    assertEq(_configuratorLogCount(), 0);
  }

  function test_unfreezeAsset_afterRepeatedFreezeAsset() public {
    address dai = address(tokenList.dai);
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeAsset(hubAddr, dai);
    emergencySteward.freezeAsset(hubAddr, dai);
    emergencySteward.unfreezeAsset(hubAddr, dai);
    vm.stopPrank();

    for (uint256 i; i < daiSpokes.length; ++i) {
      assertFalse(_isDaiFrozen(daiSpokes[i]));
    }
  }

  function test_unfreezeAsset_keepsReservesFrozenBeforeFreezeAsset() public {
    address dai = address(tokenList.dai);
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, dai);
    emergencySteward.freezeAsset(hubAddr, dai);
    emergencySteward.unfreezeAsset(hubAddr, dai);
    vm.stopPrank();

    for (uint256 i; i < daiSpokes.length; ++i) {
      assertEq(_isDaiFrozen(daiSpokes[i]), address(daiSpokes[i]) == spokeAddr);
    }
  }

  function test_unfreezeAsset_keepsReservesFrozenThroughFreezeReserve() public {
    address dai = address(tokenList.dai);
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeAsset(hubAddr, dai);
    spokeConfigurator.unfreezeReserve(spokeAddr, hubAddr, dai);
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, dai);
    _assertFrozenByBulkLevers(spoke, _daiReserveId(spoke), false, false);
    emergencySteward.unfreezeAsset(hubAddr, dai);
    vm.stopPrank();

    for (uint256 i; i < daiSpokes.length; ++i) {
      assertEq(_isDaiFrozen(daiSpokes[i]), address(daiSpokes[i]) == spokeAddr);
    }
  }

  function test_unfreezeAsset_keepsReservesFrozenThroughUpdateFrozen() public {
    address dai = address(tokenList.dai);
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeAsset(hubAddr, dai);
    spokeConfigurator.updateFrozen(spokeAddr, hubAddr, dai, true);
    _assertFrozenByBulkLevers(spoke, _daiReserveId(spoke), false, false);
    emergencySteward.unfreezeAsset(hubAddr, dai);
    vm.stopPrank();

    for (uint256 i; i < daiSpokes.length; ++i) {
      assertEq(_isDaiFrozen(daiSpokes[i]), address(daiSpokes[i]) == spokeAddr);
    }
  }

  function test_unfreezeAsset_keepsReservesFrozenThroughFreezeSpoke() public {
    address dai = address(tokenList.dai);
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeAsset(hubAddr, dai);
    emergencySteward.freezeSpoke(spokeAddr);
    _assertFrozenByBulkLevers(spoke, _daiReserveId(spoke), true, true);
    emergencySteward.unfreezeAsset(hubAddr, dai);
    vm.stopPrank();

    for (uint256 i; i < daiSpokes.length; ++i) {
      assertEq(_isDaiFrozen(daiSpokes[i]), address(daiSpokes[i]) == spokeAddr);
    }
    _assertFrozenByBulkLevers(spoke, _daiReserveId(spoke), false, true);

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unfreezeSpoke(spokeAddr);

    assertFalse(_isDaiFrozen(spoke));
    _assertFrozenByBulkLevers(spoke, _daiReserveId(spoke), false, false);
  }

  function test_unfreezeAsset_skipsReservesNotFrozenByFreezeAsset() public {
    address dai = address(tokenList.dai);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, dai);

    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unfreezeAsset(hubAddr, dai);

    assertEq(_configuratorLogCount(), 0);
    assertTrue(_isDaiFrozen(spoke));
  }

  function test_unfreezeAsset_revertsWith_unexpectedReserveLookupError() public {
    address dai = address(tokenList.dai);
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeAsset(hubAddr, dai);

    bytes memory unexpectedError = abi.encodeWithSignature('Error(string)', 'unexpected');
    vm.mockCallRevert(
      address(daiSpokes[1]),
      abi.encodeCall(ISpoke.getReserveId, (hubAddr, daiAssetId)),
      unexpectedError
    );

    vm.expectRevert(unexpectedError);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.unfreezeAsset(hubAddr, dai);
  }

  function test_unfreezeAsset_leavesOtherAssetsFrozen() public {
    _grantAssetSpokesRole(daiAssetId);
    _grantAssetSpokesRole(wethAssetId);
    vm.startPrank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.freezeAsset(hubAddr, address(tokenList.dai));
    emergencySteward.freezeAsset(hubAddr, address(tokenList.weth));
    emergencySteward.unfreezeAsset(hubAddr, address(tokenList.dai));
    vm.stopPrank();

    assertFalse(spoke.getReserveConfig(_daiReserveId(spoke)).frozen);
    assertTrue(spoke.getReserveConfig(_wethReserveId(spoke)).frozen);
  }

  function test_disableAssetBorrowing_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    emergencySteward.disableAssetBorrowing(hubAddr, underlying);
  }

  /// @dev DAI on hub1 is also registered for the TreasurySpoke, which has no reserves and must be skipped.
  function test_disableAssetBorrowing() public {
    address dai = address(tokenList.dai);
    assertTrue(hub1.isSpokeListed(daiAssetId, address(treasurySpoke)), 'treasury spoke listed');
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    assertGt(daiSpokes.length, 1, 'dai reserve on several spokes');

    ISpoke.ReserveConfig[] memory expectedConfigs = new ISpoke.ReserveConfig[](daiSpokes.length);
    uint32[] memory oldKeys = new uint32[](daiSpokes.length);
    vm.recordLogs();
    for (uint256 i; i < daiSpokes.length; ++i) {
      uint256 id = _daiReserveId(daiSpokes[i]);
      expectedConfigs[i] = daiSpokes[i].getReserveConfig(id);
      assertTrue(expectedConfigs[i].borrowable);
      expectedConfigs[i].borrowable = false;
      oldKeys[i] = _latestKey(daiSpokes[i], id);
      vm.expectCall(
        address(spokeConfigurator),
        abi.encodeCall(ISpokeConfigurator.disableBorrowing, (address(daiSpokes[i]), hubAddr, dai))
      );
      vm.expectCall(
        address(daiSpokes[i]),
        abi.encodeCall(ISpoke.updateReserveConfig, (id, expectedConfigs[i]))
      );
      vm.expectEmit(address(spokeConfigurator));
      emit ISpokeConfigurator.ReserveBorrowableUpdated(
        address(daiSpokes[i]),
        hubAddr,
        dai,
        id,
        true,
        false
      );
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.disableAssetBorrowing(hubAddr, dai);

    assertEq(_configuratorLogCount(), daiSpokes.length);
    for (uint256 i; i < daiSpokes.length; ++i) {
      uint256 id = _daiReserveId(daiSpokes[i]);
      // only the borrowable flag changes; frozen, paused and the collateral factor are untouched
      assertEq(daiSpokes[i].getReserveConfig(id), expectedConfigs[i]);
      assertEq(_latestKey(daiSpokes[i], id), oldKeys[i]);
    }
  }

  function test_disableAssetBorrowing_skipsReservesAlreadyNotBorrowable() public {
    address dai = address(tokenList.dai);
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    uint256 daiId = _daiReserveId(spoke);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateBorrowable(spokeAddr, hubAddr, dai, false);

    ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(daiId);
    vm.expectCall(spokeAddr, abi.encodeCall(ISpoke.updateReserveConfig, (daiId, reserveConfig)), 0);
    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.disableAssetBorrowing(hubAddr, dai);

    assertEq(_configuratorLogCount(), daiSpokes.length - 1);
    for (uint256 i; i < daiSpokes.length; ++i) {
      assertFalse(_isDaiBorrowable(daiSpokes[i]));
    }

    // a second call is a no-op on every reserve and does not revert
    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.disableAssetBorrowing(hubAddr, dai);
    assertEq(_configuratorLogCount(), 0);
  }

  function test_disableAssetBorrowing_skipsSpokeWithReserveNotListed() public {
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    ISpoke unlistedSpoke = daiSpokes[0];
    vm.mockCallRevert(
      address(unlistedSpoke),
      abi.encodeCall(ISpoke.getReserveId, (hubAddr, daiAssetId)),
      abi.encodeWithSelector(ISpoke.ReserveNotListed.selector)
    );

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.disableAssetBorrowing(hubAddr, address(tokenList.dai));
    vm.clearMockedCalls();

    for (uint256 i; i < daiSpokes.length; ++i) {
      assertEq(_isDaiBorrowable(daiSpokes[i]), daiSpokes[i] == unlistedSpoke);
    }
  }

  function test_disableAssetBorrowing_revertsWith_unexpectedReserveLookupError() public {
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    bytes memory unexpectedError = abi.encodeWithSelector(bytes4(keccak256('UnexpectedError()')));
    vm.mockCallRevert(
      address(daiSpokes[1]),
      abi.encodeCall(ISpoke.getReserveId, (hubAddr, daiAssetId)),
      unexpectedError
    );

    vm.expectRevert(unexpectedError);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.disableAssetBorrowing(hubAddr, address(tokenList.dai));
  }

  function test_disableAssetBorrowing_revertsWith_AccessManagedUnauthorized_onSpoke() public {
    address dai = address(tokenList.dai);
    ISpoke[] memory daiSpokes = _grantAssetSpokesRole(daiAssetId);
    for (uint256 i; i < daiSpokes.length; ++i) {
      IAccessManager spokeAuthority = IAccessManager(daiSpokes[i].authority());
      vm.prank(ADMIN);
      spokeAuthority.revokeRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(spokeConfigurator));
    }

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManaged.AccessManagedUnauthorized.selector,
        address(spokeConfigurator)
      )
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.disableAssetBorrowing(hubAddr, dai);

    // reserves that are already not borrowable are skipped without calling the Spoke
    for (uint256 i; i < daiSpokes.length; ++i) {
      _updateReserveBorrowableFlag(daiSpokes[i], _daiReserveId(daiSpokes[i]), false);
    }
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.disableAssetBorrowing(hubAddr, dai);
  }

  function test_disableAssetBorrowing_leavesOtherAssetsBorrowable() public {
    _grantAssetSpokesRole(daiAssetId);
    uint256 daiId = _daiReserveId(spoke);
    uint256 reserveCount = spoke.getReserveCount();
    bool[] memory borrowableBefore = new bool[](reserveCount);
    for (uint256 id; id < reserveCount; ++id) {
      borrowableBefore[id] = spoke.getReserveConfig(id).borrowable;
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    emergencySteward.disableAssetBorrowing(hubAddr, address(tokenList.dai));

    for (uint256 id; id < reserveCount; ++id) {
      assertEq(spoke.getReserveConfig(id).borrowable, id == daiId ? false : borrowableBefore[id]);
    }
  }

  /// @dev Asserts that `pausedId` is the only paused reserve of the Spoke; pass an unused id to assert none is.
  function _assertOnlyReservePaused(uint256 pausedId) internal view {
    for (uint256 id; id < spoke.getReserveCount(); ++id) {
      assertEq(spoke.getReserveConfig(id).paused, id == pausedId);
    }
  }

  /// @dev Asserts that `frozenId` is the only frozen reserve of the Spoke; pass an unused id to assert none is.
  function _assertOnlyReserveFrozen(uint256 frozenId) internal view {
    for (uint256 id; id < spoke.getReserveCount(); ++id) {
      assertEq(spoke.getReserveConfig(id).frozen, id == frozenId);
    }
  }

  /// @dev Grants this configurator permission on every Spoke with a reserve for the asset on hub1 and
  /// returns them, skipping the TreasurySpoke.
  function _grantAssetSpokesRole(uint256 assetId) internal returns (ISpoke[] memory spokes) {
    uint256 spokeCount = hub1.getSpokeCount(assetId);
    spokes = new ISpoke[](spokeCount);
    uint256 count;
    for (uint256 i; i < spokeCount; ++i) {
      address spokeAddress = hub1.getSpokeAddress(assetId, i);
      if (spokeAddress == address(treasurySpoke)) continue;
      spokes[count] = ISpoke(spokeAddress);
      _grantSpokeConfiguratorRole(spokes[count], address(spokeConfigurator));
      ++count;
    }
    assembly ('memory-safe') {
      mstore(spokes, count)
    }
  }

  function _isDaiFrozen(ISpoke targetSpoke) internal view returns (bool) {
    return targetSpoke.getReserveConfig(targetSpoke.getReserveId(hubAddr, daiAssetId)).frozen;
  }

  function _isDaiBorrowable(ISpoke targetSpoke) internal view returns (bool) {
    return targetSpoke.getReserveConfig(targetSpoke.getReserveId(hubAddr, daiAssetId)).borrowable;
  }
}
