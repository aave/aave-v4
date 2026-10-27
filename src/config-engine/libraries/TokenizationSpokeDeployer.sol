// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';

/// @title TokenizationSpokeDeployer
/// @author Aave Labs
/// @notice Library for deterministic CREATE2 deployment and address pre-computation of TokenizationSpoke proxies
/// using the Safe Singleton Factory.
library TokenizationSpokeDeployer {
  /// @dev Thrown when the proxy admin owner is the zero address.
  error InvalidProxyAdminOwner();

  /// @notice Deploys a TransparentUpgradeableProxy pointing to the given TokenizationSpoke implementation via CREATE2
  /// through the Safe Singleton Factory.
  /// @dev The proxy admin owner must be passed explicitly, never derived from execution context.
  /// @param implementation The address of the TokenizationSpokeInstance implementation.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param name The ERC20 name for the TokenizationSpoke share token.
  /// @param symbol The ERC20 symbol for the TokenizationSpoke share token.
  /// @param proxyAdminOwner The initial owner of the ProxyAdmin.
  /// @return proxy The address of the deployed proxy.
  function deploy(
    address implementation,
    address hub,
    address underlying,
    string calldata name,
    string calldata symbol,
    address proxyAdminOwner
  ) external returns (address proxy) {
    require(proxyAdminOwner != address(0), InvalidProxyAdminOwner());

    proxy = Create2Utils.create2Deploy(
      _computeProxySalt(hub, underlying, name, symbol),
      _proxyCreationCode(implementation, hub, underlying, name, symbol, proxyAdminOwner)
    );
  }

  /// @notice Pre-computes the CREATE2 address of the TransparentUpgradeableProxy.
  /// @param implementation The address of the TokenizationSpokeInstance implementation.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param name The ERC20 name for the TokenizationSpoke share token.
  /// @param symbol The ERC20 symbol for the TokenizationSpoke share token.
  /// @param proxyAdminOwner The initial owner of the ProxyAdmin.
  /// @return The predicted proxy address.
  function computeProxyAddress(
    address implementation,
    address hub,
    address underlying,
    string memory name,
    string memory symbol,
    address proxyAdminOwner
  ) external pure returns (address) {
    return
      Create2Utils.computeCreate2Address(
        _computeProxySalt(hub, underlying, name, symbol),
        _proxyCreationCode(implementation, hub, underlying, name, symbol, proxyAdminOwner)
      );
  }

  function _proxyCreationCode(
    address implementation,
    address hub,
    address underlying,
    string memory name,
    string memory symbol,
    address proxyAdminOwner
  ) internal pure returns (bytes memory) {
    bytes memory initData = abi.encodeCall(
      TokenizationSpokeInstance.initialize,
      (hub, underlying, name, symbol)
    );
    return
      abi.encodePacked(
        type(TransparentUpgradeableProxy).creationCode,
        abi.encode(implementation, proxyAdminOwner, initData)
      );
  }

  function _computeProxySalt(
    address hub,
    address underlying,
    string memory name,
    string memory symbol
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(hub, underlying, name, symbol, 'proxy'));
  }
}
