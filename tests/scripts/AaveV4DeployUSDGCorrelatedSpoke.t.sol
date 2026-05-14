// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';

import {AaveV4DeployUSDGCorrelatedSpoke} from 'scripts/deploy/AaveV4DeployUSDGCorrelatedSpoke.s.sol';

contract AaveV4DeployUSDGCorrelatedSpokeTest is Test {
  AaveV4DeployUSDGCorrelatedSpoke internal _script;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 25092080);
    _script = new AaveV4DeployUSDGCorrelatedSpoke();
  }

  function test_run_deploysSpoke() public {
    BatchReports.SpokeInstanceBatchReport memory report = _script.run();

    assertGt(report.spokeProxy.code.length, 0);
    assertGt(report.spokeImplementation.code.length, 0);
    assertGt(report.aaveOracle.code.length, 0);

    assertEq(IAccessManaged(report.spokeProxy).authority(), _script.ACCESS_MANAGER());
    assertEq(ISpoke(report.spokeProxy).ORACLE(), report.aaveOracle);
    assertEq(IPriceOracle(report.aaveOracle).spoke(), report.spokeProxy);
    assertEq(
      uint256(IPriceOracle(report.aaveOracle).decimals()),
      uint256(DeployConstants.ORACLE_DECIMALS)
    );
    assertEq(
      uint256(ISpoke(report.spokeProxy).MAX_USER_RESERVES_LIMIT()),
      uint256(DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT)
    );
  }

  // Same salt does NOT collide: each batch deploys a fresh CREATE-allocated AaveOracle whose
  // address is in SpokeInstance's init code, so the CREATE2 spoke address differs across calls.
  // Operator must avoid running the script twice — no on-chain safety check.
  function test_run_repeatCallsProduceDistinctSpokes() public {
    BatchReports.SpokeInstanceBatchReport memory a = _script.run();
    BatchReports.SpokeInstanceBatchReport memory b = _script.run();
    assertNotEq(a.spokeProxy, b.spokeProxy);
    assertNotEq(a.aaveOracle, b.aaveOracle);
  }

  function test_run_revertsOffMainnet_fuzz(uint64 wrongChainId) public {
    vm.assume(wrongChainId != 1);
    vm.chainId(wrongChainId);

    vm.expectRevert('chain id mismatch');
    _script.run();
  }

  function test_constantsMatchAddressBook() public view {
    assertEq(_script.ACCESS_MANAGER(), 0x08aE3BE30958cDd1847ec58fFfd4C451a87fDF01);
    assertEq(_script.EXECUTOR_LVL_1(), 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A);
  }

  function test_spokeSaltMatchesOrchestrationFormula_fuzz(address deployer) public view {
    bytes32 orchestrationSalt = keccak256('AAVE_V4');
    bytes32 userSalt = keccak256(bytes('chain 1_version 1'));
    bytes32 expectedRoot = bytes32(bytes20(deployer)) |
      (keccak256(abi.encode(orchestrationSalt, userSalt)) >> 160);
    bytes32 expected = keccak256(abi.encode(expectedRoot, 'spoke', 'USDG_CORRELATED_SPOKE'));

    assertEq(_script.spokeSalt(deployer), expected);
  }
}
