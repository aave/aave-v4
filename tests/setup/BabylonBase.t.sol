// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';

/// @dev Extends the base environment with a fourth spoke running the Babylon spoke instance.
/// The spoke mirrors spoke1's reserves and liquidation config, with the managed collateral
/// reserve (wbtc) non-borrowable and fee-free, as expected in production.
abstract contract BabylonBase is Base {
  IBabylonSpoke internal babylonSpoke;
  ISpoke internal spoke4;
  IAaveOracle internal oracle4;
  address internal liquidationManager = makeAddr('liquidationManager');

  function setUp() public virtual override {
    super.setUp();
    _deployBabylonSpoke();
    _configureBabylonSpoke();
  }

  /// @dev Supplies liquidity from a fresh user without registering it as collateral: only the
  /// managed collateral reserve can be registered on the babylon spoke.
  function _openSupplyPositionNoCollateral(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount
  ) internal {
    address user = _makeUser();
    _deal(spoke, reserveId, user, amount);
    SpokeActions.approve({spoke: spoke, reserveId: reserveId, owner: user, amount: UINT256_MAX});
    SpokeActions.supply({
      spoke: spoke,
      reserveId: reserveId,
      caller: user,
      amount: amount,
      onBehalfOf: user
    });
  }

  /// @dev Mirrors `_increaseReserveDebt` without registering the seeded liquidity as collateral.
  function _increaseReserveDebtNoCollateral(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount,
    address user
  ) internal {
    _openSupplyPositionNoCollateral(
      spoke,
      reserveId,
      _max(_hub(spoke, reserveId).previewAddByShares(_reserveAssetId(spoke, reserveId), 1), amount)
    );
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: reserveId,
      caller: user,
      amount: amount,
      onBehalfOf: user
    });
  }

  function _arr(uint256 a) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](1);
    arr[0] = a;
  }

  function _arr(uint256 a, uint256 b) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](2);
    arr[0] = a;
    arr[1] = b;
  }

  function _deployBabylonSpoke() internal {
    vm.startPrank(ADMIN);
    TestTypes.TestSpokeReport memory report = AaveV4TestOrchestration.deployTestSpoke({
      proxyAdminOwner: ADMIN,
      accessManager: address(accessManager),
      spokeBytecode: BytecodeHelper.getBabylonSpokeBytecode(),
      maxUserReservesLimit: DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT,
      // deterministic salt: the spoke address enters signed payloads measured by the gas suite
      salt: keccak256('babylon-spoke')
    });
    AaveV4SpokeRolesProcedure.setupBabylonSpokeAllRoles(address(accessManager), report.spoke);
    accessManager.grantRole(Roles.BABYLON_SPOKE_CONFIGURATOR_ROLE, ADMIN, 0);
    vm.stopPrank();

    spoke4 = ISpoke(report.spoke);
    oracle4 = IAaveOracle(report.aaveOracle);
    babylonSpoke = IBabylonSpoke(report.spoke);
    _spokes.push(spoke4);
    _oracles.push(oracle4);
    vm.label(report.spoke, 'spoke4');
    vm.label(report.aaveOracle, 'oracle4');

    _approveTokenListForBabylonSpoke();
  }

  function _configureBabylonSpoke() internal {
    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_ROLE, address(this), 0);
    accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(this), 0);
    vm.stopPrank();

    AaveV4TestOrchestration.configureHubsSpokes(_getBabylonAddSpokeParams());
    _loadSpokeInfo(
      AaveV4TestOrchestration.configureSpokes(
        _getBabylonLiquidationConfigParams(),
        _getBabylonReserveParams()
      )
    );

    accessManager.renounceRole(Roles.HUB_CONFIGURATOR_ROLE, address(this));
    accessManager.renounceRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(this));

    vm.prank(ADMIN);
    babylonSpoke.updateBabylonLiquidationConfig(liquidationManager, _wbtcReserveId(spoke4));
  }

  function _approveTokenListForBabylonSpoke() internal {
    address[7] memory users = [
      alice,
      bob,
      carol,
      derl,
      LIQUIDATOR,
      TREASURY_ADMIN,
      POSITION_MANAGER
    ];
    for (uint256 i; i < users.length; ++i) {
      vm.startPrank(users[i]);
      tokenList.weth.approve(address(spoke4), UINT256_MAX);
      tokenList.usdx.approve(address(spoke4), UINT256_MAX);
      tokenList.dai.approve(address(spoke4), UINT256_MAX);
      tokenList.wbtc.approve(address(spoke4), UINT256_MAX);
      tokenList.usdy.approve(address(spoke4), UINT256_MAX);
      tokenList.usdz.approve(address(spoke4), UINT256_MAX);
      vm.stopPrank();
    }
  }

  function _getBabylonAddSpokeParams()
    internal
    view
    returns (ConfigData.AddSpokeParams[] memory paramsList)
  {
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: MAX_ALLOWED_SPOKE_CAP,
      drawCap: MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: MAX_ALLOWED_COLLATERAL_RISK
    });
    uint256[5] memory assetIds = [wethAssetId, wbtcAssetId, daiAssetId, usdxAssetId, usdyAssetId];
    paramsList = new ConfigData.AddSpokeParams[](assetIds.length);
    for (uint256 i; i < assetIds.length; ++i) {
      paramsList[i] = ConfigData.AddSpokeParams({
        spoke: address(spoke4),
        hub: address(hub1),
        assetId: assetIds[i],
        config: spokeConfig
      });
    }
  }

  function _getBabylonLiquidationConfigParams()
    internal
    view
    returns (ConfigData.UpdateLiquidationConfigParams[] memory paramsList)
  {
    paramsList = new ConfigData.UpdateLiquidationConfigParams[](1);
    paramsList[0] = ConfigData.UpdateLiquidationConfigParams({
      spoke: address(spoke4),
      config: ISpoke.LiquidationConfig({
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: 0.7e18,
        liquidationBonusFactor: 20_00
      })
    });
  }

  function _getBabylonReserveParams()
    internal
    returns (ConfigData.AddReserveParams[] memory paramsList)
  {
    paramsList = new ConfigData.AddReserveParams[](5);
    paramsList[0] = ConfigData.AddReserveParams({
      spoke: address(spoke4),
      hub: address(hub1),
      assetId: wethAssetId,
      priceSource: _deployMockPriceFeed(spoke4, 2000e8),
      config: _getDefaultReserveConfig(15_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 10_00
      })
    });
    // the managed collateral reserve: non-borrowable, keeping its supply share price at one,
    // and fee-free, as babylon liquidations never charge the liquidation fee
    paramsList[1] = ConfigData.AddReserveParams({
      spoke: address(spoke4),
      hub: address(hub1),
      assetId: wbtcAssetId,
      priceSource: _deployMockPriceFeed(spoke4, 50_000e8),
      config: ISpoke.ReserveConfig({
        paused: false,
        frozen: false,
        borrowable: false,
        receiveSharesEnabled: true,
        collateralRisk: 15_00
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 75_00,
        maxLiquidationBonus: 103_00,
        liquidationFee: 0
      })
    });
    paramsList[2] = ConfigData.AddReserveParams({
      spoke: address(spoke4),
      hub: address(hub1),
      assetId: daiAssetId,
      priceSource: _deployMockPriceFeed(spoke4, 1e8),
      config: _getDefaultReserveConfig(20_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 78_00,
        maxLiquidationBonus: 102_00,
        liquidationFee: 10_00
      })
    });
    paramsList[3] = ConfigData.AddReserveParams({
      spoke: address(spoke4),
      hub: address(hub1),
      assetId: usdxAssetId,
      priceSource: _deployMockPriceFeed(spoke4, 1e8),
      config: _getDefaultReserveConfig(50_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 78_00,
        maxLiquidationBonus: 101_00,
        liquidationFee: 12_00
      })
    });
    paramsList[4] = ConfigData.AddReserveParams({
      spoke: address(spoke4),
      hub: address(hub1),
      assetId: usdyAssetId,
      priceSource: _deployMockPriceFeed(spoke4, 1e8),
      config: _getDefaultReserveConfig(50_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 78_00,
        maxLiquidationBonus: 101_50,
        liquidationFee: 15_00
      })
    });
  }
}
