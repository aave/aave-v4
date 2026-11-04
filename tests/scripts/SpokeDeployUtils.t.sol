// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Vm} from 'forge-std/Vm.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {SpokeDeployUtils} from 'scripts/utils/SpokeDeployUtils.sol';
import {Create2TestHelper} from 'tests/utils/Create2TestHelper.sol';

/// @dev `LibraryPreCompile` (the mandatory first deployment step) deploys LiquidationLogic
/// through the permissionless Safe Singleton Factory with a HARDCODED `bytes32(0)` salt and no
/// deployer namespacing. `Create2Utils.create2Deploy` reverts when the computed address is already
/// occupied, and LiquidationLogic is a plain library: its init code has no constructor arguments
/// and no dependency on any chain state, so anyone can deploy it at that exact address first.
/// @dev Thin external wrapper so `vm.expectRevert` sees a sub-call frame.
contract PreCompileHarness {
  function deploy(bytes32 salt) external returns (address) {
    return SpokeDeployUtils.deployLiquidationLogic(salt);
  }
}

contract SpokeDeployUtilsTest is Test, Create2TestHelper {
  PreCompileHarness internal harness;
  address internal ATTACKER = makeAddr('ATTACKER');

  function setUp() public {
    _etchCreate2Factory();
    harness = new PreCompileHarness();
  }

  function _liquidationLogicInitCode() internal view returns (bytes memory) {
    return vm.getCode('src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic');
  }

  /// @dev Control: on a clean chain the pre-compile step works.
  function test_baseline_deploysLiquidationLogic() public {
    address deployed = harness.deploy(bytes32(0));
    assertGt(deployed.code.length, 0, 'library should be deployed');
  }

  /// @dev PROOF: the salt is a public constant and the init code is state-independent, so a third
  /// party can occupy the address and the mandatory deployment step then reverts.
  function test_attackerOccupiesZeroSaltAddress_blocksDeploymentStep() public {
    bytes memory initCode = _liquidationLogicInitCode();
    address predicted = Create2Utils.computeCreate2Address(bytes32(0), initCode);

    assertEq(predicted.code.length, 0, 'address must be free before the attack');

    // Anyone can do this: no arguments to guess, no protocol state required.
    vm.prank(ATTACKER);
    (bool ok, ) = Create2Utils.CREATE2_FACTORY.call(abi.encodePacked(bytes32(0), initCode));
    assertTrue(ok, 'attacker deployment succeeds');
    assertGt(predicted.code.length, 0, 'attacker occupies the deterministic address');

    // BEFORE THE FIX this reverted with Create2Utils.ContractAlreadyDeployed, blocking
    // `make deploy-precompile` with no configurable salt to route around it.
    // AFTER THE FIX the step reuses the identical contract already at that address.
    address deployed = harness.deploy(bytes32(0));
    assertEq(deployed, predicted, 'step reuses the deterministic address');
    assertEq(
      predicted.codehash,
      keccak256(deployed.code),
      'reused contract is the one the step would have deployed'
    );
  }

  /// @dev Re-running the step after a legitimate deployment (e.g. when the .env guard in
  /// LibraryPreCompile is absent) must be a no-op rather than a revert.
  function test_stepIsIdempotent() public {
    address first = harness.deploy(bytes32(0));
    // BEFORE THE FIX this second call reverted with ContractAlreadyDeployed.
    address second = harness.deploy(bytes32(0));

    assertEq(second, first, 're-running the step is a no-op');
    assertGt(first.code.length, 0);
  }

  /// @dev The adoption branch must stay visible in the deployment receipt: a fresh deploy emits
  /// nothing, an adoption emits Create2DeploymentAdopted. This preserves the diagnostic signal
  /// that the removed revert used to provide, without reintroducing the DoS.
  function test_adoptionIsObservableInLogs() public {
    bytes memory initCode = _liquidationLogicInitCode();
    address predicted = Create2Utils.computeCreate2Address(bytes32(0), initCode);

    // Fresh deployment: no adoption event.
    vm.recordLogs();
    harness.deploy(bytes32(0));
    Vm.Log[] memory freshLogs = vm.getRecordedLogs();
    for (uint256 i; i < freshLogs.length; ++i) {
      assertTrue(
        freshLogs[i].topics[0] != Create2Utils.Create2DeploymentAdopted.selector,
        'fresh deployment must not emit an adoption event'
      );
    }

    // Re-run: adoption event, emitted by the caller of the inlined library.
    vm.expectEmit(true, false, false, true, address(harness));
    emit Create2Utils.Create2DeploymentAdopted(predicted, bytes32(0));
    harness.deploy(bytes32(0));
  }

  /// @dev Contrast with the main orchestration, which namespaces its root salt with the deployer.
  /// The pre-compile step does not, and hardcodes zero.
  function test_contrast_orchestrationSaltIsDeployerNamespaced() public pure {
    address deployer = address(0x1111111111111111111111111111111111111111);
    bytes32 derived = bytes32(bytes20(deployer)) |
      (keccak256(abi.encode(keccak256('AAVE_V4'), bytes32(0))) >> 160);

    assertEq(address(bytes20(derived)), deployer, 'orchestration salt embeds the deployer');
    assertTrue(derived != bytes32(0), 'orchestration salt is never the zero salt');
  }
}
