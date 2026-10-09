// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployEthereum} from 'scripts/deploy/AaveV4DeployEthereum.s.sol';
import {AaveV4SentoraConfigInputs} from 'scripts/config/AaveV4SentoraConfigInputs.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';

/// @title AaveV4DeploySentora
/// @author Aave Labs
/// @notice Sentora market deploy script on Ethereum (chain id 1): one Hub and its Spokes. Deploy
/// inputs are read from config/sentora.json.
contract AaveV4DeploySentora is AaveV4DeployEthereum {
  /// @dev Path to the Sentora deploy inputs, relative to the project root.
  string internal constant DEPLOY_CONFIG_PATH = 'config/sentora.json';

  /// @dev Gives the deployer initial ownership of the position managers, the gateways and the
  /// TreasurySpoke. The configured values are the end-state targets, applied by
  /// `AaveV4RelinquishSentora` as an `Ownable2Step` transfer the new owner then accepts.
  ///
  /// The managers and gateways start on the deployer because `PositionManagerBase.registerSpoke` is
  /// `onlyOwner` and `AaveV4SentoraConfiguration` has to call it to wire them to the Spoke. The
  /// TreasurySpoke does because the deploy gives its ProxyAdmin the same owner as the TreasurySpoke
  /// itself, while the two end up with different owners: the handover moves that ProxyAdmin to
  /// `proxyAdminOwner`.
  ///
  /// The other ProxyAdmins are left as configured, owned by `proxyAdminOwner` from the deploy
  /// transaction onwards.
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
    sanitizedInputs.treasurySpokeOwner = deployer;

    return sanitizedInputs;
  }

  /// @dev Reads the FullDeployInputs from config/sentora.json.
  ///
  /// `hubAdmin`, `spokeAdmin`, `hubConfiguratorAdmin` and `spokeConfiguratorAdmin` are zero on
  /// purpose: the Hub and Spoke roles are left unheld, as on the live Ethereum and Avalanche
  /// markets, and the configurator roles are granted to their holders at handover. `grantRoles` is
  /// false, so the deploy reads none of them.
  ///
  /// The handover targets are read here too, so that a deploy on Ethereum refuses to run while any
  /// of them is still a placeholder.
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

    AaveV4SentoraConfigInputs.readHandover();
  }
}
