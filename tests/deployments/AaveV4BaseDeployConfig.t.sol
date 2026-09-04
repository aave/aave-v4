// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PostDeploymentVerificationBase} from 'tests/deployments/fork/PostDeploymentVerificationBase.t.sol';
import {AaveV4DeployBase} from 'scripts/deploy/AaveV4DeployBase.s.sol';
import {AaveV4BaseConfigEngine} from 'scripts/config/AaveV4BaseConfigEngine.sol';
import {AaveV4BaseConfigInputs} from 'scripts/config/AaveV4BaseConfigInputs.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';

/// @title AaveV4BaseDeployConfigTest
/// @author Aave Labs
/// @notice Checks that config/base.json and config/base-config.json parse into the intended inputs,
///         and that a full deployment driven by those inputs sets every ownership as configured.
contract AaveV4BaseDeployConfigTest is PostDeploymentVerificationBase, AaveV4DeployBase {
  /// @dev `MiscEthereum.V4_SECURITY_COUNCIL`, which is the same address on Ethereum, Avalanche and
  ///      Arc and is expected to be the same on Base.
  address internal constant V4_SECURITY_COUNCIL = 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9;
  /// @dev `GovernanceV3Base.EXECUTOR_LVL_1`.
  address internal constant GOVERNANCE_EXECUTOR = 0x9390B1735def18560c509E2d0bc090E9d6BA257a;
  address internal constant WETH = 0x4200000000000000000000000000000000000006;
  uint256 internal constant BASE_CHAIN_ID = 8453;

  function setUp() public override(PostDeploymentVerificationBase) {
    _etchCreate2Factory();
    PostDeploymentVerificationBase.setUp();
  }

  function test_expectedChainId() public pure {
    assertEq(_expectedChainId(), BASE_CHAIN_ID);
  }

  /// @dev The Security Council owns the market outright. The V4 Security Council executor is not
  ///      deployed on Base yet, so both configurator domain admin fields are still the placeholder:
  ///      update these assertions together with config/base.json once it is.
  function test_deployInputs() public view {
    InputUtils.FullDeployInputs memory inputs = _getDeployInputs();

    assertEq(inputs.accessManagerAdmin, V4_SECURITY_COUNCIL, 'accessManagerAdmin');
    assertEq(inputs.proxyAdminOwner, V4_SECURITY_COUNCIL, 'proxyAdminOwner');
    assertEq(inputs.treasurySpokeOwner, V4_SECURITY_COUNCIL, 'treasurySpokeOwner');
    assertEq(inputs.gatewayOwner, V4_SECURITY_COUNCIL, 'gatewayOwner');
    assertEq(inputs.positionManagerOwner, V4_SECURITY_COUNCIL, 'positionManagerOwner');

    // the domain admin roles end up with whoever executes the Council's configuration payloads,
    // which is not the Safe that owns the market
    assertEq(inputs.hubConfiguratorAdmin, PLACEHOLDER_ADDRESS, 'hubConfiguratorAdmin');
    assertEq(inputs.spokeConfiguratorAdmin, PLACEHOLDER_ADDRESS, 'spokeConfiguratorAdmin');

    // roles 100-103 and 300-302 are left unheld, as on the live Ethereum and Avalanche markets
    assertEq(inputs.hubAdmin, address(0), 'hubAdmin');
    assertEq(inputs.spokeAdmin, address(0), 'spokeAdmin');

    assertEq(inputs.nativeWrapper, WETH, 'nativeWrapper');
    assertTrue(inputs.deployNativeTokenGateway, 'deployNativeTokenGateway');
    assertTrue(inputs.deploySignatureGateway, 'deploySignatureGateway');
    assertTrue(inputs.deployPositionManagers, 'deployPositionManagers');
    // roles are granted by the configuration and handover scripts, not at deploy time
    assertFalse(inputs.grantRoles, 'grantRoles');

    assertEq(inputs.hubLabels.length, 1, 'hub count');
    assertEq(inputs.hubLabels[0], 'core', 'hub label');
    assertEq(inputs.spokeLabels.length, 1, 'spoke count');
    assertEq(inputs.spokeLabels[0], 'main', 'spoke label');
    assertEq(inputs.spokeMaxReservesLimits.length, 0, 'spoke max reserves limits');
    assertTrue(inputs.salt != bytes32(0), 'salt');
  }

  /// @notice The handover targets are read off the same file the deploy is driven by.
  function test_handoverTargets() public view {
    AaveV4BaseConfigInputs.Handover memory targets = AaveV4BaseConfigInputs.readHandover();

    assertEq(targets.securityCouncil, V4_SECURITY_COUNCIL, 'securityCouncil');
    assertEq(targets.councilExecutor, PLACEHOLDER_ADDRESS, 'councilExecutor');
    assertEq(targets.governanceExecutor, GOVERNANCE_EXECUTOR, 'governanceExecutor');
    assertEq(targets.proxyAdminOwner, V4_SECURITY_COUNCIL, 'proxyAdminOwner');
    assertEq(targets.treasurySpokeOwner, V4_SECURITY_COUNCIL, 'treasurySpokeOwner');
    assertEq(targets.gatewayOwner, V4_SECURITY_COUNCIL, 'gatewayOwner');
    assertEq(targets.positionManagerOwner, V4_SECURITY_COUNCIL, 'positionManagerOwner');
  }

  /// @notice The launch set is empty until the assets and their risk parameters are decided, and
  ///         reading it is not an error.
  function test_assetInputsAreEmpty() public view {
    assertEq(AaveV4BaseConfigInputs.readAssets().length, 0, 'asset count');
  }

  /// @notice A deploy on Base itself refuses to read the placeholder address.
  function test_deployRevertsOnBaseWithPlaceholders() public {
    vm.chainId(BASE_CHAIN_ID);
    vm.expectRevert(abi.encodeWithSelector(PlaceholderAddress.selector, 'hubConfiguratorAdmin'));
    this.readDeployInputs();
  }

  /// @dev Exposes the deploy inputs externally, so that `vm.expectRevert` sees a nested call.
  function readDeployInputs() external view returns (InputUtils.FullDeployInputs memory) {
    return _getDeployInputs();
  }

  /// @notice The config engine lands on the address `predictedAddress` computes for it.
  /// @dev That address is what governance payloads are built against, and nothing records it, so it
  ///      has to be recomputable rather than merely deterministic.
  function test_configEngineDeploysAtPredictedAddress() public {
    address predicted = AaveV4BaseConfigEngine.predictedAddress();
    assertEq(predicted.code.length, 0, 'already deployed');

    assertEq(AaveV4BaseConfigEngine.deploy(), predicted, 'deployed address');
    assertGt(predicted.code.length, 0, 'engine code');
  }

  function test_deployWithBaseConfig() public {
    InputUtils.FullDeployInputs memory sanitizedInputs = _loadWarningsAndSanitizeInputs(
      _getDeployInputs(),
      _deployer
    );

    // the Council owns the proxies and the treasury spoke from the deploy transaction onwards
    assertEq(sanitizedInputs.proxyAdminOwner, V4_SECURITY_COUNCIL, 'proxyAdminOwner');
    assertEq(sanitizedInputs.treasurySpokeOwner, V4_SECURITY_COUNCIL, 'treasurySpokeOwner');

    // the managers and gateways start on the deployer, which needs `onlyOwner` access to
    // `registerSpoke` during configuration
    assertEq(sanitizedInputs.gatewayOwner, _deployer, 'gatewayOwner');
    assertEq(sanitizedInputs.positionManagerOwner, _deployer, 'positionManagerOwner');

    _deployWriteReportAndVerify(sanitizedInputs);
  }

  /// @dev Tests are non-interactive.
  function _executeUserPrompt() internal override {}
}
