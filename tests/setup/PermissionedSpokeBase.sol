// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';
import {IPermissionedSpoke} from 'src/spoke/interfaces/IPermissionedSpoke.sol';
import {IEligibilityRegistry} from 'src/spoke/interfaces/IEligibilityRegistry.sol';
import {IEligibilityPolicyGate} from 'src/spoke/interfaces/IEligibilityPolicyGate.sol';
import {EligibilityRegistry} from 'src/spoke/gates/EligibilityRegistry.sol';
import {EligibilityPolicyGate} from 'src/spoke/gates/EligibilityPolicyGate.sol';
import {AuthKind} from 'src/spoke/libraries/AuthKind.sol';

/// @dev Deploys an issuer registry and permissioned spokes on hub1 with three reserves: weth,
/// usdx and dai, in that order, so the reserve ids are the constants below.
abstract contract PermissionedSpokeBase is Base {
  uint256 internal constant P_WETH = 0;
  uint256 internal constant P_USDX = 1;
  uint256 internal constant P_DAI = 2;

  EligibilityRegistry internal registry;
  address internal COMPLIANCE = makeAddr('COMPLIANCE');
  address internal RESERVE_MANAGER = makeAddr('RESERVE_MANAGER');
  address internal CUSTODY = makeAddr('CUSTODY');
  address internal PROXY_ADMIN_OWNER = makeAddr('PROXY_ADMIN_OWNER');

  function setUp() public virtual override {
    super.setUp();
    registry = new EligibilityRegistry(address(accessManager));
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = IEligibilityRegistry.updateEligibility.selector;
    selectors[1] = IEligibilityRegistry.updateReserveManager.selector;
    uint64 complianceRole = 9_001;
    vm.startPrank(ADMIN);
    accessManager.setTargetFunctionRole(address(registry), selectors, complianceRole);
    accessManager.grantRole(complianceRole, COMPLIANCE, 0);
    vm.stopPrank();
  }

  function _gateConfig(
    bool allowOwnerRepay,
    bool allowFrozenExit
  ) internal view returns (IEligibilityPolicyGate.Config memory) {
    return
      IEligibilityPolicyGate.Config({
        registry: address(registry),
        onlyCaller: address(0),
        onlyLiquidator: address(0),
        allowOwnerRepay: allowOwnerRepay,
        allowFrozenExit: allowFrozenExit
      });
  }

  /// @dev Deploys a policy gate with `config` and a permissioned spoke using it.
  function _deployPermissionedSpoke(
    IEligibilityPolicyGate.Config memory config
  ) internal returns (ISpoke) {
    AaveOracle oracle = new AaveOracle(8);
    // deployed from the artifact: the instances are compiled with their own settings
    address implementation = vm.deployCode(
      'src/spoke/instances/PermissionedSpokeInstance.sol:PermissionedSpokeInstance',
      abi.encode(
        address(oracle),
        DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT,
        address(new EligibilityPolicyGate(config))
      )
    );
    return _setUpSpoke(oracle, implementation);
  }

  /// @dev Deploys a canonical spoke with the same reserves, for comparisons.
  function _deployCanonicalSpoke() internal returns (ISpoke) {
    AaveOracle oracle = new AaveOracle(8);
    address implementation = vm.deployCode(
      'src/spoke/instances/SpokeInstance.sol:SpokeInstance',
      abi.encode(address(oracle), DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT)
    );
    return _setUpSpoke(oracle, implementation);
  }

  function _setUpSpoke(AaveOracle oracle, address implementation) internal returns (ISpoke spoke) {
    spoke = ISpoke(
      address(
        new TransparentUpgradeableProxy(
          implementation,
          PROXY_ADMIN_OWNER,
          abi.encodeCall(ISpokeInstance.initialize, (address(accessManager)))
        )
      )
    );
    oracle.setSpoke(address(spoke));
    setUpRoles(hub1, spoke, accessManager);

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: MAX_ALLOWED_SPOKE_CAP,
      drawCap: MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: MAX_ALLOWED_COLLATERAL_RISK
    });
    uint256[3] memory assetIds = [wethAssetId, usdxAssetId, daiAssetId];
    uint256[3] memory prices = [uint256(2000e8), 1e8, 1e8];
    uint16[3] memory collateralFactors = [uint16(80_00), 78_00, 78_00];
    vm.startPrank(ADMIN);
    for (uint256 i; i < assetIds.length; ++i) {
      spoke.addReserve(
        address(hub1),
        assetIds[i],
        _deployMockPriceFeed(spoke, prices[i]),
        _getDefaultReserveConfig(15_00),
        ISpoke.DynamicReserveConfig({
          collateralFactor: collateralFactors[i],
          maxLiquidationBonus: 105_00,
          liquidationFee: 10_00
        })
      );
      hub1.addSpoke(assetIds[i], address(spoke), spokeConfig);
    }
    vm.stopPrank();

    address[8] memory users = [
      alice,
      bob,
      carol,
      LIQUIDATOR,
      POSITION_MANAGER,
      RESERVE_MANAGER,
      CUSTODY,
      COMPLIANCE
    ];
    for (uint256 i; i < users.length; ++i) {
      if (tokenList.usdx.balanceOf(users[i]) == 0) {
        tokenList.usdx.mint(users[i], mintAmount_USDX);
        deal(address(tokenList.weth), users[i], mintAmount_WETH);
      }
      vm.startPrank(users[i]);
      tokenList.weth.approve(address(spoke), UINT256_MAX);
      tokenList.usdx.approve(address(spoke), UINT256_MAX);
      tokenList.dai.approve(address(spoke), UINT256_MAX);
      vm.stopPrank();
    }
  }

  function _setStatus(address account, IEligibilityRegistry.Status status) internal {
    _setStatus(account, status, uint40(block.timestamp + 365 days));
  }

  function _setStatus(
    address account,
    IEligibilityRegistry.Status status,
    uint40 validUntil
  ) internal {
    address[] memory accounts = new address[](1);
    accounts[0] = account;
    vm.prank(COMPLIANCE);
    registry.updateEligibility(accounts, status, validUntil);
  }

  function _setReserveManager(
    ISpoke spoke,
    uint256 reserveId,
    address manager,
    uint8 actions
  ) internal {
    vm.prank(COMPLIANCE);
    registry.updateReserveManager(address(spoke), reserveId, manager, actions);
  }

  function _approvePositionManager(ISpoke spoke, address user, address manager) internal {
    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager(manager, true);
    vm.prank(user);
    spoke.setUserPositionManager(manager, true);
  }
}
