// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';

import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {ProxyAdmin} from 'src/dependencies/openzeppelin/ProxyAdmin.sol';
import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title AaveV4BabylonVerification
/// @author Aave Labs
/// @notice Read-only checks of a Babylon market against its config, reverting on the first mismatch.
/// @dev The role end state follows Ethereum with every governance holder collapsed into `admin`:
///
/// | role                                | holder                |
/// | ----------------------------------- | --------------------- |
/// | 0   ACCESS_MANAGER_ADMIN            | admin                 |
/// | 101 HUB_CONFIGURATOR_ROLE           | the HubConfigurator   |
/// | 200 HUB_CONFIGURATOR_DOMAIN_ADMIN   | admin                 |
/// | 301 SPOKE_CONFIGURATOR_ROLE         | the SpokeConfigurator |
/// | 400 SPOKE_CONFIGURATOR_DOMAIN_ADMIN | admin                 |
/// | every other role                    | nobody                |
library AaveV4BabylonVerification {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @dev ERC-1967 admin slot, `bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)`.
  bytes32 internal constant ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
  /// @dev ERC-1967 implementation slot, `bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)`.
  bytes32 internal constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  /// @notice Reverts unless every deployed contract exists and is wired to the others as configured.
  /// @param config The Babylon market config.
  /// @param deployment The deployed Babylon market.
  function verifyDeployment(
    AaveV4BabylonConfig.Config memory config,
    AaveV4BabylonConfig.Deployment memory deployment
  ) internal view {
    address accessManager = deployment.accessManager;
    _requireCode(accessManager, 'access manager code');
    _requireCode(deployment.treasurySpoke, 'treasury spoke code');
    _requireCode(deployment.oracle, 'oracle code');
    require(
      IAccessManaged(deployment.hubConfigurator).authority() == accessManager,
      'hub configurator authority'
    );
    require(
      IAccessManaged(deployment.spokeConfigurator).authority() == accessManager,
      'spoke configurator authority'
    );

    for (uint256 i; i < deployment.hubs.length; ++i) {
      require(IAccessManaged(deployment.hubs[i]).authority() == accessManager, 'hub authority');
      require(
        _implementation(deployment.hubs[i]) == deployment.hubImplementations[i],
        'hub implementation'
      );
      require(
        IAssetInterestRateStrategy(deployment.irStrategies[i]).HUB() == deployment.hubs[i],
        'ir strategy hub'
      );
    }

    IBabylonSpoke babylonSpoke = IBabylonSpoke(deployment.babylonSpoke);
    require(
      IAccessManaged(deployment.babylonSpoke).authority() == accessManager,
      'babylon spoke authority'
    );
    require(
      _implementation(deployment.babylonSpoke) == deployment.babylonSpokeImplementation,
      'babylon spoke implementation'
    );
    require(ISpoke(deployment.babylonSpoke).ORACLE() == deployment.oracle, 'babylon spoke oracle');
    require(IAaveOracle(deployment.oracle).spoke() == deployment.babylonSpoke, 'oracle spoke');
    require(babylonSpoke.LIQUIDATION_MANAGER() == config.liquidationManager, 'liquidation manager');
    require(
      babylonSpoke.MANAGED_COLLATERAL_RESERVE_ID() == config.managedCollateralReserveId,
      'managed collateral reserve id'
    );
  }

  /// @notice Reverts unless every role holds exactly its end-state members.
  /// @dev Exact member lists also prove the deployer holds no role, since `admin` is not the deployer.
  /// @param deployment The deployed Babylon market.
  /// @param admin The address the market is handed over to.
  function verifyRoles(
    AaveV4BabylonConfig.Deployment memory deployment,
    address admin
  ) internal view {
    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(deployment.accessManager);
    _requireOnlyMember(accessManager, Roles.ACCESS_MANAGER_ADMIN_ROLE, admin);
    _requireOnlyMember(accessManager, Roles.HUB_CONFIGURATOR_ROLE, deployment.hubConfigurator);
    _requireOnlyMember(accessManager, Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, admin);
    _requireOnlyMember(accessManager, Roles.SPOKE_CONFIGURATOR_ROLE, deployment.spokeConfigurator);
    _requireOnlyMember(accessManager, Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, admin);

    uint64[5] memory unheld = [
      Roles.HUB_DOMAIN_ADMIN_ROLE,
      Roles.HUB_FEE_MINTER_ROLE,
      Roles.HUB_DEFICIT_ELIMINATOR_ROLE,
      Roles.SPOKE_DOMAIN_ADMIN_ROLE,
      Roles.SPOKE_USER_POSITION_UPDATER_ROLE
    ];
    for (uint256 i; i < unheld.length; ++i) {
      _requireNoMembers(accessManager, unheld[i]);
    }

    // catches a role outside `Roles` that something granted
    uint256 roleCount = accessManager.getRoleCount();
    for (uint256 i; i < roleCount; ++i) {
      uint64 role = accessManager.getRole(i);
      if (
        role != Roles.HUB_CONFIGURATOR_ROLE &&
        role != Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE &&
        role != Roles.SPOKE_CONFIGURATOR_ROLE &&
        role != Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE
      ) {
        _requireNoMembers(accessManager, role);
      }
    }
  }

  /// @notice Reverts unless every ProxyAdmin in the market is owned by `owner`.
  /// @dev Walks every spoke registered on each Hub asset too, so a spoke connected later is covered.
  /// @param deployment The deployed Babylon market.
  /// @param owner The expected owner of every ProxyAdmin.
  function verifyProxyAdmins(
    AaveV4BabylonConfig.Deployment memory deployment,
    address owner
  ) internal view {
    _requireProxyAdminOwner(deployment.babylonSpoke, owner);
    _requireProxyAdminOwner(deployment.treasurySpoke, owner);
    for (uint256 i; i < deployment.hubs.length; ++i) {
      IHub hub = IHub(deployment.hubs[i]);
      _requireProxyAdminOwner(address(hub), owner);
      uint256 assetCount = hub.getAssetCount();
      for (uint256 assetId; assetId < assetCount; ++assetId) {
        uint256 spokeCount = hub.getSpokeCount(assetId);
        for (uint256 j; j < spokeCount; ++j) {
          _requireProxyAdminOwner(hub.getSpokeAddress(assetId, j), owner);
        }
      }
    }
  }

  /// @notice Reverts unless the TreasurySpoke is owned by `owner`, or, if `allowPending`, has
  /// `owner` as pending owner.
  /// @param deployment The deployed Babylon market.
  /// @param owner The expected TreasurySpoke owner.
  /// @param allowPending Whether an ownership transfer that is not accepted yet passes.
  function verifyTreasurySpokeOwner(
    AaveV4BabylonConfig.Deployment memory deployment,
    address owner,
    bool allowPending
  ) internal view {
    Ownable2StepUpgradeable treasurySpoke = Ownable2StepUpgradeable(deployment.treasurySpoke);
    if (treasurySpoke.owner() == owner) {
      require(treasurySpoke.pendingOwner() == address(0), 'treasury spoke pending owner');
      return;
    }
    require(allowPending && treasurySpoke.pendingOwner() == owner, 'treasury spoke owner');
  }

  /// @notice Reverts unless the Hubs and the BabylonSpoke hold exactly the configured market.
  /// @param deployment The deployed Babylon market.
  /// @param marketConfig The configured market.
  function verifyMarketConfig(
    AaveV4BabylonConfig.Deployment memory deployment,
    AaveV4BabylonConfig.MarketConfig memory marketConfig
  ) internal view {
    ISpoke spoke = ISpoke(deployment.babylonSpoke);
    require(spoke.getReserveCount() == marketConfig.reserves.length, 'reserve count');
    for (uint256 i; i < deployment.hubs.length; ++i) {
      require(
        IHub(deployment.hubs[i]).getAssetCount() == _listingCount(marketConfig, deployment.hubs[i]),
        'hub asset count'
      );
    }

    for (uint256 i; i < marketConfig.reserves.length; ++i) {
      _verifyReserve({deployment: deployment, listing: marketConfig.reserves[i], reserveId: i});
    }

    require(
      keccak256(abi.encode(spoke.getLiquidationConfig())) ==
        keccak256(abi.encode(marketConfig.liquidationConfig)),
      'liquidation config'
    );
  }

  function _verifyReserve(
    AaveV4BabylonConfig.Deployment memory deployment,
    AaveV4BabylonConfig.ReserveListing memory listing,
    uint256 reserveId
  ) private view {
    ISpoke spoke = ISpoke(deployment.babylonSpoke);
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    require(address(reserve.hub) == listing.hub, 'reserve hub');
    require(reserve.underlying == listing.underlying, 'reserve underlying');
    require(spoke.getReserveId(listing.hub, reserve.assetId) == reserveId, 'reserve id');
    require(
      IAaveOracle(deployment.oracle).getReserveSource(reserveId) == listing.priceSource,
      'reserve price source'
    );
    require(
      keccak256(abi.encode(spoke.getReserveConfig(reserveId))) ==
        keccak256(abi.encode(listing.reserveConfig)),
      'reserve config'
    );
    require(
      keccak256(abi.encode(spoke.getDynamicReserveConfig(reserveId, reserve.dynamicConfigKey))) ==
        keccak256(abi.encode(listing.dynamicConfig)),
      'dynamic reserve config'
    );

    IHub hub = IHub(listing.hub);
    IHub.Asset memory asset = hub.getAsset(reserve.assetId);
    require(asset.underlying == listing.underlying, 'asset underlying');
    require(asset.feeReceiver == deployment.treasurySpoke, 'asset fee receiver');
    require(asset.liquidityFee == listing.liquidityFee, 'asset liquidity fee');
    require(asset.irStrategy == listing.irStrategy, 'asset ir strategy');
    require(asset.reinvestmentController == address(0), 'asset reinvestment controller');
    require(
      keccak256(
        abi.encode(
          IAssetInterestRateStrategy(listing.irStrategy).getInterestRateData(reserve.assetId)
        )
      ) == keccak256(abi.encode(listing.irData)),
      'asset ir data'
    );

    // the BabylonSpoke and the TreasurySpoke, added by `addAsset` as fee receiver
    require(hub.getSpokeCount(reserve.assetId) == 2, 'asset spoke count');
    require(
      keccak256(abi.encode(hub.getSpokeConfig(reserve.assetId, deployment.babylonSpoke))) ==
        keccak256(abi.encode(listing.spokeConfig)),
      'babylon spoke config'
    );
    require(
      keccak256(abi.encode(hub.getSpokeConfig(reserve.assetId, deployment.treasurySpoke))) ==
        keccak256(
          abi.encode(
            IHub.SpokeConfig({
              addCap: type(uint40).max,
              drawCap: 0,
              riskPremiumThreshold: 0,
              active: true,
              halted: false
            })
          )
        ),
      'treasury spoke config'
    );
  }

  function _listingCount(
    AaveV4BabylonConfig.MarketConfig memory marketConfig,
    address hub
  ) private pure returns (uint256 count) {
    for (uint256 i; i < marketConfig.reserves.length; ++i) {
      if (marketConfig.reserves[i].hub == hub) {
        ++count;
      }
    }
  }

  function _requireOnlyMember(
    IAccessManagerEnumerable accessManager,
    uint64 role,
    address account
  ) private view {
    (bool isMember, ) = accessManager.hasRole(role, account);
    require(
      isMember && accessManager.getRoleMemberCount(role) == 1,
      string.concat('unexpected role members: ', vm.toString(role))
    );
  }

  function _requireNoMembers(IAccessManagerEnumerable accessManager, uint64 role) private view {
    require(
      accessManager.getRoleMemberCount(role) == 0,
      string.concat('unexpected role members: ', vm.toString(role))
    );
  }

  function _requireProxyAdminOwner(address proxy, address owner) private view {
    address proxyAdmin = address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));
    require(proxyAdmin != address(0), 'not a transparent proxy');
    require(ProxyAdmin(proxyAdmin).owner() == owner, 'proxy admin owner');
  }

  function _requireCode(address target, string memory what) private view {
    require(target.code.length > 0, what);
  }

  function _implementation(address proxy) private view returns (address) {
    return address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
  }
}
