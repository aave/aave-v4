// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

import {PermissionedSpokeInstance} from 'src/spoke/instances/PermissionedSpokeInstance.sol';
import {IPermissionedSpoke} from 'src/spoke/interfaces/IPermissionedSpoke.sol';
import {MockMandatoryPositionManager} from 'tests/helpers/mocks/MockMandatoryPositionManager.sol';

contract PermissionedSpokeTest is Base {
  ISpoke internal spoke;
  MockMandatoryPositionManager internal mandatoryPositionManager;
  address internal RWA_MANAGER = makeAddr('RWA_MANAGER');

  uint256 internal wethReserveId;
  uint256 internal usdxReserveId;

  function setUp() public virtual override {
    super.setUp();

    // Deploy a fresh spoke with the PermissionedSpokeInstance implementation
    TestTypes.TestEnvReport memory report = AaveV4TestOrchestration.deployTestEnv({
      admin: ADMIN,
      treasuryAdmin: TREASURY_ADMIN,
      hubCount: 0,
      spokeCount: 1,
      nativeWrapper: address(tokenList.weth),
      hubBytecode: BytecodeHelper.getHubBytecode(),
      spokeBytecode: vm.getCode(
        'src/spoke/instances/PermissionedSpokeInstance.sol:PermissionedSpokeInstance'
      ),
      salt: bytes32(vm.randomBytes(32))
    });
    _setupFixturesRoles(report);
    spoke = ISpoke(report.spokeReports[0].spoke);
    mandatoryPositionManager = new MockMandatoryPositionManager(spoke);

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: MAX_ALLOWED_SPOKE_CAP,
      drawCap: MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: MAX_ALLOWED_COLLATERAL_RISK
    });

    vm.startPrank(ADMIN);
    wethReserveId = spoke.addReserve(
      address(hub1),
      wethAssetId,
      _deployMockPriceFeed(spoke, 2000e8),
      _getDefaultReserveConfig(15_00),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 10_00
      })
    );
    usdxReserveId = spoke.addReserve(
      address(hub1),
      usdxAssetId,
      _deployMockPriceFeed(spoke, 1e8),
      _getDefaultReserveConfig(20_00),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 78_00,
        maxLiquidationBonus: 101_00,
        liquidationFee: 12_00
      })
    );
    hub1.addSpoke(wethAssetId, address(spoke), spokeConfig);
    hub1.addSpoke(usdxAssetId, address(spoke), spokeConfig);
    vm.stopPrank();

    address[3] memory users = [alice, bob, RWA_MANAGER];
    for (uint256 i = 0; i < users.length; ++i) {
      vm.startPrank(users[i]);
      tokenList.weth.approve(address(spoke), type(uint256).max);
      tokenList.usdx.approve(address(spoke), type(uint256).max);
      vm.stopPrank();
    }
  }

  function test_defaultBehavior_withoutMandatoryPositionManager() public {
    _supplyCollateralAndBorrow(alice, 100e6);

    // an unapproved caller still cannot act on behalf of alice
    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 1e6,
      onBehalfOf: alice
    });
  }

  function test_updateMandatoryPositionManager() public {
    vm.expectEmit(address(spoke));
    emit IPermissionedSpoke.UpdateMandatoryPositionManager(address(mandatoryPositionManager));

    vm.prank(ADMIN);
    PermissionedSpokeInstance(address(spoke)).updateMandatoryPositionManager(
      address(mandatoryPositionManager)
    );

    assertEq(
      PermissionedSpokeInstance(address(spoke)).getMandatoryPositionManager(),
      address(mandatoryPositionManager)
    );
  }

  function test_updateMandatoryPositionManager_removal() public {
    _setMandatoryPositionManager(address(mandatoryPositionManager));
    _setMandatoryPositionManager(address(0));

    assertEq(PermissionedSpokeInstance(address(spoke)).getMandatoryPositionManager(), address(0));

    // default authorization is restored
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });
  }

  function test_updateMandatoryPositionManager_revertsIfUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    PermissionedSpokeInstance(address(spoke)).updateMandatoryPositionManager(
      address(mandatoryPositionManager)
    );
  }

  function test_permissionedBorrow() public {
    mandatoryPositionManager.setGated(ISpoke.borrow.selector, true);
    _setMandatoryPositionManager(address(mandatoryPositionManager));

    // supply is not gated for ineligible users
    SpokeActions.supplyCollateral({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 200e6,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    mandatoryPositionManager.setEligible(alice, true);
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    assertEq(spoke.getUserTotalDebt(usdxReserveId, alice), 100e6);
  }

  function test_defaultApprovalsPreservedViaCallback() public {
    _setMandatoryPositionManager(address(mandatoryPositionManager));

    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    // bob is not an approved position manager for alice
    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 50e6,
      onBehalfOf: alice
    });

    // approving bob as position manager makes the call pass through the callback
    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager(bob, true);
    vm.prank(alice);
    spoke.setUserPositionManager(bob, true);

    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 50e6,
      onBehalfOf: alice
    });

    assertEq(spoke.getUserSuppliedAssets(usdxReserveId, alice), 50e6);
  }

  /// @dev Horizon-style forced transfer: the RWA manager moves alice's position to bob by
  /// withdrawing on her behalf and re-supplying to bob, without any user approval.
  function test_forcedTransfer_viaGlobalManager() public {
    mandatoryPositionManager.setGlobalManager(RWA_MANAGER, true);
    _setMandatoryPositionManager(address(mandatoryPositionManager));

    uint256 amount = 100e6;
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    uint256 balanceBefore = tokenList.usdx.balanceOf(RWA_MANAGER);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });
    assertEq(tokenList.usdx.balanceOf(RWA_MANAGER), balanceBefore + amount);

    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      amount: amount,
      onBehalfOf: bob
    });

    assertEq(spoke.getUserSuppliedAssets(usdxReserveId, alice), 0);
    assertEq(spoke.getUserSuppliedAssets(usdxReserveId, bob), amount);
  }

  function test_forcedWithdraw_stillValidatesHealthFactor() public {
    mandatoryPositionManager.setGlobalManager(RWA_MANAGER, true);
    _setMandatoryPositionManager(address(mandatoryPositionManager));

    _supplyCollateralAndBorrow(alice, 100e6);

    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      amount: 100e6,
      onBehalfOf: alice
    });
  }

  function test_liquidationCallUnaffected() public {
    _setMandatoryPositionManager(address(mandatoryPositionManager));

    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 10_000e6,
      onBehalfOf: bob
    });
    SpokeActions.supplyCollateral({
      spoke: spoke,
      reserveId: wethReserveId,
      caller: alice,
      amount: 1e18,
      onBehalfOf: alice
    });
    _borrowToBeLiquidatableWithPriceChange({
      spoke: spoke,
      user: alice,
      reserveId: usdxReserveId,
      collateralReserveId: wethReserveId,
      desiredHf: 1.01e18,
      pricePercentage: 90_00
    });

    uint256 debtBefore = spoke.getUserTotalDebt(usdxReserveId, alice);

    // bob is neither eligible nor a global manager; liquidations are not gated
    SpokeActions.liquidationCall({
      spoke: spoke,
      collateralReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      user: alice,
      debtToCover: type(uint256).max,
      receiveShares: false,
      caller: bob
    });

    assertLt(spoke.getUserTotalDebt(usdxReserveId, alice), debtBefore, 'liquidation executed');
  }

  function test_cannotBeBypassedWithMulticall() public {
    mandatoryPositionManager.setGated(ISpoke.borrow.selector, true);
    _setMandatoryPositionManager(address(mandatoryPositionManager));

    bytes[] memory calls = new bytes[](1);
    calls[0] = abi.encodeCall(ISpoke.borrow, (usdxReserveId, 100e6, alice));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(alice);
    spoke.multicall(calls);
  }

  function _supplyCollateralAndBorrow(address user, uint256 amount) internal {
    SpokeActions.supplyCollateral({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: user,
      amount: amount * 2,
      onBehalfOf: user
    });
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: user,
      amount: amount,
      onBehalfOf: user
    });
  }

  function _setMandatoryPositionManager(address newMandatoryPositionManager) internal {
    vm.prank(ADMIN);
    PermissionedSpokeInstance(address(spoke)).updateMandatoryPositionManager(
      newMandatoryPositionManager
    );
  }
}
