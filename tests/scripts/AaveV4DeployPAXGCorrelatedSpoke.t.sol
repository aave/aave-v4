// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeInstance} from 'src/deployments/utils/interfaces/ISpokeInstance.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';

import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';

import {AaveV4DeployPAXGCorrelatedSpoke} from 'scripts/deploy/AaveV4DeployCorrelatedSpoke.s.sol';

contract AaveV4DeployPAXGCorrelatedSpokeTest is Test {
  AaveV4DeployPAXGCorrelatedSpoke internal _script;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 26254077);
    _script = new AaveV4DeployPAXGCorrelatedSpoke();
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

  function test_run_ownershipMatchesPaxgGoldSpoke() public {
    address existing = 0xAD75cE6354f87F3135cE10621d385d8D1e2562C2;
    BatchReports.SpokeInstanceBatchReport memory report = _script.run();
    assertEq(
      Ownable(ProxyHelper.getProxyAdmin(report.spokeProxy)).owner(),
      Ownable(ProxyHelper.getProxyAdmin(existing)).owner()
    );
    assertEq(IAccessManaged(report.spokeProxy).authority(), IAccessManaged(existing).authority());
    assertEq(
      ISpoke(report.spokeProxy).MAX_USER_RESERVES_LIMIT(),
      ISpoke(existing).MAX_USER_RESERVES_LIMIT()
    );
    assertEq(
      IPriceOracle(report.aaveOracle).decimals(),
      IPriceOracle(ISpoke(existing).ORACLE()).decimals()
    );
    assertEq(ProxyHelper.getImplementation(report.spokeProxy), report.spokeImplementation);
    assertEq(ProxyHelper.getProxyInitializedVersion(report.spokeProxy), 1);
    assertEq(ISpoke(report.spokeProxy).getReserveCount(), 0);
  }

  function test_run_positionManagersStartInactive() public {
    BatchReports.SpokeInstanceBatchReport memory report = _script.run();
    ISpoke spoke = ISpoke(report.spokeProxy);
    assertEq(spoke.getReserveCount(), 0);
    // AaveV4EthereumPositionManagers: Giver, Taker, Config, Native Gateway, Signature Gateway.
    assertFalse(spoke.isPositionManagerActive(0x17A54b8d6D9C68e7fa1C7112AC998EA1BA51d11e));
    assertFalse(spoke.isPositionManagerActive(0x6c044c0D3801499bCAbfAd458B70880bc518e9F7));
    assertFalse(spoke.isPositionManagerActive(0x51305839CE822a7b4b12AA7D86eA7005052d575c));
    assertFalse(spoke.isPositionManagerActive(0xe68ab4F90Fe026B9873F5F276eD2d7efBbbE42Be));
    assertFalse(spoke.isPositionManagerActive(0xfbC184337Dc6595D8bf62968Bda46e7De7AF9c3d));
  }

  function test_run_proxyAndImplementationCannotBeReinitialized() public {
    BatchReports.SpokeInstanceBatchReport memory report = _script.run();
    address authority = _script.ACCESS_MANAGER();
    vm.expectRevert(bytes4(keccak256('InvalidInitialization()')));
    ISpokeInstance(report.spokeProxy).initialize(authority);
    vm.expectRevert(bytes4(keccak256('InvalidInitialization()')));
    ISpokeInstance(report.spokeImplementation).initialize(authority);
  }

  function test_run_proxyAdminOwnedBySecurityCouncil() public {
    BatchReports.SpokeInstanceBatchReport memory report = _script.run();

    address owner = Ownable(ProxyHelper.getProxyAdmin(report.spokeProxy)).owner();
    assertEq(owner, _script.PROTOCOL_SECURITY_COUNCIL());
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
    assertEq(_script.PROTOCOL_SECURITY_COUNCIL(), 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9);
  }

  function test_spokeSaltMatchesOrchestrationFormula_fuzz(address deployer) public view {
    bytes32 orchestrationSalt = keccak256('AAVE_V4');
    bytes32 userSalt = keccak256(bytes('chain 1_version 1'));
    bytes32 expectedRoot = bytes32(bytes20(deployer)) |
      (keccak256(abi.encode(orchestrationSalt, userSalt)) >> 160);
    bytes32 expected = keccak256(abi.encode(expectedRoot, 'spoke', 'PAXG_CORRELATED_SPOKE'));

    assertEq(_script.spokeSalt(deployer), expected);
  }
}
