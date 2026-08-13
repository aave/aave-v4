// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

import {PermissionedBorrowAccessManager} from 'src/access/PermissionedBorrowAccessManager.sol';
import {MockBorrowerEligibility} from 'tests/helpers/mocks/MockBorrowerEligibility.sol';

/// forge-config: default.isolate = true
contract PermissionedBorrowOperations_Gas_Tests is Base {
  string internal NAMESPACE = 'PermissionedBorrow.Operations';

  ISpoke internal spoke;
  IAccessManager internal defaultAccessManager;
  PermissionedBorrowAccessManager internal permissionedAccessManager;
  MockBorrowerEligibility internal eligibility;

  uint256 internal wethReserveId;
  uint256 internal usdxReserveId;

  function setUp() public virtual override {
    super.setUp();

    // Match PR #1334's isolated permissioned-Spoke setup.
    TestTypes.TestEnvReport memory report = AaveV4TestOrchestration.deployTestEnv({
      admin: ADMIN,
      treasuryAdmin: TREASURY_ADMIN,
      hubCount: 0,
      spokeCount: 1,
      nativeWrapper: address(tokenList.weth),
      hubBytecode: BytecodeHelper.getHubBytecode(),
      spokeBytecode: BytecodeHelper.getSpokeBytecode(),
      salt: bytes32(vm.randomBytes(32))
    });
    _setupFixturesRoles(report);
    spoke = ISpoke(report.spokeReports[0].spoke);
    defaultAccessManager = IAccessManager(report.accessManager);
    eligibility = new MockBorrowerEligibility();
    permissionedAccessManager = new PermissionedBorrowAccessManager(ADMIN, spoke, eligibility);

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

    address[2] memory users = [alice, bob];
    for (uint256 i = 0; i < users.length; ++i) {
      vm.startPrank(users[i]);
      tokenList.weth.approve(address(spoke), type(uint256).max);
      tokenList.usdx.approve(address(spoke), type(uint256).max);
      vm.stopPrank();
    }

    // Seed borrowable liquidity, matching PR #1334.
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 100_000e6,
      onBehalfOf: bob
    });
  }

  function test_updateAuthority() public {
    vm.prank(ADMIN);
    defaultAccessManager.updateAuthority(address(spoke), address(permissionedAccessManager));
    vm.snapshotGasLastCall(NAMESPACE, 'updateAuthority: permissioned manager');
  }

  function test_operations_defaultAccessManager() public {
    _snapshotOperations('default manager');
  }

  function test_operations_permissionedBorrowAccessManager() public {
    eligibility.setEligible(alice, true);
    vm.prank(ADMIN);
    defaultAccessManager.updateAuthority(address(spoke), address(permissionedAccessManager));

    _snapshotOperations('permissioned manager');
  }

  function _snapshotOperations(string memory label) internal {
    vm.startPrank(alice);
    spoke.supply(usdxReserveId, 1000e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('supply: ', label));

    spoke.setUsingAsCollateral(usdxReserveId, true, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('usingAsCollateral: enable, ', label));

    spoke.borrow(usdxReserveId, 100e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('borrow: ', label));

    skip(100);

    spoke.repay(usdxReserveId, 50e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('repay: partial, ', label));

    spoke.withdraw(usdxReserveId, 100e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('withdraw: partial, ', label));
    vm.stopPrank();
  }
}
