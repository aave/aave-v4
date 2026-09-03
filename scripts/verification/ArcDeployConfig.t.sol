// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PostDeploymentVerificationBase} from 'tests/deployments/fork/PostDeploymentVerificationBase.t.sol';
import {AaveV4DeployArc} from 'scripts/deploy/AaveV4DeployArc.s.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';

/// @title ArcDeployConfigTest
/// @author Aave Labs
/// @notice Checks that scripts/config/arc.json parses into the intended deploy inputs, and that a full
///         deployment driven by those inputs grants every role and ownership as configured.
contract ArcDeployConfigTest is PostDeploymentVerificationBase, AaveV4DeployArc {
  address internal constant SECURITY_COUNCIL = 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9;
  address internal constant SECURITY_COUNCIL_EXECUTOR = 0x8e79b0541122d3822eC93082cEB1ab03EDBc1Fd5;
  uint256 internal constant ARC_CHAIN_ID = 5042;

  function setUp() public override(PostDeploymentVerificationBase) {
    _etchCreate2Factory();
    PostDeploymentVerificationBase.setUp();
  }

  function test_expectedChainId() public pure {
    assertEq(_expectedChainId(), ARC_CHAIN_ID);
  }

  function test_deployInputs() public view {
    InputUtils.FullDeployInputs memory inputs = _getDeployInputs();

    assertEq(inputs.accessManagerAdmin, SECURITY_COUNCIL, 'accessManagerAdmin');
    assertEq(inputs.proxyAdminOwner, SECURITY_COUNCIL, 'proxyAdminOwner');
    assertEq(inputs.hubAdmin, SECURITY_COUNCIL, 'hubAdmin');
    assertEq(inputs.treasurySpokeOwner, SECURITY_COUNCIL, 'treasurySpokeOwner');
    assertEq(inputs.spokeAdmin, SECURITY_COUNCIL, 'spokeAdmin');
    assertEq(inputs.gatewayOwner, SECURITY_COUNCIL, 'gatewayOwner');
    assertEq(inputs.positionManagerOwner, SECURITY_COUNCIL, 'positionManagerOwner');

    // the domain admin roles end up with the executor, which delegatecalls the config engine
    assertEq(inputs.hubConfiguratorAdmin, SECURITY_COUNCIL_EXECUTOR, 'hubConfiguratorAdmin');
    assertEq(inputs.spokeConfiguratorAdmin, SECURITY_COUNCIL_EXECUTOR, 'spokeConfiguratorAdmin');

    // Arc pays gas in USDC, so there is no native wrapper to gateway
    assertEq(inputs.nativeWrapper, address(0), 'nativeWrapper');
    assertFalse(inputs.deployNativeTokenGateway, 'deployNativeTokenGateway');
    assertTrue(inputs.deploySignatureGateway, 'deploySignatureGateway');
    assertTrue(inputs.deployPositionManagers, 'deployPositionManagers');
    // roles are granted by the configuration and handover scripts, not at deploy time
    assertFalse(inputs.grantRoles, 'grantRoles');

    assertEq(inputs.hubLabels.length, 1, 'hub count');
    assertEq(inputs.hubLabels[0], 'core', 'hub label');
    assertEq(inputs.spokeLabels.length, 2, 'spoke count');
    assertEq(inputs.spokeLabels[0], 'main', 'first spoke label');
    assertEq(inputs.spokeLabels[1], 'forex', 'second spoke label');
    assertEq(inputs.spokeMaxReservesLimits.length, 0, 'spoke max reserves limits');
    assertTrue(inputs.salt != bytes32(0), 'salt');
  }

  function test_deployWithArcConfig() public {
    InputUtils.FullDeployInputs memory sanitizedInputs = _loadWarningsAndSanitizeInputs(
      _getDeployInputs(),
      _deployer
    );

    // the deployer holds no ownership: only the AccessManager admin role is deferred to it
    assertEq(sanitizedInputs.proxyAdminOwner, SECURITY_COUNCIL, 'proxyAdminOwner');
    assertEq(sanitizedInputs.treasurySpokeOwner, SECURITY_COUNCIL, 'treasurySpokeOwner');
    // the managers are deployer-owned during configuration, which needs onlyOwner access to
    // registerSpoke; the handover moves them to the Council
    assertEq(sanitizedInputs.gatewayOwner, _deployer, 'gatewayOwner');
    assertEq(sanitizedInputs.positionManagerOwner, _deployer, 'positionManagerOwner');

    _deployWriteReportAndVerify(sanitizedInputs);
  }

  /// @dev Tests are non-interactive.
  function _executeUserPrompt() internal override {}
}
