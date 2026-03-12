// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';
import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';

/// @title TokenizationSpokeDeployer
/// @author Aave Labs
/// @notice Library for deterministic CREATE2 deployment and address pre-computation of TokenizationSpoke proxies
///   using the Safe Singleton Factory.
library TokenizationSpokeDeployer {
  /// @notice Thrown when a CREATE2 deployment via the factory fails.
  error Create2DeploymentFailed();

  /// @dev Safe Singleton Factory address (https://github.com/safe-global/safe-singleton-factory).
  address internal constant CREATE2_FACTORY = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;

  /// @notice Deploys a TokenizationSpokeInstance implementation and TransparentUpgradeableProxy via CREATE2
  ///   through the Safe Singleton Factory.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param name The ERC20 name for the TokenizationSpoke share token.
  /// @param symbol The ERC20 symbol for the TokenizationSpoke share token.
  /// @return proxy The address of the deployed proxy.
  function deploy(
    address hub,
    address underlying,
    string calldata name,
    string calldata symbol
  ) external returns (address proxy) {
    bytes32 implSalt = _computeImplementationSalt(hub, underlying, name, symbol);
    bytes memory implCreationCode = abi.encodePacked(
      type(TokenizationSpokeInstance).creationCode,
      abi.encode(hub, underlying)
    );
    address impl = _create2Deploy(implSalt, implCreationCode);

    bytes32 proxySalt = _computeProxySalt(hub, underlying, name, symbol);
    bytes memory initData = abi.encodeCall(TokenizationSpokeInstance.initialize, (name, symbol));
    bytes memory proxyCreationCode = abi.encodePacked(
      type(TransparentUpgradeableProxy).creationCode,
      abi.encode(impl, msg.sender, initData)
    );
    proxy = _create2Deploy(proxySalt, proxyCreationCode);
  }

  /// @notice Pre-computes the CREATE2 address of the TokenizationSpokeInstance implementation.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param name The ERC20 name for the TokenizationSpoke share token.
  /// @param symbol The ERC20 symbol for the TokenizationSpoke share token.
  /// @return The predicted implementation address.
  function computeImplementationAddress(
    address hub,
    address underlying,
    string memory name,
    string memory symbol
  ) external pure returns (address) {
    return _computeImplementationAddress(hub, underlying, name, symbol);
  }

  /// @notice Pre-computes the CREATE2 address of the TransparentUpgradeableProxy.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param name The ERC20 name for the TokenizationSpoke share token.
  /// @param symbol The ERC20 symbol for the TokenizationSpoke share token.
  /// @param proxyAdminOwner The initial owner of the ProxyAdmin (msg.sender in `deploy`).
  /// @return The predicted proxy address.
  function computeProxyAddress(
    address hub,
    address underlying,
    string memory name,
    string memory symbol,
    address proxyAdminOwner
  ) external pure returns (address) {
    address impl = _computeImplementationAddress(hub, underlying, name, symbol);

    bytes32 proxySalt = _computeProxySalt(hub, underlying, name, symbol);
    bytes memory initData = abi.encodeCall(TokenizationSpokeInstance.initialize, (name, symbol));
    bytes memory creationCode = abi.encodePacked(
      type(TransparentUpgradeableProxy).creationCode,
      abi.encode(impl, proxyAdminOwner, initData)
    );
    return _computeCreate2Address(proxySalt, creationCode);
  }

  function _create2Deploy(
    bytes32 salt,
    bytes memory creationCode
  ) private returns (address deployed) {
    (bool success, bytes memory returnData) = CREATE2_FACTORY.call(
      abi.encodePacked(salt, creationCode)
    );
    if (!success || returnData.length < 20) revert Create2DeploymentFailed();
    deployed = address(uint160(bytes20(returnData)));
  }

  function _computeImplementationAddress(
    address hub,
    address underlying,
    string memory name,
    string memory symbol
  ) internal pure returns (address) {
    bytes32 implSalt = _computeImplementationSalt(hub, underlying, name, symbol);
    bytes memory creationCode = abi.encodePacked(
      type(TokenizationSpokeInstance).creationCode,
      abi.encode(hub, underlying)
    );
    return _computeCreate2Address(implSalt, creationCode);
  }

  function _computeCreate2Address(
    bytes32 salt,
    bytes memory creationCode
  ) private pure returns (address) {
    return
      address(
        uint160(
          uint256(
            keccak256(
              abi.encodePacked(bytes1(0xff), CREATE2_FACTORY, salt, keccak256(creationCode))
            )
          )
        )
      );
  }

  function _computeImplementationSalt(
    address hub,
    address underlying,
    string memory name,
    string memory symbol
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(hub, underlying, name, symbol, 'impl'));
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
