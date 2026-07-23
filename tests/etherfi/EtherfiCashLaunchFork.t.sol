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
/// @notice Dress rehearsal of the whole launch on an OP Mainnet fork:
///   1. deploys the payload with the pinned addresses,
///   2. executes it in the Owner Safe's context (delegatecall, real roles, real instance),
///   3. verifies the resulting hub/spoke state field by field (VerifyEtherfiCashLive).
/// Skips itself unless running against chainid 10 with the instance addresses pinned:
///   forge test --match-path tests/etherfi/EtherfiCashLaunchFork.t.sol --fork-url <op-rpc> -vv
contract EtherfiCashLaunchForkTest is Test {
  function test_fork_fullLaunchRehearsal() public {
    if (block.chainid != 10 || EtherfiCashOpMainnet.CONFIG_ENGINE == address(0)) {
      vm.skip(true);
    }

    // 1. deploy the payload exactly as the deploy script would (same address resolution)
    DeployEtherfiCashLaunchPayloadScript deployScript = new DeployEtherfiCashLaunchPayloadScript();
    address payload = deployScript.run();

    // 2. execute in the Owner Safe's context
    address ownerSafe = EtherfiCashOpMainnet.OWNER_SAFE;
    vm.etch(ownerSafe, address(new SafeDelegateSimulator()).code);
    SafeDelegateSimulator(ownerSafe).exec(payload);

    // 3. field-by-field verification of the live state
    uint256 verified = new VerifyEtherfiCashLiveScript().verify();
    assertGt(verified, 0, 'nothing verified');
  }
}
