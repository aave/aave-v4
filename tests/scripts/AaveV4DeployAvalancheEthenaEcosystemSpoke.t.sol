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

import {AaveV4DeployAvalancheEthenaEcosystemSpoke} from 'scripts/deploy/AaveV4DeployCorrelatedSpoke.s.sol';

/// @dev Run with FOUNDRY_LIBRARIES linking LiquidationLogic to the Avalanche instance
///      (0x88df535473c5adf1f57789734a05e555f7deb8db), otherwise the bytecode check fails.
contract AaveV4DeployAvalancheEthenaEcosystemSpokeTest is Test {
  struct ImmutableReference {
    uint256 length;
    uint256 start;
  }

  // https://snowscan.xyz/address/0x56F74D6BC5F51dA3ba0D3F715A67cD7D15358AD4
  address internal constant AVALANCHE_MAIN_SPOKE_IMPL = 0x56F74D6BC5F51dA3ba0D3F715A67cD7D15358AD4;

  AaveV4DeployAvalancheEthenaEcosystemSpoke internal _script;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('avalanche'), 97437780);
    _script = new AaveV4DeployAvalancheEthenaEcosystemSpoke();
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
    // AaveV4AvalanchePositionManagers: Giver, Taker, Config, Native Token Gateway and Signature Gateway
    assertFalse(spoke.isPositionManagerActive(0x50c4C40aB6BaE46B372a251BEacE388439aa96b4));
    assertFalse(spoke.isPositionManagerActive(0x5A5A711560eb9293Ef6F4bc33CD8589b4A603D10));
    assertFalse(spoke.isPositionManagerActive(0x50BE00C5EbF6CC230B8970f4205Cd0B5A70EaEB1));
    assertFalse(spoke.isPositionManagerActive(0xE4C7183A5f22c365140F41d733d8A8baD5A1a6bA));
    assertFalse(spoke.isPositionManagerActive(0x6E3B91A951DA9b515a5E98F0c7D210a697382e7F));
  }

  function test_run_proxyAdminOwnedBySecurityCouncil() public {
    BatchReports.SpokeInstanceBatchReport memory report = _script.run();

    address owner = Ownable(ProxyHelper.getProxyAdmin(report.spokeProxy)).owner();
    assertEq(owner, _script.PROTOCOL_SECURITY_COUNCIL());
  }

  function test_run_implementationMatchesAvalancheMainSpoke() public {
    BatchReports.SpokeInstanceBatchReport memory report = _script.run();

    bytes memory deployed = report.spokeImplementation.code;
    bytes memory live = AVALANCHE_MAIN_SPOKE_IMPL.code;
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
  // Operator must avoid running the script twice, there is no on-chain safety check.
  function test_run_repeatCallsProduceDistinctSpokes() public {
    BatchReports.SpokeInstanceBatchReport memory a = _script.run();
    BatchReports.SpokeInstanceBatchReport memory b = _script.run();
    assertNotEq(a.spokeProxy, b.spokeProxy);
    assertNotEq(a.aaveOracle, b.aaveOracle);
  }

  function test_run_revertsOffAvalanche_fuzz(uint64 wrongChainId) public {
    vm.assume(wrongChainId != 43114);
    vm.chainId(wrongChainId);

    vm.expectRevert('chain id mismatch');
    _script.run();
  }

  function test_constantsMatchAddressBook() public view {
    assertEq(_script.ACCESS_MANAGER(), 0xe069096bDAfF9bAD15b2f1079EaF0f1685a24522);
    assertEq(_script.PROTOCOL_SECURITY_COUNCIL(), 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9);
  }

  function test_spokeSaltMatchesOrchestrationFormula_fuzz(address deployer) public view {
    bytes32 orchestrationSalt = keccak256('AAVE_V4');
    bytes32 userSalt = keccak256(bytes('chain 43114_version 1'));
    bytes32 expectedRoot = bytes32(bytes20(deployer)) |
      (keccak256(abi.encode(orchestrationSalt, userSalt)) >> 160);
    bytes32 expected = keccak256(abi.encode(expectedRoot, 'spoke', 'ETHENA_ECOSYSTEM_SPOKE'));

    assertEq(_script.spokeSalt(deployer), expected);
  }
}
