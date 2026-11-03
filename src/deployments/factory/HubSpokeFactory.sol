// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {EIP712Hash} from 'src/spoke/libraries/EIP712Hash.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';
import {IHubInstance} from 'src/deployments/utils/interfaces/IHubInstance.sol';
import {ISpokeInstance} from 'src/deployments/utils/interfaces/ISpokeInstance.sol';
import {ITreasurySpokeInstance} from 'src/deployments/utils/interfaces/ITreasurySpokeInstance.sol';
import {ITokenizationSpokeInstance} from 'src/deployments/utils/interfaces/ITokenizationSpokeInstance.sol';
import {IHubSpokeFactory} from 'src/deployments/factory/interfaces/IHubSpokeFactory.sol';

/// @title HubSpokeFactory
/// @author Aave Labs
/// @notice Deploys Hub, Spoke, TreasurySpoke and TokenizationSpoke instances as proxies to the canonical on-chain
/// implementations.
/// @dev Deployments are permissionless. The caller is bound into every CREATE2 salt, so addresses can't be squatted
/// or front-run. Deployment events record provenance only: a ProxyAdmin can upgrade an instance afterwards.
contract HubSpokeFactory is IHubSpokeFactory {
  bytes32 internal constant HUB_SALT_DOMAIN = keccak256('hub');
  bytes32 internal constant SPOKE_SALT_DOMAIN = keccak256('spoke');
  bytes32 internal constant TREASURY_SPOKE_SALT_DOMAIN = keccak256('treasury-spoke');
  bytes32 internal constant TOKENIZATION_SPOKE_SALT_DOMAIN = keccak256('tokenization-spoke');

  /// @dev Prefix of the CREATE2 address derivation (EIP-1014).
  bytes1 internal constant CREATE2_PREFIX = 0xff;

  /// @dev Revision 1 of the Spoke and the TokenizationSpoke holds per-instance params in implementation immutables.
  uint64 internal constant MIN_SPOKE_REVISION = 2;

  /// @inheritdoc IHubSpokeFactory
  uint8 public constant ORACLE_DECIMALS = DeployConstants.ORACLE_DECIMALS;

  /// @inheritdoc IHubSpokeFactory
  uint16 public constant MAX_USER_RESERVES_LIMIT = DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT;

  /// @inheritdoc IHubSpokeFactory
  address public immutable HUB_IMPLEMENTATION;

  /// @inheritdoc IHubSpokeFactory
  address public immutable SPOKE_IMPLEMENTATION;

  /// @inheritdoc IHubSpokeFactory
  address public immutable TREASURY_SPOKE_IMPLEMENTATION;

  /// @inheritdoc IHubSpokeFactory
  address public immutable TOKENIZATION_SPOKE_IMPLEMENTATION;

  /// @dev Constructor.
  /// @dev `SPOKE_REVISION` is shared by the Spoke, TreasurySpoke and TokenizationSpoke, so each implementation is
  /// also probed with a function only its own type exposes.
  /// @param hubImplementation_ The canonical HubInstance implementation.
  /// @param spokeImplementation_ The canonical SpokeInstance implementation.
  /// @param treasurySpokeImplementation_ The canonical TreasurySpokeInstance implementation.
  /// @param tokenizationSpokeImplementation_ The canonical TokenizationSpokeInstance implementation.
  constructor(
    address hubImplementation_,
    address spokeImplementation_,
    address treasurySpokeImplementation_,
    address tokenizationSpokeImplementation_
  ) {
    require(IHubInstance(hubImplementation_).HUB_REVISION() > 0, InvalidImplementation());
    require(
      ISpokeInstance(spokeImplementation_).SPOKE_REVISION() >= MIN_SPOKE_REVISION &&
        ISpokeInstance(spokeImplementation_).SET_USER_POSITION_MANAGERS_TYPEHASH() ==
          EIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
      InvalidImplementation()
    );
    require(
      ITreasurySpokeInstance(treasurySpokeImplementation_).SPOKE_REVISION() > 0 &&
        ITreasurySpokeInstance(treasurySpokeImplementation_).owner() == address(0),
      InvalidImplementation()
    );
    require(
      ITokenizationSpokeInstance(tokenizationSpokeImplementation_).SPOKE_REVISION() >=
        MIN_SPOKE_REVISION &&
        ITokenizationSpokeInstance(tokenizationSpokeImplementation_).DEPOSIT_TYPEHASH() ==
          EIP712Hash.TOKENIZED_DEPOSIT_TYPEHASH,
      InvalidImplementation()
    );
    HUB_IMPLEMENTATION = hubImplementation_;
    SPOKE_IMPLEMENTATION = spokeImplementation_;
    TREASURY_SPOKE_IMPLEMENTATION = treasurySpokeImplementation_;
    TOKENIZATION_SPOKE_IMPLEMENTATION = tokenizationSpokeImplementation_;
  }

  /// @inheritdoc IHubSpokeFactory
  function deployHub(
    bytes32 salt,
    address authority,
    address proxyAdminOwner
  ) external returns (HubDeployment memory deployment) {
    bytes32 childSalt = _deriveSalt(HUB_SALT_DOMAIN, msg.sender, salt);
    deployment.proxy = _deployProxy(
      childSalt,
      HUB_IMPLEMENTATION,
      proxyAdminOwner,
      _hubInitData(authority)
    );
    deployment.irStrategy = _create2(childSalt, _irStrategyInitCode(deployment.proxy));

    emit HubDeployed(
      msg.sender,
      deployment.proxy,
      deployment.irStrategy,
      authority,
      proxyAdminOwner
    );
  }

  /// @inheritdoc IHubSpokeFactory
  function deploySpoke(
    bytes32 salt,
    address authority,
    address proxyAdminOwner
  ) external returns (SpokeDeployment memory deployment) {
    bytes32 childSalt = _deriveSalt(SPOKE_SALT_DOMAIN, msg.sender, salt);
    // the factory is the oracle deployer, so it is the only one able to bind it
    deployment.oracle = _create2(childSalt, _oracleInitCode());
    deployment.proxy = _deployProxy(
      childSalt,
      SPOKE_IMPLEMENTATION,
      proxyAdminOwner,
      _spokeInitData(authority, deployment.oracle)
    );
    IAaveOracle(deployment.oracle).setSpoke(deployment.proxy);

    emit SpokeDeployed(msg.sender, deployment.proxy, deployment.oracle, authority, proxyAdminOwner);
  }

  /// @inheritdoc IHubSpokeFactory
  function deployTreasurySpoke(
    bytes32 salt,
    address owner,
    address proxyAdminOwner
  ) external returns (address proxy) {
    proxy = _deployProxy(
      _deriveSalt(TREASURY_SPOKE_SALT_DOMAIN, msg.sender, salt),
      TREASURY_SPOKE_IMPLEMENTATION,
      proxyAdminOwner,
      _treasurySpokeInitData(owner)
    );

    emit TreasurySpokeDeployed(msg.sender, proxy, owner, proxyAdminOwner);
  }

  /// @inheritdoc IHubSpokeFactory
  function deployTokenizationSpoke(
    bytes32 salt,
    address hub,
    address underlying,
    string calldata name,
    string calldata symbol,
    address proxyAdminOwner
  ) external returns (address proxy) {
    proxy = _deployProxy(
      _deriveSalt(TOKENIZATION_SPOKE_SALT_DOMAIN, msg.sender, salt),
      TOKENIZATION_SPOKE_IMPLEMENTATION,
      proxyAdminOwner,
      _tokenizationSpokeInitData(hub, underlying, name, symbol)
    );

    emit TokenizationSpokeDeployed(msg.sender, proxy, hub, underlying, proxyAdminOwner);
  }

  /// @inheritdoc IHubSpokeFactory
  function predictHub(
    address deployer,
    bytes32 salt,
    address authority,
    address proxyAdminOwner
  ) external view returns (HubDeployment memory deployment) {
    bytes32 childSalt = _deriveSalt(HUB_SALT_DOMAIN, deployer, salt);
    deployment.proxy = _predictProxy(
      childSalt,
      HUB_IMPLEMENTATION,
      proxyAdminOwner,
      _hubInitData(authority)
    );
    deployment.irStrategy = _computeAddress(childSalt, _irStrategyInitCode(deployment.proxy));
  }

  /// @inheritdoc IHubSpokeFactory
  function predictSpoke(
    address deployer,
    bytes32 salt,
    address authority,
    address proxyAdminOwner
  ) external view returns (SpokeDeployment memory deployment) {
    bytes32 childSalt = _deriveSalt(SPOKE_SALT_DOMAIN, deployer, salt);
    deployment.oracle = _computeAddress(childSalt, _oracleInitCode());
    deployment.proxy = _predictProxy(
      childSalt,
      SPOKE_IMPLEMENTATION,
      proxyAdminOwner,
      _spokeInitData(authority, deployment.oracle)
    );
  }

  /// @inheritdoc IHubSpokeFactory
  function predictTreasurySpoke(
    address deployer,
    bytes32 salt,
    address owner,
    address proxyAdminOwner
  ) external view returns (address) {
    return
      _predictProxy(
        _deriveSalt(TREASURY_SPOKE_SALT_DOMAIN, deployer, salt),
        TREASURY_SPOKE_IMPLEMENTATION,
        proxyAdminOwner,
        _treasurySpokeInitData(owner)
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
      _predictProxy(
        _deriveSalt(TOKENIZATION_SPOKE_SALT_DOMAIN, deployer, salt),
        TOKENIZATION_SPOKE_IMPLEMENTATION,
        proxyAdminOwner,
        _tokenizationSpokeInitData(hub, underlying, name, symbol)
      );
  }

  function _deployProxy(
    bytes32 salt,
    address implementation,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (address) {
    return _create2(salt, _proxyInitCode(implementation, proxyAdminOwner, initData));
  }

  function _predictProxy(
    bytes32 salt,
    address implementation,
    address proxyAdminOwner,
    bytes memory initData
  ) internal view returns (address) {
    return _computeAddress(salt, _proxyInitCode(implementation, proxyAdminOwner, initData));
  }

  /// @dev Reverts when the salt maps to an address already in use, instead of letting the CREATE2 collision burn
  /// all the gas forwarded to it. Bubbles up constructor reverts.
  function _create2(bytes32 salt, bytes memory initCode) internal returns (address deployed) {
    require(_computeAddress(salt, initCode).code.length == 0, SaltAlreadyUsed());
    assembly ('memory-safe') {
      deployed := create2(0, add(initCode, 0x20), mload(initCode), salt)
      if iszero(deployed) {
        let ptr := mload(0x40)
        returndatacopy(ptr, 0, returndatasize())
        revert(ptr, returndatasize())
      }
    }
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

  function _spokeInitData(address authority, address oracle) internal pure returns (bytes memory) {
    return abi.encodeCall(ISpokeInstance.initialize, (authority, oracle, MAX_USER_RESERVES_LIMIT));
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
