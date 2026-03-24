// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4SpokeDeployProcedureTest is ProceduresBase {
  AaveV4SpokeDeployProcedureWrapper public aaveV4SpokeDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4SpokeDeployProcedureWrapper = new AaveV4SpokeDeployProcedureWrapper();
  }

  function test_deployUpgradeableSpokeInstance() public {
    (address spokeProxy, address spokeImplementation) = aaveV4SpokeDeployProcedureWrapper
      .deployUpgradeableSpokeInstance(
        owner,
        accessManager,
        aaveOracle,
        spokeBytecode,
        maxUserReservesLimit,
        salt
      );
    assertNotEq(spokeProxy, address(0));
    assertNotEq(spokeImplementation, address(0));
    assertEq(Ownable(ProxyHelper.getProxyAdmin(spokeProxy)).owner(), owner);
    assertEq(ProxyHelper.getImplementation(spokeProxy), spokeImplementation);
    assertEq(ISpoke(spokeProxy).ORACLE(), aaveOracle);
  }

  function test_deployUpgradeableSpokeInstance_reverts() public {
    vm.expectRevert('invalid spoke proxy admin owner');
    aaveV4SpokeDeployProcedureWrapper.deployUpgradeableSpokeInstance({
      spokeProxyAdminOwner: address(0),
      authority: accessManager,
      oracle: aaveOracle,
      spokeBytecode: spokeBytecode,
      maxUserReservesLimit: maxUserReservesLimit,
      salt: salt
    });

    vm.expectRevert('invalid authority');
    aaveV4SpokeDeployProcedureWrapper.deployUpgradeableSpokeInstance({
      spokeProxyAdminOwner: owner,
      authority: address(0),
      oracle: aaveOracle,
      spokeBytecode: spokeBytecode,
      maxUserReservesLimit: maxUserReservesLimit,
      salt: salt
    });

    vm.expectRevert('invalid oracle');
    aaveV4SpokeDeployProcedureWrapper.deployUpgradeableSpokeInstance({
      spokeProxyAdminOwner: owner,
      authority: accessManager,
      oracle: address(0),
      spokeBytecode: spokeBytecode,
      maxUserReservesLimit: maxUserReservesLimit,
      salt: salt
    });

    vm.expectRevert('invalid max user reserves limit');
    aaveV4SpokeDeployProcedureWrapper.deployUpgradeableSpokeInstance({
      spokeProxyAdminOwner: owner,
      authority: accessManager,
      oracle: aaveOracle,
      spokeBytecode: spokeBytecode,
      maxUserReservesLimit: 0,
      salt: salt
    });
  }
}
