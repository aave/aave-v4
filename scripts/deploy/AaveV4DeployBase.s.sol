// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';

/// @title AaveV4DeployBase
/// @author Aave Labs
/// @notice Base deploy script (chain id 8453). Deploy inputs are read from config/base.json.
contract AaveV4DeployBase is AaveV4DeployBatchBaseScript {
  /// @dev Path to the Base deploy inputs, relative to the project root.
  string internal constant DEPLOY_CONFIG_PATH = 'config/base.json';

  /// @dev Stands in for the V4 Security Council executor, which is not deployed on Base yet. Both
  /// configurator domain admin fields of config/base.json carry it.
  address internal constant PLACEHOLDER_ADDRESS = 0x1111111111111111111111111111111111111111;

  /// @notice Thrown when a deploy on Base itself would read the placeholder address.
  error PlaceholderAddress(string field);

  /// @dev Constructor.
  constructor() AaveV4DeployBatchBaseScript('base') {}

  /// @dev Base mainnet.
  function _expectedChainId() internal pure virtual override returns (uint256) {
    return 8453;
  }

  /// @dev Gives the deployer initial ownership of the position managers and gateways, because
  /// `PositionManagerBase.registerSpoke` is `onlyOwner` and `AaveV4BaseConfiguration` has to call it
  /// to wire them to the Spokes. The configured values are the end-state targets, applied by
  /// `AaveV4RelinquishBase` as an `Ownable2Step` transfer the Council then accepts.
  ///
  /// Every other ownership is left as configured: the Council owns the ProxyAdmins and the
  /// TreasurySpoke from the deploy transaction onwards, since configuration never touches them and
  /// the TreasurySpoke would otherwise need an `Ownable2Step` acceptance of its own.
  function _loadWarningsAndSanitizeInputs(
    InputUtils.FullDeployInputs memory inputs,
    address deployer
  ) internal virtual override returns (InputUtils.FullDeployInputs memory) {
    InputUtils.FullDeployInputs memory sanitizedInputs = super._loadWarningsAndSanitizeInputs(
      inputs,
      deployer
    );

    sanitizedInputs.gatewayOwner = deployer;
    sanitizedInputs.positionManagerOwner = deployer;

    return sanitizedInputs;
  }

  /// @dev Reads the FullDeployInputs from config/base.json.
  ///
  /// `hubAdmin` and `spokeAdmin` are zero on purpose: the Hub and Spoke roles they would fill are
  /// left unheld, as on the live Ethereum and Avalanche markets. `grantRoles` is false, so the
  /// deploy reads neither.
  function _getDeployInputs()
    internal
    view
    virtual
    override
    returns (InputUtils.FullDeployInputs memory inputs)
  {
    string memory json = vm.readFile(DEPLOY_CONFIG_PATH);

    uint256[] memory rawLimits = vm.parseJsonUintArray(json, '.spokeMaxReservesLimits');
    uint16[] memory spokeMaxReservesLimits = new uint16[](rawLimits.length);
    for (uint256 i; i < rawLimits.length; ++i) {
      spokeMaxReservesLimits[i] = uint16(rawLimits[i]);
    }

    inputs = InputUtils.FullDeployInputs({
      accessManagerAdmin: vm.parseJsonAddress(json, '.accessManagerAdmin'),
      proxyAdminOwner: vm.parseJsonAddress(json, '.proxyAdminOwner'),
      hubAdmin: vm.parseJsonAddress(json, '.hubAdmin'),
      hubConfiguratorAdmin: vm.parseJsonAddress(json, '.hubConfiguratorAdmin'),
      treasurySpokeOwner: vm.parseJsonAddress(json, '.treasurySpokeOwner'),
      spokeAdmin: vm.parseJsonAddress(json, '.spokeAdmin'),
      spokeConfiguratorAdmin: vm.parseJsonAddress(json, '.spokeConfiguratorAdmin'),
      gatewayOwner: vm.parseJsonAddress(json, '.gatewayOwner'),
      positionManagerOwner: vm.parseJsonAddress(json, '.positionManagerOwner'),
      nativeWrapper: vm.parseJsonAddress(json, '.nativeWrapper'),
      deployNativeTokenGateway: vm.parseJsonBool(json, '.deployNativeTokenGateway'),
      deploySignatureGateway: vm.parseJsonBool(json, '.deploySignatureGateway'),
      deployPositionManagers: vm.parseJsonBool(json, '.deployPositionManagers'),
      grantRoles: vm.parseJsonBool(json, '.grantRoles'),
      hubLabels: vm.parseJsonStringArray(json, '.hubLabels'),
      spokeLabels: vm.parseJsonStringArray(json, '.spokeLabels'),
      spokeMaxReservesLimits: spokeMaxReservesLimits,
      salt: vm.parseJsonBytes32(json, '.salt')
    });

    if (block.chainid == _expectedChainId()) {
      _requireResolved(inputs.hubConfiguratorAdmin, 'hubConfiguratorAdmin');
      _requireResolved(inputs.spokeConfiguratorAdmin, 'spokeConfiguratorAdmin');
      _requireResolved(vm.parseJsonAddress(json, '.governanceExecutor'), 'governanceExecutor');
    }
  }

  /// @dev The handover script reads these fields back and grants the market's standing permissions
  /// from them, so none of them may still be the placeholder on Base. Local runs are exempt, which
  /// is what lets the tests deploy from the unresolved config.
  function _requireResolved(address target, string memory field) private pure {
    require(target != PLACEHOLDER_ADDRESS, PlaceholderAddress(field));
  }
}
