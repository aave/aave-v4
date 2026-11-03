// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IHubSpokeFactory
/// @author Aave Labs
/// @notice Interface for the Hub & Spoke factory.
interface IHubSpokeFactory {
  /// @notice Addresses produced by a Hub deployment.
  /// @param proxy The Hub proxy.
  /// @param irStrategy The interest rate strategy bound to the Hub proxy.
  struct HubDeployment {
    address proxy;
    address irStrategy;
  }

  /// @notice Addresses produced by a Spoke deployment.
  /// @param proxy The Spoke proxy.
  /// @param oracle The AaveOracle bound to the Spoke proxy.
  struct SpokeDeployment {
    address proxy;
    address oracle;
  }

  /// @notice Emitted when a Hub is deployed.
  /// @param deployer The caller of the deployment.
  /// @param proxy The Hub proxy.
  /// @param irStrategy The interest rate strategy bound to the Hub proxy.
  /// @param authority The access-control authority of the Hub.
  /// @param proxyAdminOwner The owner of the Hub ProxyAdmin.
  event HubDeployed(
    address indexed deployer,
    address indexed proxy,
    address irStrategy,
    address authority,
    address proxyAdminOwner
  );

  /// @notice Emitted when a Spoke is deployed.
  /// @param deployer The caller of the deployment.
  /// @param proxy The Spoke proxy.
  /// @param oracle The AaveOracle bound to the Spoke proxy.
  /// @param authority The access-control authority of the Spoke.
  /// @param proxyAdminOwner The owner of the Spoke ProxyAdmin.
  event SpokeDeployed(
    address indexed deployer,
    address indexed proxy,
    address oracle,
    address authority,
    address proxyAdminOwner
  );

  /// @notice Emitted when a TreasurySpoke is deployed.
  /// @param deployer The caller of the deployment.
  /// @param proxy The TreasurySpoke proxy.
  /// @param owner The owner of the TreasurySpoke.
  /// @param proxyAdminOwner The owner of the TreasurySpoke ProxyAdmin.
  event TreasurySpokeDeployed(
    address indexed deployer,
    address indexed proxy,
    address owner,
    address proxyAdminOwner
  );

  /// @notice Emitted when a TokenizationSpoke is deployed.
  /// @param deployer The caller of the deployment.
  /// @param proxy The TokenizationSpoke proxy.
  /// @param hub The Hub of the tokenized asset.
  /// @param underlying The underlying of the tokenized asset.
  /// @param proxyAdminOwner The owner of the TokenizationSpoke ProxyAdmin.
  event TokenizationSpokeDeployed(
    address indexed deployer,
    address indexed proxy,
    address indexed hub,
    address underlying,
    address proxyAdminOwner
  );

  /// @notice Thrown when a canonical implementation is invalid.
  error InvalidImplementation();

  /// @notice Thrown when the caller and salt map to an address already in use.
  error SaltAlreadyUsed();

  /// @notice Deploys a Hub proxy pointing to `HUB_IMPLEMENTATION`, and its interest rate strategy.
  /// @dev The CREATE2 salt is bound to the caller. Reverts with `SaltAlreadyUsed` if a resulting address is already in use.
  /// @param salt The caller-provided salt.
  /// @param authority The access-control authority of the Hub.
  /// @param proxyAdminOwner The owner of the Hub ProxyAdmin.
  /// @return The deployed Hub addresses.
  function deployHub(
    bytes32 salt,
    address authority,
    address proxyAdminOwner
  ) external returns (HubDeployment memory);

  /// @notice Deploys an AaveOracle and a Spoke proxy pointing to `SPOKE_IMPLEMENTATION`, and binds them.
  /// @dev The CREATE2 salt is bound to the caller. Reverts with `SaltAlreadyUsed` if a resulting address is already in use.
  /// The Spoke is initialized with `MAX_USER_RESERVES_LIMIT`.
  /// @param salt The caller-provided salt.
  /// @param authority The access-control authority of the Spoke.
  /// @param proxyAdminOwner The owner of the Spoke ProxyAdmin.
  /// @return The deployed Spoke addresses.
  function deploySpoke(
    bytes32 salt,
    address authority,
    address proxyAdminOwner
  ) external returns (SpokeDeployment memory);

