// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BeaconProxy} from 'src/dependencies/openzeppelin/BeaconProxy.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ITokenizationSpokeInstance} from 'src/deployments/utils/interfaces/ITokenizationSpokeInstance.sol';

/// @title TokenizationSpokeDeployer
/// @author Aave Labs
/// @notice Library for deterministic CREATE2 deployment and address pre-computation of TokenizationSpoke
/// beacon proxies using the Safe Singleton Factory.
library TokenizationSpokeDeployer {
  /// @notice Deploys a TokenizationSpoke BeaconProxy via CREATE2 through the Safe Singleton Factory.
  /// @dev The proxy points to the shared `beacon`, whose owner controls the implementation upgrades.
  /// @param beacon The address of the shared TokenizationSpoke beacon.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param name The ERC20 name for the TokenizationSpoke share token.
  /// @param symbol The ERC20 symbol for the TokenizationSpoke share token.
  /// @return proxy The address of the deployed proxy.
  function deploy(
    address beacon,
    address hub,
    address underlying,
    string calldata name,
    string calldata symbol
  ) external returns (address proxy) {
    bytes32 proxySalt = _computeProxySalt(beacon, hub, underlying, name, symbol);
    bytes memory initData = abi.encodeCall(
      ITokenizationSpokeInstance.initialize,
      (hub, underlying, name, symbol)
    );
    bytes memory proxyCreationCode = abi.encodePacked(
      type(BeaconProxy).creationCode,
      abi.encode(beacon, initData)
    );
    proxy = Create2Utils.create2Deploy(proxySalt, proxyCreationCode);
  }

  /// @notice Pre-computes the CREATE2 address of the TokenizationSpoke BeaconProxy.
  /// @param beacon The address of the shared TokenizationSpoke beacon.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param name The ERC20 name for the TokenizationSpoke share token.
  /// @param symbol The ERC20 symbol for the TokenizationSpoke share token.
  /// @return The predicted proxy address.
  function computeProxyAddress(
    address beacon,
    address hub,
    address underlying,
    string memory name,
    string memory symbol
  ) external pure returns (address) {
    bytes32 proxySalt = _computeProxySalt(beacon, hub, underlying, name, symbol);
    bytes memory initData = abi.encodeCall(
      ITokenizationSpokeInstance.initialize,
      (hub, underlying, name, symbol)
    );
    bytes memory creationCode = abi.encodePacked(
      type(BeaconProxy).creationCode,
      abi.encode(beacon, initData)
    );
    return Create2Utils.computeCreate2Address(proxySalt, creationCode);
  }

  function _computeProxySalt(
    address beacon,
    address hub,
    address underlying,
    string memory name,
    string memory symbol
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(beacon, hub, underlying, name, symbol, 'proxy'));
  }
}
