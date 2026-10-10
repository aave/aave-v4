// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PostDeploymentVerificationBase} from 'tests/deployments/fork/PostDeploymentVerificationBase.t.sol';
import {AaveV4DeployAnvil} from 'scripts/deploy/examples/AaveV4DeployAnvil.s.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';

/// @title PostDeploymentVerificationTest
/// @author Aave Labs
/// @notice Integration test that deploys all Aave V4 contracts, writes the JSON deployment report,
///         reads it back, and verifies the parsed report matches on-chain state.
contract PostDeploymentVerificationTest is PostDeploymentVerificationBase, AaveV4DeployAnvil {
  string internal constant FILE_NAME = 'anvil-integration';

  /// @dev Fuzz input struct
  struct FuzzParams {
    address accessManagerAdmin;
    address proxyAdminOwner;
    address hubAdmin;
    address hubConfiguratorAdmin;
    address treasurySpokeOwner;
    address feeSharesMinterOwner;
    address spokeAdmin;
    address spokeConfiguratorAdmin;
    address gatewayOwner;
    address positionManagerOwner;
    bool deployNativeTokenGateway;
    bool useValidNativeWrapper;
    bool deploySignatureGateway;
    bool deployPositionManagers;
    bool grantRoles;
    bytes32 salt;
    uint8 hubCount;
    uint8 spokeCount;
  }

  function setUp() public override(PostDeploymentVerificationBase) {
    _etchCreate2Factory();
    _deployer = makeAddr('deployer');
    PostDeploymentVerificationBase.setUp();
  }

  /// @notice Full deployment with JSON report write + read-back verification.
  function test_jsonReportRoundTrip() public {
    InputUtils.FullDeployInputs memory sanitizedInputs = _loadWarningsAndSanitizeInputs(
      _defaultInputs(),
      _deployer
    );
    _deployWriteReportAndVerify(sanitizedInputs, OUTPUT_DIR, FILE_NAME);
  }

  /// deploy all gateways
  function test_allGateways() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();
    inputs.deployNativeTokenGateway = true;
    inputs.deploySignatureGateway = true;
    _sanitizeAndDeploy(inputs);
  }

  /// deploy only native gateway
  function test_nativeGatewayOnly() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();
    inputs.deployNativeTokenGateway = true;
    inputs.deploySignatureGateway = false;
    _sanitizeAndDeploy(inputs);
  }

  /// deploy only signature gateway
  function test_signatureGatewayOnly() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();
    inputs.deployNativeTokenGateway = false;
    inputs.deploySignatureGateway = true;
    _sanitizeAndDeploy(inputs);
  }

  /// deploy no gateways
  function test_noGateways() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();
    inputs.deployNativeTokenGateway = false;
    inputs.deploySignatureGateway = false;
    _sanitizeAndDeploy(inputs);
  }

  /// deploy with position managers
  function test_withPositionManagers() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();
    inputs.deployPositionManagers = true;
    _sanitizeAndDeploy(inputs);
  }

  /// deploy without position managers
  function test_withoutPositionManagers() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();
    inputs.deployPositionManagers = false;
    _sanitizeAndDeploy(inputs);
  }

  /// deploy with roles
  function test_withRoles() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();
    inputs.grantRoles = true;
    _sanitizeAndDeploy(inputs);
  }

  /// deploy without roles
  function test_withoutRoles() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();
    inputs.grantRoles = false;
    _sanitizeAndDeploy(inputs);
  }

  /// deploy with single hub and single spoke
  function test_singleHubSingleSpoke() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();

    string[] memory hubLabels = new string[](1);
    hubLabels[0] = 'core';
    inputs.hubLabels = hubLabels;

    string[] memory spokeLabels = new string[](1);
    spokeLabels[0] = 'main';
    inputs.spokeLabels = spokeLabels;

    _sanitizeAndDeploy(inputs);
  }

  /// deploy with multiple hubs and multiple spokes
  function test_multipleHubsMultipleSpokes() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();

    string[] memory hubLabels = new string[](3);
    hubLabels[0] = 'core';
    hubLabels[1] = 'prime';
    hubLabels[2] = 'lrt';
    inputs.hubLabels = hubLabels;

    string[] memory spokeLabels = new string[](3);
    spokeLabels[0] = 'main';
    spokeLabels[1] = 'core';
    spokeLabels[2] = 'base';
    inputs.spokeLabels = spokeLabels;

    _sanitizeAndDeploy(inputs);
  }

  /// deploy minimal deployment with no gateways, position managers, or roles
  function test_minimalDeploy() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();
    inputs.deployNativeTokenGateway = false;
    inputs.deploySignatureGateway = false;
    inputs.deployPositionManagers = false;
    inputs.grantRoles = false;
    _sanitizeAndDeploy(inputs);
  }

  /// deploy full deployment with all gateways, position managers, and roles
  function test_fullDeploy() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();
    inputs.deployNativeTokenGateway = true;
    inputs.deploySignatureGateway = true;
    inputs.deployPositionManagers = true;
    inputs.grantRoles = true;
    _sanitizeAndDeploy(inputs);
  }

  /// deploy with position managers and roles but no gateways
  function test_noGatewaysWithRoles() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();
    inputs.deployNativeTokenGateway = false;
    inputs.deploySignatureGateway = false;
    inputs.deployPositionManagers = true;
    inputs.grantRoles = true;
    _sanitizeAndDeploy(inputs);
  }

  /// deploy with gateways but no position managers or roles
  function test_gatewaysWithoutRoles() public {
    InputUtils.FullDeployInputs memory inputs = _defaultInputs();
    inputs.deployNativeTokenGateway = true;
    inputs.deploySignatureGateway = true;
    inputs.deployPositionManagers = false;
    inputs.grantRoles = false;
    _sanitizeAndDeploy(inputs);
  }

  /// forge-config: default.fuzz.runs = 1000
  function testFuzz_postDeploymentCheck(FuzzParams memory params) public {
    params.hubCount = uint8(bound(params.hubCount, 1, 10));
    params.spokeCount = uint8(bound(params.spokeCount, 0, 10));

    string[] memory hubLabels = new string[](params.hubCount);
    for (uint256 i; i < params.hubCount; i++) {
      hubLabels[i] = string.concat('hub', vm.toString(i));
    }

    string[] memory spokeLabels = new string[](params.spokeCount);
    for (uint256 i; i < params.spokeCount; i++) {
      spokeLabels[i] = string.concat('spoke', vm.toString(i));
    }

    InputUtils.FullDeployInputs memory inputs = InputUtils.FullDeployInputs({
      accessManagerAdmin: params.accessManagerAdmin,
      proxyAdminOwner: params.proxyAdminOwner,
      hubAdmin: params.hubAdmin,
      hubConfiguratorAdmin: params.hubConfiguratorAdmin,
      treasurySpokeOwner: params.treasurySpokeOwner,
      feeSharesMinterOwner: params.feeSharesMinterOwner,
      spokeAdmin: params.spokeAdmin,
      spokeConfiguratorAdmin: params.spokeConfiguratorAdmin,
      gatewayOwner: params.gatewayOwner,
      positionManagerOwner: params.positionManagerOwner,
      nativeWrapper: (params.deployNativeTokenGateway && params.useValidNativeWrapper)
        ? weth
        : address(0),
      deployNativeTokenGateway: params.deployNativeTokenGateway,
      deploySignatureGateway: params.deploySignatureGateway,
      deployPositionManagers: params.deployPositionManagers,
      grantRoles: params.grantRoles,
      hubLabels: hubLabels,
      spokeLabels: spokeLabels,
      spokeMaxReservesLimits: new uint16[](0),
      salt: params.salt
    });

    // Invalid input combinations revert during deployment
    if (_shouldExpectRevert(inputs)) {
      vm.expectRevert();
      this.externalSanitizeAndDeploy(inputs);
    } else {
      _sanitizeAndDeploy(inputs);
    }
  }

  /// @dev External entry point so test can expect reverts for the fuzz test
  function externalSanitizeAndDeploy(InputUtils.FullDeployInputs memory rawInputs) external {
    _sanitizeAndDeploy(rawInputs);
  }

  function _shouldExpectRevert(
    InputUtils.FullDeployInputs memory inputs
  ) internal pure returns (bool) {
    if (inputs.deployNativeTokenGateway && inputs.nativeWrapper == address(0)) return true;
    return false;
  }

  /// default inputs for the base case
  function _defaultInputs() internal returns (InputUtils.FullDeployInputs memory inputs) {
    string[] memory hubLabels = new string[](2);
    hubLabels[0] = 'core';
    hubLabels[1] = 'prime';

    string[] memory spokeLabels = new string[](2);
    spokeLabels[0] = 'mainnet';
    spokeLabels[1] = 'lrt';

    inputs = InputUtils.FullDeployInputs({
      accessManagerAdmin: makeAddr('accessManagerAdmin'),
      proxyAdminOwner: makeAddr('proxyAdminOwner'),
      hubAdmin: makeAddr('hubAdmin'),
      hubConfiguratorAdmin: makeAddr('hubConfiguratorAdmin'),
      treasurySpokeOwner: makeAddr('treasurySpokeOwner'),
      feeSharesMinterOwner: makeAddr('feeSharesMinterOwner'),
      spokeAdmin: makeAddr('spokeAdmin'),
      spokeConfiguratorAdmin: makeAddr('spokeConfiguratorAdmin'),
      gatewayOwner: makeAddr('gatewayOwner'),
      positionManagerOwner: makeAddr('positionManagerOwner'),
      nativeWrapper: weth,
      deployNativeTokenGateway: true,
      deploySignatureGateway: true,
      deployPositionManagers: true,
      grantRoles: true,
      hubLabels: hubLabels,
      spokeLabels: spokeLabels,
      spokeMaxReservesLimits: new uint16[](0),
      salt: keccak256('test-salt')
    });
  }

  function _sanitizeAndDeploy(InputUtils.FullDeployInputs memory rawInputs) internal {
    InputUtils.FullDeployInputs memory sanitizedInputs = _loadWarningsAndSanitizeInputs(
      rawInputs,
      _deployer
    );
    _deployWriteReportAndVerify(sanitizedInputs);
  }
}