  /// @notice Deploys a TreasurySpoke proxy pointing to `TREASURY_SPOKE_IMPLEMENTATION`.
  /// @dev The CREATE2 salt is bound to the caller. Reverts with `SaltAlreadyUsed` if a resulting address is already in use.
  /// @param salt The caller-provided salt.
  /// @param owner The owner of the TreasurySpoke.
  /// @param proxyAdminOwner The owner of the TreasurySpoke ProxyAdmin.
  /// @return The TreasurySpoke proxy.
  function deployTreasurySpoke(
    bytes32 salt,
    address owner,
    address proxyAdminOwner
  ) external returns (address);

  /// @notice Deploys a TokenizationSpoke proxy pointing to `TOKENIZATION_SPOKE_IMPLEMENTATION`.
  /// @dev The CREATE2 salt is bound to the caller. Reverts with `SaltAlreadyUsed` if a resulting address is already in use.
  /// Registering the TokenizationSpoke on its Hub is left to the caller.
  /// @param salt The caller-provided salt.
  /// @param hub The Hub of the tokenized asset.
  /// @param underlying The underlying of the tokenized asset.
  /// @param name The ERC20 name of the share token.
  /// @param symbol The ERC20 symbol of the share token.
  /// @param proxyAdminOwner The owner of the TokenizationSpoke ProxyAdmin.
  /// @return The TokenizationSpoke proxy.
  function deployTokenizationSpoke(
    bytes32 salt,
    address hub,
    address underlying,
    string calldata name,
    string calldata symbol,
    address proxyAdminOwner
  ) external returns (address);

  /// @notice Predicts the addresses of a Hub deployment.
  /// @param deployer The caller of the deployment.
  /// @param salt The caller-provided salt.
  /// @param authority The access-control authority of the Hub.
  /// @param proxyAdminOwner The owner of the Hub ProxyAdmin.
  /// @return The predicted Hub addresses.
  function predictHub(
    address deployer,
    bytes32 salt,
    address authority,
    address proxyAdminOwner
  ) external view returns (HubDeployment memory);

  /// @notice Predicts the addresses of a Spoke deployment.
  /// @param deployer The caller of the deployment.
  /// @param salt The caller-provided salt.
  /// @param authority The access-control authority of the Spoke.
  /// @param proxyAdminOwner The owner of the Spoke ProxyAdmin.
  /// @return The predicted Spoke addresses.
  function predictSpoke(
    address deployer,
    bytes32 salt,
    address authority,
    address proxyAdminOwner
  ) external view returns (SpokeDeployment memory);

  /// @notice Predicts the address of a TreasurySpoke deployment.
  /// @param deployer The caller of the deployment.
  /// @param salt The caller-provided salt.
  /// @param owner The owner of the TreasurySpoke.
  /// @param proxyAdminOwner The owner of the TreasurySpoke ProxyAdmin.
  /// @return The predicted TreasurySpoke proxy.
  function predictTreasurySpoke(
    address deployer,
    bytes32 salt,
    address owner,
    address proxyAdminOwner
  ) external view returns (address);

  /// @notice Predicts the address of a TokenizationSpoke deployment.
  /// @param deployer The caller of the deployment.
  /// @param salt The caller-provided salt.
  /// @param hub The Hub of the tokenized asset.
  /// @param underlying The underlying of the tokenized asset.
  /// @param name The ERC20 name of the share token.
  /// @param symbol The ERC20 symbol of the share token.
  /// @param proxyAdminOwner The owner of the TokenizationSpoke ProxyAdmin.
  /// @return The predicted TokenizationSpoke proxy.
  function predictTokenizationSpoke(
    address deployer,
    bytes32 salt,
    address hub,
    address underlying,
    string calldata name,
    string calldata symbol,
    address proxyAdminOwner
  ) external view returns (address);

  /// @notice Returns the canonical Hub implementation.
  function HUB_IMPLEMENTATION() external view returns (address);

  /// @notice Returns the canonical Spoke implementation.
  function SPOKE_IMPLEMENTATION() external view returns (address);

  /// @notice Returns the canonical TreasurySpoke implementation.
  function TREASURY_SPOKE_IMPLEMENTATION() external view returns (address);

  /// @notice Returns the canonical TokenizationSpoke implementation.
  function TOKENIZATION_SPOKE_IMPLEMENTATION() external view returns (address);

  /// @notice Returns the decimals of the AaveOracle deployed with each Spoke.
  function ORACLE_DECIMALS() external view returns (uint8);

  /// @notice Returns the maximum user reserves limit each Spoke is initialized with.
  function MAX_USER_RESERVES_LIMIT() external view returns (uint16);
}
