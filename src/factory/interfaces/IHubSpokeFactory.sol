// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IHubSpokeFactory
/// @author Aave Labs
/// @notice Interface for the Hub & Spoke factory.
interface IHubSpokeFactory {
  /// @notice Types of instances deployed by the factory.
  enum InstanceType {
    None,
    Hub,
    Spoke,
    TreasurySpoke,
    TokenizationSpoke
  }

  /// @notice Deployment information of an instance.
  /// @param deployer The caller of the deployment.
  /// @param instanceType The type of the instance.
  struct InstanceInfo {
    address deployer;
    InstanceType instanceType;
  }

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

  /// @notice Emitted when the canonical implementation of an instance type is updated.
  /// @param instanceType The instance type.
  /// @param implementation The new canonical implementation.
  event ImplementationUpdated(InstanceType indexed instanceType, address indexed implementation);

  /// @notice Thrown when a canonical implementation is invalid.
  error InvalidImplementation();

  /// @notice Thrown when the caller and salt map to an address already in use.
  error SaltAlreadyUsed();

  /// @notice Thrown when the caller already deployed a TokenizationSpoke for the Hub and underlying.
  error TokenizationSpokeAlreadyDeployed();

  /// @notice Updates the canonical implementation of an instance type.
  /// @dev The implementation must match the revision and type expected for `instanceType`. Instances already deployed
  /// are not affected, but the addresses returned by `predict*` change.
  /// @param instanceType The instance type.
  /// @param implementation The new canonical implementation.
  function setImplementation(InstanceType instanceType, address implementation) external;

  /// @notice Deploys a Hub proxy pointing to the canonical Hub implementation, and its interest rate strategy.
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

  /// @notice Deploys an AaveOracle and a Spoke proxy pointing to the canonical Spoke implementation, and binds them.
  /// @dev The CREATE2 salt is bound to the caller. Reverts with `SaltAlreadyUsed` if a resulting address is already in use.
  /// @param salt The caller-provided salt.
  /// @param authority The access-control authority of the Spoke.
  /// @param maxUserReservesLimit The maximum number of collateral and borrow reserves a user can have.
  /// @param proxyAdminOwner The owner of the Spoke ProxyAdmin.
  /// @return The deployed Spoke addresses.
  function deploySpoke(
    bytes32 salt,
    address authority,
    uint16 maxUserReservesLimit,
    address proxyAdminOwner
  ) external returns (SpokeDeployment memory);

  /// @notice Deploys a TreasurySpoke proxy pointing to the canonical TreasurySpoke implementation.
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

  /// @notice Deploys a TokenizationSpoke proxy pointing to the canonical TokenizationSpoke implementation.
  /// @dev The CREATE2 salt is bound to the caller. Reverts with `SaltAlreadyUsed` if a resulting address is already in use.
  /// Reverts with `TokenizationSpokeAlreadyDeployed` if the caller already deployed one for `hub` and `underlying`.
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
  /// @param maxUserReservesLimit The maximum number of collateral and borrow reserves a user can have.
  /// @param proxyAdminOwner The owner of the Spoke ProxyAdmin.
  /// @return The predicted Spoke addresses.
  function predictSpoke(
    address deployer,
    bytes32 salt,
    address authority,
    uint16 maxUserReservesLimit,
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

  /// @notice Returns the canonical implementation of an instance type.
  /// @param instanceType The instance type.
  /// @return The canonical implementation, or zero address if unset.
  function getImplementation(InstanceType instanceType) external view returns (address);

  /// @notice Returns the instances of a type deployed by a deployer, in deployment order.
  /// @param deployer The caller of the deployments.
  /// @param instanceType The instance type.
  /// @return The deployed instances.
  function getInstances(
    address deployer,
    InstanceType instanceType
  ) external view returns (address[] memory);

  /// @notice Returns the deployment information of an instance.
  /// @dev Records provenance only: a ProxyAdmin can upgrade an instance afterwards.
  /// @param instance The instance address.
  /// @return The deployment information, empty if the instance was not deployed by the factory.
  function getInstanceInfo(address instance) external view returns (InstanceInfo memory);

  /// @notice Returns the TokenizationSpoke deployed by a deployer for a Hub and underlying.
  /// @param deployer The caller of the deployment.
  /// @param hub The Hub of the tokenized asset.
  /// @param underlying The underlying of the tokenized asset.
  /// @return The TokenizationSpoke proxy, or zero address if none.
  function getTokenizationSpoke(
    address deployer,
    address hub,
    address underlying
  ) external view returns (address);

  /// @notice Returns the decimals of the AaveOracle deployed with each Spoke.
  function ORACLE_DECIMALS() external view returns (uint8);
}
