// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';

import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';

import {AaveV4DeployArcMapleSpoke} from 'scripts/deploy/AaveV4DeployCorrelatedSpoke.s.sol';

/// @dev Run with FOUNDRY_LIBRARIES linking LiquidationLogic to the Arc instance
///      (0x818E84198224535FAeaEc1b583d3Ff6b812A5AF3), otherwise the bytecode check fails.
contract AaveV4DeployArcMapleSpokeTest is Test {
  struct ImmutableReference {
    uint256 length;
    uint256 start;
  }

  // https://explorer.arc.io/address/0xf76b49f5911ca3838a469563c0ffb07c8f91ba79
  address internal constant ARC_MAIN_SPOKE_IMPL = 0xf76b49F5911Ca3838a469563c0ffB07c8f91ba79;

  AaveV4DeployArcMapleSpoke internal _script;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('arc'), 23686000);
    _script = new AaveV4DeployArcMapleSpoke();
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

  function test_run_spokeIsEmpty() public {
    BatchReports.SpokeInstanceBatchReport memory report = _script.run();
    ISpoke spoke = ISpoke(report.spokeProxy);

    assertEq(spoke.getReserveCount(), 0);
    // AaveV4ArcPositionManagers: Giver, Taker, Config and Signature Gateway
    assertFalse(spoke.isPositionManagerActive(0x01Da80Eef3004ebbF90b7637B1De7fF30fBc7cf1));
    assertFalse(spoke.isPositionManagerActive(0xe9fae1C386c6f45B1fb3C3Ef01aDE424DAd4bCcF));
    assertFalse(spoke.isPositionManagerActive(0xa5Aa65Ae1c830d2ae10853CeEa42AE653adB3312));
    assertFalse(spoke.isPositionManagerActive(0x0d36A4a21119BBBDe559d59002254171D976289f));
  }

  function test_run_proxyAdminOwnedBySecurityCouncil() public {
    BatchReports.SpokeInstanceBatchReport memory report = _script.run();

    address owner = Ownable(ProxyHelper.getProxyAdmin(report.spokeProxy)).owner();
    assertEq(owner, _script.PROTOCOL_SECURITY_COUNCIL());
  }

  function test_run_implementationMatchesArcMainSpoke() public {
    BatchReports.SpokeInstanceBatchReport memory report = _script.run();

    bytes memory deployed = report.spokeImplementation.code;
    bytes memory live = ARC_MAIN_SPOKE_IMPL.code;
    assertEq(deployed.length, live.length);

    // ORACLE, MAX_USER_RESERVES_LIMIT and the EIP712 cached values
    string memory artifact = vm.readFile('out/SpokeInstance.sol/SpokeInstance.json');
    string memory refsPath = '.deployedBytecode.immutableReferences';
    string[] memory ids = vm.parseJsonKeys(artifact, refsPath);
    assertGt(ids.length, 0);
    for (uint256 i; i < ids.length; ++i) {
      ImmutableReference[] memory refs = abi.decode(
        vm.parseJson(artifact, string.concat(refsPath, '.', ids[i])),
        (ImmutableReference[])
      );
      for (uint256 j; j < refs.length; ++j) {
        for (uint256 k; k < refs[j].length; ++k) {
          deployed[refs[j].start + k] = 0;
          live[refs[j].start + k] = 0;
        }
      }
    }

    assertEq(keccak256(deployed), keccak256(live));
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

  function test_run_revertsOffArc_fuzz(uint64 wrongChainId) public {
    vm.assume(wrongChainId != 5042);
    vm.chainId(wrongChainId);

    vm.expectRevert('chain id mismatch');
    _script.run();
  }

  function test_constantsMatchAddressBook() public view {
    assertEq(_script.ACCESS_MANAGER(), 0x24761DB265998ba1D38E8a29031cF72C2CeF3A7D);
    assertEq(_script.PROTOCOL_SECURITY_COUNCIL(), 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9);
  }

  function test_spokeSaltMatchesOrchestrationFormula_fuzz(address deployer) public view {
    bytes32 orchestrationSalt = keccak256('AAVE_V4');
    bytes32 userSalt = keccak256(bytes('chain 5042_version 1'));
    bytes32 expectedRoot = bytes32(bytes20(deployer)) |
      (keccak256(abi.encode(orchestrationSalt, userSalt)) >> 160);
    bytes32 expected = keccak256(abi.encode(expectedRoot, 'spoke', 'MAPLE_SPOKE'));

    assertEq(_script.spokeSalt(deployer), expected);
  }
}
