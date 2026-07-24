// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {EtherfiCashLaunchPayload} from 'src/etherfi/EtherfiCashLaunchPayload.sol';
import {EtherfiCashOpMainnet} from 'src/etherfi/EtherfiCashOpMainnet.sol';
import {VerifyEtherfiCashLiveScript} from 'scripts/etherfi/VerifyEtherfiCashLive.s.sol';
import {DeployEtherfiCashLaunchPayloadScript} from 'scripts/etherfi/DeployEtherfiCashLaunchPayload.s.sol';

/// @dev Executes the payload EXACTLY as the Owner Safe transaction will: code running at the
/// Owner Safe's address delegatecalls execute(), so address(this) inside the payload/engine is
/// the Safe, matching the roles granted by the instance deployment.
contract SafeDelegateSimulator {
  error DelegatecallFailed();

  function exec(address payload) external {
    (bool ok, ) = payload.delegatecall(abi.encodeCall(AaveV4Payload.execute, ()));
    require(ok, DelegatecallFailed());
  }
}

/// @title EtherfiCashLaunchForkTest
/// @notice Dress rehearsal of the whole two-phase launch on an OP Mainnet fork:
///   1. deploys both payloads with the pinned addresses,
///   2. phase 1: Owner-Safe-context delegatecall of the dormant-config launch payload,
///   3. verifies the DORMANT state field by field,
///   4. phase 2: Owner-Safe-context delegatecall of the activation payload,
///   5. verifies the ACTIVE state field by field.
/// Skips itself unless running against chainid 10 with the instance addresses pinned:
///   forge test --match-path tests/etherfi/EtherfiCashLaunchFork.t.sol --fork-url <op-rpc> -vv
contract EtherfiCashLaunchForkTest is Test {
  function test_fork_fullLaunchRehearsal() public {
    if (block.chainid != 10 || EtherfiCashOpMainnet.CONFIG_ENGINE == address(0)) {
      vm.skip(true);
    }

    // 1. deploy both payloads exactly as the deploy script would (same address resolution)
    DeployEtherfiCashLaunchPayloadScript deployScript = new DeployEtherfiCashLaunchPayloadScript();
    (address payload, address activation) = deployScript.run();

    address ownerSafe = EtherfiCashOpMainnet.OWNER_SAFE;
    vm.etch(ownerSafe, address(new SafeDelegateSimulator()).code);

    // 2. phase 1: dormant configuration
    SafeDelegateSimulator(ownerSafe).exec(payload);

    // 3. verify the dormant state
    vm.setEnv('EXPECT_ACTIVE', 'false');
    uint256 verified = new VerifyEtherfiCashLiveScript().verify();
    assertGt(verified, 0, 'nothing verified');

    // 4. phase 2: activation
    SafeDelegateSimulator(ownerSafe).exec(activation);

    // 5. verify the live state
    vm.setEnv('EXPECT_ACTIVE', 'true');
    verified = new VerifyEtherfiCashLiveScript().verify();
    assertGt(verified, 0, 'nothing verified');
  }
}
