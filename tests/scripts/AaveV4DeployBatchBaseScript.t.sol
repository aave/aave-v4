// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {Constants} from 'tests/Constants.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';

contract AaveV4DeployBatchBaseScriptHarness is AaveV4DeployBatchBaseScript {
  // use harness to expose internal functions for testing

  constructor() AaveV4DeployBatchBaseScript('out.json') {}

  function loadWarningsAndSanitizeInputs(
    InputUtils.FullDeployInputs memory inputs,
    address deployer
  ) public returns (InputUtils.FullDeployInputs memory) {
    return _loadWarningsAndSanitizeInputs(inputs, deployer);
  }

  function logWarning(string memory warning) public {
    _logWarning(warning);
  }

  function _getDeployInputs() internal pure override returns (InputUtils.FullDeployInputs memory) {
    revert('not implemented');
  }

  function _expectedChainId() internal pure override returns (uint256) {
    return 31337;
  }

  function expectedChainId() public pure returns (uint256) {
    return _expectedChainId();
  }

  function validateChainId() public view {
    _validateChainId();
  }

  function _executeUserPrompt() internal override {}
}

contract AaveV4DeployBatchBaseScriptTest is Test {
  AaveV4DeployBatchBaseScriptHarness internal _harness;
  InputUtils.FullDeployInputs internal _inputs;
  address internal _deployer;

  function setUp() public {
    _harness = new AaveV4DeployBatchBaseScriptHarness();

    _inputs = InputUtils.FullDeployInputs({
      accessManagerAdmin: makeAddr('accessManagerAdmin'),
      hubAdmin: makeAddr('hubAdmin'),
      hubConfiguratorAdmin: makeAddr('hubConfiguratorAdmin'),
      treasurySpokeOwner: makeAddr('treasurySpokeOwner'),
      spokeAdmin: makeAddr('spokeAdmin'),
      hubProxyAdminOwner: makeAddr('hubProxyAdminOwner'),
      spokeProxyAdminOwner: makeAddr('spokeProxyAdminOwner'),
      spokeConfiguratorAdmin: makeAddr('spokeConfiguratorAdmin'),
      gatewayOwner: makeAddr('gatewayOwner'),
      positionManagerOwner: makeAddr('positionManagerOwner'),
      nativeWrapper: address(new WETH9()),
      deployNativeTokenGateway: true,
      deploySignatureGateway: true,
      deployPositionManagers: true,
      grantRoles: true,
      hubLabels: _toArray('hub1', 'hub2', 'hub3'),
      spokeLabels: _toArray('spoke1', 'spoke2', 'spoke3'),
      spokeMaxReservesLimits: _defaultSpokeMaxReservesLimits(3),
      salt: bytes32(0)
    });

    _deployer = makeAddr('deployer');
  }

  function test_validateChainId_revertsOnMismatch(uint64 chainId) public {
    vm.assume(chainId != _harness.expectedChainId());

    vm.chainId(chainId);
    vm.expectRevert('chain id mismatch');
    _harness.validateChainId();
  }

  function test_loadWarningsAndSanitizeInputs() public {
    InputUtils.FullDeployInputs memory expected = _inputs;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _inputs,
      _deployer
    );
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroAccessManagerAdmin_fuzz(
    bool grantRoles
  ) public {
    _inputs.accessManagerAdmin = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    if (grantRoles) {
      expected.accessManagerAdmin = _deployer;
    } else {
      expected.treasurySpokeOwner = _deployer;
      expected.hubProxyAdminOwner = _deployer;
      expected.spokeProxyAdminOwner = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroHubAdmin_fuzz(bool grantRoles) public {
    _inputs.hubAdmin = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    if (grantRoles) {
      expected.hubAdmin = _deployer;
    } else {
      // when grantRoles=false, treasurySpokeOwner and spokeProxyAdminOwner always default to deployer
      expected.treasurySpokeOwner = _deployer;
      expected.hubProxyAdminOwner = _deployer;
      expected.spokeProxyAdminOwner = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroSpokeAdmin_fuzz(bool grantRoles) public {
    _inputs.spokeAdmin = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    if (grantRoles) {
      expected.spokeAdmin = _deployer;
    } else {
      expected.treasurySpokeOwner = _deployer;
      expected.hubProxyAdminOwner = _deployer;
      expected.spokeProxyAdminOwner = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroHubConfiguratorAdmin_fuzz(
    bool grantRoles
  ) public {
    _inputs.hubConfiguratorAdmin = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    if (grantRoles) {
      expected.hubConfiguratorAdmin = _deployer;
    } else {
      expected.treasurySpokeOwner = _deployer;
      expected.hubProxyAdminOwner = _deployer;
      expected.spokeProxyAdminOwner = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroSpokeConfiguratorAdmin_fuzz(
    bool grantRoles
  ) public {
    _inputs.spokeConfiguratorAdmin = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    if (grantRoles) {
      expected.spokeConfiguratorAdmin = _deployer;
    } else {
      expected.treasurySpokeOwner = _deployer;
      expected.hubProxyAdminOwner = _deployer;
      expected.spokeProxyAdminOwner = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroHubProxyAdminOwner_fuzz(
    bool grantRoles
  ) public {
    _inputs.hubProxyAdminOwner = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _inputs,
      _deployer
    );

    InputUtils.FullDeployInputs memory expected = _inputs;
    // hubProxyAdminOwner always defaults to deployer (in both grantRoles branches)
    expected.hubProxyAdminOwner = _deployer;
    if (!grantRoles) {
      expected.treasurySpokeOwner = _deployer;
      expected.hubProxyAdminOwner = _deployer;
      expected.spokeProxyAdminOwner = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroSpokeProxyAdminOwner_fuzz(
    bool grantRoles
  ) public {
    _inputs.spokeProxyAdminOwner = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _inputs,
      _deployer
    );

    InputUtils.FullDeployInputs memory expected = _inputs;
    // spokeProxyAdminOwner always defaults to deployer (in both grantRoles branches)
    expected.spokeProxyAdminOwner = _deployer;
    if (!grantRoles) {
      expected.treasurySpokeOwner = _deployer;
      expected.hubProxyAdminOwner = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroTreasurySpokeOwner_fuzz(
    bool grantRoles
  ) public {
    _inputs.treasurySpokeOwner = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    // treasurySpokeOwner always defaults to deployer (in both grantRoles branches)
    expected.treasurySpokeOwner = _deployer;
    if (!grantRoles) {
      expected.hubProxyAdminOwner = _deployer;
      expected.spokeProxyAdminOwner = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroGatewayOwner_fuzz(bool grantRoles) public {
    _inputs.gatewayOwner = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    expected.gatewayOwner = _deployer;
    if (!grantRoles) {
      expected.treasurySpokeOwner = _deployer;
      expected.hubProxyAdminOwner = _deployer;
      expected.spokeProxyAdminOwner = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroPositionManagerOwner_fuzz(
    bool grantRoles
  ) public {
    _inputs.positionManagerOwner = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    expected.positionManagerOwner = _deployer;
    if (!grantRoles) {
      expected.treasurySpokeOwner = _deployer;
      expected.hubProxyAdminOwner = _deployer;
      expected.spokeProxyAdminOwner = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroNativeWrapper_fuzz(bool grantRoles) public {
    _inputs.nativeWrapper = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    expected.nativeWrapper = address(0);
    if (!grantRoles) {
      expected.treasurySpokeOwner = _deployer;
      expected.hubProxyAdminOwner = _deployer;
      expected.spokeProxyAdminOwner = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_revertsWith_duplicateHubLabel() public {
    _inputs.hubLabels = ['hub1', 'hub2', 'hub1'];
    vm.expectRevert('duplicate hub label: hub1');
    _harness.loadWarningsAndSanitizeInputs(_inputs, _deployer);
  }

  function test_loadWarningsAndSanitizeInputs_revertsWith_duplicateSpokeLabel() public {
    _inputs.spokeLabels = ['spoke1', 'spoke1'];
    _inputs.spokeMaxReservesLimits = _defaultSpokeMaxReservesLimits(2);

    vm.expectRevert('duplicate spoke label: spoke1');
    _harness.loadWarningsAndSanitizeInputs(_inputs, _deployer);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroSalt() public {
    _inputs.salt = bytes32(0);
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    assertEq(sanitized, expected);
  }

  function assertEq(
    InputUtils.FullDeployInputs memory a,
    InputUtils.FullDeployInputs memory b
  ) public pure {
    assertEq(a.accessManagerAdmin, b.accessManagerAdmin, 'access manager admin');
    assertEq(a.hubAdmin, b.hubAdmin, 'hub admin');
    assertEq(a.hubConfiguratorAdmin, b.hubConfiguratorAdmin, 'hub configurator admin');
    assertEq(a.treasurySpokeOwner, b.treasurySpokeOwner, 'treasury spoke owner');
    assertEq(a.hubProxyAdminOwner, b.hubProxyAdminOwner, 'hub proxy admin owner');
    assertEq(a.spokeProxyAdminOwner, b.spokeProxyAdminOwner, 'spoke proxy admin owner');
    assertEq(a.spokeConfiguratorAdmin, b.spokeConfiguratorAdmin, 'spoke configurator admin');
    assertEq(a.spokeAdmin, b.spokeAdmin, 'spoke admin');
    assertEq(a.gatewayOwner, b.gatewayOwner, 'gateway owner');
    assertEq(a.positionManagerOwner, b.positionManagerOwner, 'position manager owner');
    assertEq(a.nativeWrapper, b.nativeWrapper, 'native wrapper');
    assertEq(a.deployNativeTokenGateway, b.deployNativeTokenGateway, 'deploy native token gateway');
    assertEq(a.deploySignatureGateway, b.deploySignatureGateway, 'deploy signature gateway');
    assertEq(a.deployPositionManagers, b.deployPositionManagers, 'deploy position managers');
    assertEq(a.grantRoles, b.grantRoles, 'grant roles');
    assertEq(a.hubLabels, b.hubLabels, 'hub labels');
    assertEq(a.spokeLabels, b.spokeLabels, 'spoke labels');
    assertEq(a.salt, b.salt, 'salt');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function _defaultSpokeMaxReservesLimits(
    uint256 count
  ) internal pure returns (uint16[] memory limits) {
    limits = new uint16[](count);
    for (uint256 i; i < count; i++) {
      limits[i] = Constants.MAX_ALLOWED_USER_RESERVES_LIMIT;
    }
  }

  function _toArray(
    string memory a,
    string memory b,
    string memory c
  ) internal pure returns (string[] memory arr) {
    arr = new string[](3);
    arr[0] = a;
    arr[1] = b;
    arr[2] = c;
  }
}
