// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';

/// @title AaveV4DeployArc
/// @author Aave Labs
/// @notice Arc deploy script (chain id 5042). Deploy inputs are read from scripts/config/arc.json.
contract AaveV4DeployArc is AaveV4DeployBatchBaseScript {
  /// @dev Path to the Arc deploy inputs, relative to the project root.
  string internal constant DEPLOY_CONFIG_PATH = 'scripts/config/arc.json';

  /// @dev Constructor.
  constructor() AaveV4DeployBatchBaseScript('arc') {}

  /// @dev Arc mainnet. The Arc testnet chain id is 5042002.
  function _expectedChainId() internal pure virtual override returns (uint256) {
    return 5042;
  }

  /// @dev Sets deploy-time ownership so that the deployer holds exactly what configuration needs
  /// and nothing else.
  ///
  /// `proxyAdminOwner` and `treasurySpokeOwner` are restored from the config, which the base script
  /// otherwise overwrites with the deployer whenever `grantRoles` is false. Configuration never
  /// touches either, so the Council owns them from the deploy transaction onwards and the
  /// TreasurySpoke never needs an `Ownable2Step` acceptance.
  ///
  /// `gatewayOwner` and `positionManagerOwner` go the other way: they are forced to the deployer,
  /// because `PositionManagerBase.registerSpoke` is `onlyOwner` and configuration has to call it.
  /// The config's values are the end-state targets, applied by `AaveV4RelinquishArc`.
  ///
  /// Both values are read before delegating: the base assigns `sanitizedInputs = inputs`, which for
  /// two memory structs is a reference rather than a copy, so it mutates `inputs` in place and the
  /// configured values are gone by the time it returns.
  function _loadWarningsAndSanitizeInputs(
    InputUtils.FullDeployInputs memory inputs,
    address deployer
  ) internal virtual override returns (InputUtils.FullDeployInputs memory) {
    address configuredProxyAdminOwner = inputs.proxyAdminOwner;
    address configuredTreasurySpokeOwner = inputs.treasurySpokeOwner;

    InputUtils.FullDeployInputs memory sanitizedInputs = super._loadWarningsAndSanitizeInputs(
      inputs,
      deployer
    );

    if (configuredProxyAdminOwner != address(0)) {
      sanitizedInputs.proxyAdminOwner = configuredProxyAdminOwner;
    }
    if (configuredTreasurySpokeOwner != address(0)) {
      sanitizedInputs.treasurySpokeOwner = configuredTreasurySpokeOwner;
    }

    sanitizedInputs.gatewayOwner = deployer;
    sanitizedInputs.positionManagerOwner = deployer;

    return sanitizedInputs;
  }

  /// @dev Reads the FullDeployInputs from scripts/config/arc.json.
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
  }
}
