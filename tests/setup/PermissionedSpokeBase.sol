// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';
import {PermissionedSpokeInstance} from 'src/spoke/instances/PermissionedSpokeInstance.sol';
import {IPermissionedSpoke} from 'src/spoke/interfaces/IPermissionedSpoke.sol';
import {MockSpokeGate} from 'tests/helpers/mocks/MockSpokeGate.sol';

/// @dev Deploys a spoke with the `PermissionedSpokeInstance` implementation gated by a mock gate,
/// with two reserves on hub1 (weth as collateral, usdx as borrowable).
abstract contract PermissionedSpokeBase is Base {
  ISpoke internal spoke;
  MockSpokeGate internal gate;
  address internal RWA_MANAGER = makeAddr('RWA_MANAGER');
  address internal PROXY_ADMIN_OWNER = makeAddr('PROXY_ADMIN_OWNER');

  uint256 internal wethReserveId;
  uint256 internal usdxReserveId;

  function setUp() public virtual override {
    super.setUp();

    gate = new MockSpokeGate();
    spoke = _deployPermissionedSpoke(address(gate));
  }

  /// @dev Deploys a permissioned spoke with the given gate, mirroring the standard fixture config.
  function _deployPermissionedSpoke(address newGate) internal returns (ISpoke newSpoke) {
    AaveOracle oracle = new AaveOracle(8);
    PermissionedSpokeInstance implementation = new PermissionedSpokeInstance({
      oracle_: address(oracle),
      maxUserReservesLimit_: DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT
    });
    newSpoke = ISpoke(
      address(
        new TransparentUpgradeableProxy(
          address(implementation),
          PROXY_ADMIN_OWNER,
          abi.encodeWithSignature('initialize(address,address)', address(accessManager), newGate)
        )
      )
    );
    oracle.setSpoke(address(newSpoke));
    setUpRoles(hub1, newSpoke, accessManager);

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: MAX_ALLOWED_SPOKE_CAP,
      drawCap: MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: MAX_ALLOWED_COLLATERAL_RISK
    });

    vm.startPrank(ADMIN);
    wethReserveId = newSpoke.addReserve(
      address(hub1),
      wethAssetId,
      _deployMockPriceFeed(newSpoke, 2000e8),
      _getDefaultReserveConfig(15_00),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 10_00
      })
    );
    usdxReserveId = newSpoke.addReserve(
      address(hub1),
      usdxAssetId,
      _deployMockPriceFeed(newSpoke, 1e8),
      _getDefaultReserveConfig(20_00),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 78_00,
        maxLiquidationBonus: 101_00,
        liquidationFee: 12_00
      })
    );
    hub1.addSpoke(wethAssetId, address(newSpoke), spokeConfig);
    hub1.addSpoke(usdxAssetId, address(newSpoke), spokeConfig);
    vm.stopPrank();

    address[3] memory users = [alice, bob, RWA_MANAGER];
    for (uint256 i = 0; i < users.length; ++i) {
      vm.startPrank(users[i]);
      tokenList.weth.approve(address(newSpoke), type(uint256).max);
      tokenList.usdx.approve(address(newSpoke), type(uint256).max);
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
}
