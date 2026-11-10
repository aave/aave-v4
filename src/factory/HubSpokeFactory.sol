// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/AccessManagedUpgradeable.sol';
import {IERC5267} from 'src/dependencies/openzeppelin/IERC5267.sol';
import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';
import {IHubInstance} from 'src/deployments/utils/interfaces/IHubInstance.sol';
import {ISpokeInstance} from 'src/deployments/utils/interfaces/ISpokeInstance.sol';
import {ITreasurySpokeInstance} from 'src/deployments/utils/interfaces/ITreasurySpokeInstance.sol';
import {ITokenizationSpokeInstance} from 'src/deployments/utils/interfaces/ITokenizationSpokeInstance.sol';
import {HubSpokeFactoryStorage} from 'src/factory/HubSpokeFactoryStorage.sol';
import {IHubSpokeFactory} from 'src/factory/interfaces/IHubSpokeFactory.sol';

/// @title HubSpokeFactory
/// @author Aave Labs
/// @notice Deploys Hub, Spoke, TreasurySpoke and TokenizationSpoke instances as proxies to the canonical
/// implementations, and records every deployment.
/// @dev Deployments are permissionless. The caller is bound into every CREATE2 salt, so addresses can't be squatted
/// or front-run. Records are keyed by deployer and track provenance only: a ProxyAdmin can upgrade an instance
/// afterwards.
contract HubSpokeFactory is IHubSpokeFactory, HubSpokeFactoryStorage, AccessManagedUpgradeable {
  bytes32 internal constant HUB_SALT_DOMAIN = keccak256('hub');
  bytes32 internal constant SPOKE_SALT_DOMAIN = keccak256('spoke');
  bytes32 internal constant TREASURY_SPOKE_SALT_DOMAIN = keccak256('treasury-spoke');
  bytes32 internal constant TOKENIZATION_SPOKE_SALT_DOMAIN = keccak256('tokenization-spoke');

  /// @dev Prefix of the CREATE2 address derivation (EIP-1014).
  bytes1 internal constant CREATE2_PREFIX = 0xff;

  /// @dev Revisions the canonical implementations must match.
  uint64 internal constant HUB_REVISION = 1;
  uint64 internal constant SPOKE_REVISION = 2;
  uint64 internal constant TREASURY_SPOKE_REVISION = 1;
  uint64 internal constant TOKENIZATION_SPOKE_REVISION = 2;

  /// @dev EIP-712 domain names telling the Spoke and TokenizationSpoke apart, as both share `SPOKE_REVISION`.
  bytes32 internal constant SPOKE_DOMAIN_NAME_HASH = keccak256('Spoke');
  bytes32 internal constant TOKENIZATION_SPOKE_DOMAIN_NAME_HASH = keccak256('Tokenization Spoke');

  /// @inheritdoc IHubSpokeFactory
  uint8 public constant ORACLE_DECIMALS = DeployConstants.ORACLE_DECIMALS;

  /// @dev Constructor.
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializer.
  /// @dev The authority contract must implement the `AccessManaged` interface for access control.
  /// @param authority The address of the authority contract which manages permissions.
  /// @param hubImplementation The canonical HubInstance implementation.
  /// @param spokeImplementation The canonical SpokeInstance implementation.
  /// @param treasurySpokeImplementation The canonical TreasurySpokeInstance implementation.
  /// @param tokenizationSpokeImplementation The canonical TokenizationSpokeInstance implementation.
  function initialize(
    address authority,
    address hubImplementation,
    address spokeImplementation,
    address treasurySpokeImplementation,
    address tokenizationSpokeImplementation
  ) external initializer {
    __AccessManaged_init(authority);
    _setImplementation(InstanceType.Hub, hubImplementation);
    _setImplementation(InstanceType.Spoke, spokeImplementation);
    _setImplementation(InstanceType.TreasurySpoke, treasurySpokeImplementation);
    _setImplementation(InstanceType.TokenizationSpoke, tokenizationSpokeImplementation);
  }

  /// @inheritdoc IHubSpokeFactory
  function setImplementation(
    InstanceType instanceType,
    address implementation
  ) external restricted {
    _setImplementation(instanceType, implementation);
  }

  /// @inheritdoc IHubSpokeFactory
  function deployHub(
    bytes32 salt,
    address authority,
    address proxyAdminOwner
  ) external returns (HubDeployment memory) {
    bytes32 childSalt = _deriveSalt(HUB_SALT_DOMAIN, msg.sender, salt);
    HubDeployment memory deployment;
    deployment.proxy = _deployProxy(
      childSalt,
      InstanceType.Hub,
      proxyAdminOwner,
      _hubInitData(authority)
    );
    deployment.irStrategy = _deployIrStrategy(childSalt, deployment.proxy);
    _register(InstanceType.Hub, deployment.proxy);

    emit HubDeployed(
      msg.sender,
      deployment.proxy,
      deployment.irStrategy,
      authority,
      proxyAdminOwner
    );
    return deployment;
  }

  /// @inheritdoc IHubSpokeFactory
  function deploySpoke(
    bytes32 salt,
    address authority,
    uint16 maxUserReservesLimit,
    address proxyAdminOwner
  ) external returns (SpokeDeployment memory) {
    bytes32 childSalt = _deriveSalt(SPOKE_SALT_DOMAIN, msg.sender, salt);
    SpokeDeployment memory deployment;
    // the factory is the oracle deployer, so it is the only one able to bind it
    deployment.oracle = _deployOracle(childSalt);
    deployment.proxy = _deployProxy(
      childSalt,
      InstanceType.Spoke,
      proxyAdminOwner,
      _spokeInitData(authority, deployment.oracle, maxUserReservesLimit)
    );
    IAaveOracle(deployment.oracle).setSpoke(deployment.proxy);
    _register(InstanceType.Spoke, deployment.proxy);

    emit SpokeDeployed(msg.sender, deployment.proxy, deployment.oracle, authority, proxyAdminOwner);
    return deployment;
  }

  /// @inheritdoc IHubSpokeFactory
  function deployTreasurySpoke(
    bytes32 salt,
    address owner,
    address proxyAdminOwner
  ) external returns (address) {
    address proxy = _deployProxy(
      _deriveSalt(TREASURY_SPOKE_SALT_DOMAIN, msg.sender, salt),
      InstanceType.TreasurySpoke,
      proxyAdminOwner,
      _treasurySpokeInitData(owner)
    );
    _register(InstanceType.TreasurySpoke, proxy);

    emit TreasurySpokeDeployed(msg.sender, proxy, owner, proxyAdminOwner);
    return proxy;
  }

  /// @inheritdoc IHubSpokeFactory
  function deployTokenizationSpoke(
    bytes32 salt,
    address hub,
    address underlying,
    string calldata name,
    string calldata symbol,
    address proxyAdminOwner
  ) external returns (address) {
    require(
      _tokenizationSpokes[msg.sender][hub][underlying] == address(0),
      TokenizationSpokeAlreadyDeployed()
    );
    address proxy = _deployProxy(
      _deriveSalt(TOKENIZATION_SPOKE_SALT_DOMAIN, msg.sender, salt),
      InstanceType.TokenizationSpoke,
      proxyAdminOwner,
      _tokenizationSpokeInitData(hub, underlying, name, symbol)
    );
    _tokenizationSpokes[msg.sender][hub][underlying] = proxy;
    _register(InstanceType.TokenizationSpoke, proxy);

    emit TokenizationSpokeDeployed(msg.sender, proxy, hub, underlying, proxyAdminOwner);
    return proxy;
  }

  /// @inheritdoc IHubSpokeFactory
  function predictHub(
    address deployer,
    bytes32 salt,
    address authority,
    address proxyAdminOwner
  ) external view returns (HubDeployment memory) {
    bytes32 childSalt = _deriveSalt(HUB_SALT_DOMAIN, deployer, salt);
    HubDeployment memory deployment;
    deployment.proxy = _computeAddress(
      childSalt,
      _proxyInitCode(_implementations[InstanceType.Hub], proxyAdminOwner, _hubInitData(authority))
    );
    deployment.irStrategy = _computeAddress(childSalt, _irStrategyInitCode(deployment.proxy));
    return deployment;
  }

  /// @inheritdoc IHubSpokeFactory
  function predictSpoke(
    address deployer,
    bytes32 salt,
    address authority,
    uint16 maxUserReservesLimit,
    address proxyAdminOwner
  ) external view returns (SpokeDeployment memory) {
    bytes32 childSalt = _deriveSalt(SPOKE_SALT_DOMAIN, deployer, salt);
    SpokeDeployment memory deployment;
    deployment.oracle = _computeAddress(childSalt, _oracleInitCode());
    deployment.proxy = _computeAddress(
      childSalt,
      _proxyInitCode(
        _implementations[InstanceType.Spoke],
        proxyAdminOwner,
        _spokeInitData(authority, deployment.oracle, maxUserReservesLimit)
      )
    );
    return deployment;
  }

  /// @inheritdoc IHubSpokeFactory
  function predictTreasurySpoke(
    address deployer,
    bytes32 salt,
    address owner,
    address proxyAdminOwner
  ) external view returns (address) {
    return
      _computeAddress(
        _deriveSalt(TREASURY_SPOKE_SALT_DOMAIN, deployer, salt),
        _proxyInitCode(
          _implementations[InstanceType.TreasurySpoke],
          proxyAdminOwner,
          _treasurySpokeInitData(owner)
        )
      );
  }

  /// @inheritdoc IHubSpokeFactory
  function predictTokenizationSpoke(
    address deployer,
    bytes32 salt,
    address hub,
    address underlying,
    string calldata name,
    string calldata symbol,
    address proxyAdminOwner
  ) external view returns (address) {
    return
      _computeAddress(
        _deriveSalt(TOKENIZATION_SPOKE_SALT_DOMAIN, deployer, salt),
        _proxyInitCode(
          _implementations[InstanceType.TokenizationSpoke],
          proxyAdminOwner,
          _tokenizationSpokeInitData(hub, underlying, name, symbol)
        )
      );
  }

  /// @inheritdoc IHubSpokeFactory
  function getImplementation(InstanceType instanceType) external view returns (address) {
    return _implementations[instanceType];
  }

  /// @inheritdoc IHubSpokeFactory
  function getInstances(
    address deployer,
    InstanceType instanceType
  ) external view returns (address[] memory) {
    return _instances[deployer][instanceType];
  }

  /// @inheritdoc IHubSpokeFactory
  function getInstanceInfo(address instance) external view returns (InstanceInfo memory) {
    return _instanceInfo[instance];
  }

  /// @inheritdoc IHubSpokeFactory
  function getTokenizationSpoke(
    address deployer,
    address hub,
    address underlying
  ) external view returns (address) {
    return _tokenizationSpokes[deployer][hub][underlying];
  }

  function _setImplementation(InstanceType instanceType, address implementation) internal {
    require(_isValidImplementation(instanceType, implementation), InvalidImplementation());
    _implementations[instanceType] = implementation;
    emit ImplementationUpdated(instanceType, implementation);
  }

  function _register(InstanceType instanceType, address instance) internal {
    _instances[msg.sender][instanceType].push(instance);
    _instanceInfo[instance] = InstanceInfo({deployer: msg.sender, instanceType: instanceType});
  }

  function _deployProxy(
    bytes32 salt,
    InstanceType instanceType,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (address) {
    address implementation = _implementations[instanceType];
    _checkSaltUnused(salt, _proxyInitCode(implementation, proxyAdminOwner, initData));
    return
      address(
        new TransparentUpgradeableProxy{salt: salt}(implementation, proxyAdminOwner, initData)
      );
  }

  function _deployIrStrategy(bytes32 salt, address hub) internal returns (address) {
    _checkSaltUnused(salt, _irStrategyInitCode(hub));
    return address(new AssetInterestRateStrategy{salt: salt}(hub));
  }

  function _deployOracle(bytes32 salt) internal returns (address) {
    _checkSaltUnused(salt, _oracleInitCode());
    return address(new AaveOracle{salt: salt}(ORACLE_DECIMALS));
  }

  /// @dev Reverts when the salt maps to an address already in use, instead of letting the CREATE2 collision burn
  /// all the gas forwarded to it.
  function _checkSaltUnused(bytes32 salt, bytes memory initCode) internal view {
    require(_computeAddress(salt, initCode).code.length == 0, SaltAlreadyUsed());
  }

  /// @dev Returns whether `implementation` matches the revision and type expected for `instanceType`.
  function _isValidImplementation(
    InstanceType instanceType,
    address implementation
  ) internal view returns (bool) {
    if (instanceType == InstanceType.Hub) {
      return IHubInstance(implementation).HUB_REVISION() == HUB_REVISION;
    }
    if (instanceType == InstanceType.Spoke) {
      return
        ISpokeInstance(implementation).SPOKE_REVISION() == SPOKE_REVISION &&
        _domainNameHash(implementation) == SPOKE_DOMAIN_NAME_HASH;
    }
    if (instanceType == InstanceType.TreasurySpoke) {
      return
        ITreasurySpokeInstance(implementation).SPOKE_REVISION() == TREASURY_SPOKE_REVISION &&
        ITreasurySpokeInstance(implementation).owner() == address(0);
    }
    if (instanceType == InstanceType.TokenizationSpoke) {
      return
        ITokenizationSpokeInstance(implementation).SPOKE_REVISION() ==
          TOKENIZATION_SPOKE_REVISION &&
        _domainNameHash(implementation) == TOKENIZATION_SPOKE_DOMAIN_NAME_HASH;
    }
    return false;
  }

  function _domainNameHash(address implementation) internal view returns (bytes32) {
    (, string memory name, , , , , ) = IERC5267(implementation).eip712Domain();
    return keccak256(bytes(name));
  }

  function _computeAddress(bytes32 salt, bytes memory initCode) internal view returns (address) {
    return
      address(
        uint160(
          uint256(
            keccak256(abi.encodePacked(CREATE2_PREFIX, address(this), salt, keccak256(initCode)))
          )
        )
      );
  }

  function _proxyInitCode(
    address implementation,
    address proxyAdminOwner,
    bytes memory initData
  ) internal pure returns (bytes memory) {
    return
      abi.encodePacked(
        type(TransparentUpgradeableProxy).creationCode,
        abi.encode(implementation, proxyAdminOwner, initData)
      );
  }

  function _irStrategyInitCode(address hub) internal pure returns (bytes memory) {
    return abi.encodePacked(type(AssetInterestRateStrategy).creationCode, abi.encode(hub));
  }

  function _oracleInitCode() internal pure returns (bytes memory) {
    return abi.encodePacked(type(AaveOracle).creationCode, abi.encode(ORACLE_DECIMALS));
  }

  function _hubInitData(address authority) internal pure returns (bytes memory) {
    return abi.encodeCall(IHubInstance.initialize, (authority));
  }

  function _spokeInitData(
    address authority,
    address oracle,
    uint16 maxUserReservesLimit
  ) internal pure returns (bytes memory) {
    return abi.encodeCall(ISpokeInstance.initialize, (authority, oracle, maxUserReservesLimit));
  }

  function _treasurySpokeInitData(address owner) internal pure returns (bytes memory) {
    return abi.encodeCall(ITreasurySpokeInstance.initialize, (owner));
  }

  function _tokenizationSpokeInitData(
    address hub,
    address underlying,
    string calldata name,
    string calldata symbol
  ) internal pure returns (bytes memory) {
    return abi.encodeCall(ITokenizationSpokeInstance.initialize, (hub, underlying, name, symbol));
  }

  /// @dev Binds the instance type and the caller into the salt.
  function _deriveSalt(
    bytes32 domain,
    address deployer,
    bytes32 salt
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(domain, deployer, salt));
  }
}
