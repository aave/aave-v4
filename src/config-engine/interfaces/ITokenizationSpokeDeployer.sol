// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @notice ABI shared by the Solidity and Vyper tokenization-spoke deployers.
interface ITokenizationSpokeDeployer {
  function deploy(
    address hub,
    address underlying,
    string calldata name,
    string calldata symbol,
    address proxyAdminOwner
  ) external returns (address proxy);

  function computeImplementationAddress(
    address hub,
    address underlying,
    string calldata name,
    string calldata symbol
  ) external view returns (address);

  function computeProxyAddress(
    address hub,
    address underlying,
    string calldata name,
    string calldata symbol,
    address proxyAdminOwner
  ) external view returns (address);
}
