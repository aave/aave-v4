// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

import {PermissionedSpokeInstance} from 'src/spoke/instances/PermissionedSpokeInstance.sol';
import {IPermissionedSpoke} from 'src/spoke/interfaces/IPermissionedSpoke.sol';
import {MockMandatoryPositionManager} from 'tests/helpers/mocks/MockMandatoryPositionManager.sol';

/// @dev Deploys a spoke with the `PermissionedSpokeInstance` implementation, two reserves on hub1
/// (weth as collateral, usdx as borrowable) and a mock mandatory position manager.
abstract contract PermissionedSpokeBase is Base {
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
