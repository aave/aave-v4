// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/utils/BatchTestProcedures.sol';

import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';

/// @dev Deterministic CREATE2 deployment must be idempotent.
///
/// The orchestration derives its root salt as
///   `bytes32(bytes20(deployer)) | (keccak256(abi.encode(SALT, deployInputs.salt)) >> 160)`
/// which looks deployer-namespaced. But the Safe Singleton Factory does not enforce the salt
/// prefix, so namespacing only helps if the salt is UNPREDICTABLE. When `deployInputs.salt` is
/// left at `bytes32(0)` — which the deploy script permits with a warning only, and which the
/// repo's own deployment tests use — every input is public and the whole root salt is computable
/// in advance from the (public) deployer address alone.
contract AaveV4DeployOrchestrationIdempotencyTest is BatchTestProcedures {
  address internal ATTACKER = makeAddr('ATTACKER');

  function setUp() public override {
    super.setUp();

    _inputs = InputUtils.FullDeployInputs({
      accessManagerAdmin: makeAddr('accessManagerAdmin'),
      proxyAdminOwner: makeAddr('proxyAdminOwner'),
      hubAdmin: makeAddr('hubAdmin'),
      hubConfiguratorAdmin: makeAddr('hubConfiguratorAdmin'),
      treasurySpokeOwner: makeAddr('treasurySpokeOwner'),
      spokeAdmin: makeAddr('spokeAdmin'),
      spokeConfiguratorAdmin: makeAddr('spokeConfiguratorAdmin'),
      gatewayOwner: makeAddr('gatewayOwner'),
      positionManagerOwner: makeAddr('positionManagerOwner'),
      nativeWrapper: _weth9,
      deployNativeTokenGateway: false,
      deploySignatureGateway: false,
      deployPositionManagers: false,
      grantRoles: true,
      hubLabels: _hubLabels,
      spokeLabels: _spokeLabels,
      spokeMaxReservesLimits: _defaultSpokeMaxReservesLimits(_spokeLabels.length),
      salt: bytes32(0)
    });
  }

  /// @dev Reproduces AaveV4DeployOrchestration._deriveSalt using only public information.
  function _rootSalt(address deployer, bytes32 userSalt) internal pure returns (bytes32) {
    return
      bytes32(bytes20(deployer)) |
      (keccak256(abi.encode(keccak256('AAVE_V4'), userSalt)) >> 160);
  }

  /// @dev External so `vm.expectRevert` binds to the deployment frame; `deployAaveV4` is an
  /// internal library and would otherwise be inlined at test depth.
  function runDeploymentExternal() external {
    vm.startPrank(_deployer);
    AaveV4DeployOrchestration.deployAaveV4(
      _logger,
      _deployer,
      _inputs,
      BytecodeHelper.getHubBytecode(),
      BytecodeHelper.getSpokeBytecode()
    );
    vm.stopPrank();
  }

  function _runDeployment() internal {
    this.runDeploymentExternal();
  }

  /// @dev Control: the deployment works when nobody interferes.
  function test_baseline_deploymentSucceeds() public {
    _runDeployment();
  }

  /// @dev PROOF: with the zero user salt, the AccessManagerEnumerable address — the very first
  /// contract of the deployment — is computable by anyone, and its init code has no precondition
  /// (constructor only stores an admin), so a third party can occupy it and brick the whole run.
  function test_attackerOccupiesAccessManager_deploymentStillCompletes() public {
    bytes32 salt = _rootSalt(_deployer, bytes32(0));

    // Root admin is the deployer itself (AaveV4DeployOrchestration sets initialAdmin = deployer).
    bytes memory initCode = abi.encodePacked(
      type(AccessManagerEnumerable).creationCode,
      abi.encode(_deployer)
    );
    address predicted = Create2Utils.computeCreate2Address(salt, initCode);

    assertEq(predicted.code.length, 0, 'address free before the attack');

    vm.prank(ATTACKER);
    (bool ok, ) = Create2Utils.CREATE2_FACTORY.call(abi.encodePacked(salt, initCode));
    assertTrue(ok, 'attacker can deploy it: no unmet constructor precondition');
    assertGt(predicted.code.length, 0, 'attacker occupies the AccessManager address');

    // BEFORE THE FIX: reverted with Create2Utils.ContractAlreadyDeployed, bricking the run.
    // AFTER THE FIX: the deployment reuses the identical contract and completes.
    this.runDeploymentExternal();
    assertGt(predicted.code.length, 0, 'deployment completed reusing the occupied address');
  }

  /// @dev The Hub implementation is the softest target of all: `create2Deploy` is called with the
  /// raw compiled bytecode and NO constructor arguments, so its init code is a public constant.
  /// Only the child salt is needed, and that is derived from the root salt plus the hub label.
  function test_attackerOccupiesHubImplementation_deploymentStillCompletes() public {
    bytes32 salt = _rootSalt(_deployer, bytes32(0));
    bytes32 childSalt = keccak256(abi.encode(salt, 'hub', _hubLabels[0]));

    bytes memory hubBytecode = BytecodeHelper.getHubBytecode();
    address predicted = Create2Utils.computeCreate2Address(childSalt, hubBytecode);

    vm.prank(ATTACKER);
    (bool ok, ) = Create2Utils.CREATE2_FACTORY.call(abi.encodePacked(childSalt, hubBytecode));
    assertTrue(ok, 'HubInstance has no constructor args and no preconditions');
    assertGt(predicted.code.length, 0, 'attacker occupies the Hub implementation address');

    // BEFORE THE FIX: reverted with Create2Utils.ContractAlreadyDeployed.
    this.runDeploymentExternal();
    assertGt(predicted.code.length, 0, 'deployment completed reusing the occupied address');
  }

  /// @dev A non-zero, unguessable user salt removes the pre-positioning capability: the attacker
  /// cannot compute the address ahead of the deployment transaction.
  function test_nonZeroSecretSalt_addressIsNotPrecomputable() public {
    bytes32 secret = keccak256('operator chosen secret salt');
    bytes32 guessed = _rootSalt(_deployer, bytes32(0));
    bytes32 actual = _rootSalt(_deployer, secret);

    assertTrue(guessed != actual, 'a secret user salt changes the derived root salt');

    _inputs.salt = secret;
    // Occupying the address the attacker CAN compute (zero-salt derivation) is now harmless.
    bytes memory initCode = abi.encodePacked(
      type(AccessManagerEnumerable).creationCode,
      abi.encode(_deployer)
    );
    vm.prank(ATTACKER);
    Create2Utils.CREATE2_FACTORY.call(abi.encodePacked(guessed, initCode));

    _runDeployment();
  }
}
