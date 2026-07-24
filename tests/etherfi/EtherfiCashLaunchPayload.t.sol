// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/config-engine/BaseConfigEngine.t.sol';

import {EtherfiCashLaunchPayload} from 'src/etherfi/EtherfiCashLaunchPayload.sol';
import {EtherfiCashActivationPayload} from 'src/etherfi/EtherfiCashActivationPayload.sol';

/// @dev Simulates the full ether.fi Cash launch payload through the production governance
/// topology (PayloadsController -> Executor.executeTransaction -> delegatecall payload
/// -> delegatecall engine) against a locally deployed Aave V4 instance, and asserts every
/// resulting hub/spoke config matches the launch parameter sheet.
contract EtherfiCashLaunchPayloadTest is BaseConfigEngineTest {
  uint256 internal constant NUM_ASSETS = 19;

  address internal OPERATOR_SAFE = makeAddr('OPERATOR_SAFE');

  EtherfiCashLaunchPayload internal payload;

  TestnetERC20[NUM_ASSETS] internal tokens;
  MockPriceFeed[NUM_ASSETS] internal feeds;

  function setUp() public override {
    super.setUp();

    string[NUM_ASSETS] memory symbols = [
      'USDC',
      'USDT',
      'EURC',
      'frxUSD',
      'cWETH', // fresh mock; the env's WETH9 is already listed in the test setup
      'weETH',
      'eBTC',
      'eUSD',
      'ETHFI',
      'sETHFI',
      'OP',
      'WHYPE',
      'beHYPE',
      'liquidETH',
      'liquidBTC',
      'liquidUSD',
      'liquidRESERVE',
      'weEUR',
      'liquidRWA'
    ];
    uint8[NUM_ASSETS] memory decimalsList = [
      uint8(6),
      6,
      6,
      18,
      18,
      18,
      8,
      18,
      18,
      18,
      18,
      18,
      18,
      18,
      8,
      6,
      6,
      6,
      6
    ];

    for (uint256 i; i < NUM_ASSETS; i++) {
      tokens[i] = new TestnetERC20(symbols[i], symbols[i], decimalsList[i]);
      feeds[i] = new MockPriceFeed(8, string.concat(symbols[i], '/USD'), 1e8);
    }

    payload = new EtherfiCashLaunchPayload(_instanceAddresses(), _assetAddresses());

    // in production the Owner Safe (played here by the executor) holds the AccessManager admin
    // role and the configurator domain-admin roles; the payload executes with its identity
    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(executor), 0);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(executor), 0);
    accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(executor), 0);
    vm.stopPrank();
  }

  function _instanceAddresses()
    internal
    view
    returns (EtherfiCashLaunchPayload.InstanceAddresses memory)
  {
    return
      EtherfiCashLaunchPayload.InstanceAddresses({
        configEngine: address(engine),
        hubConfigurator: address(hubConfigurator),
        hub: address(hub1()),
        spokeConfigurator: address(spokeConfigurator),
        cashSpoke: address(spoke1()),
        irStrategy: address(irStrategy1()),
        feeReceiver: FEE_RECEIVER,
        accessManager: address(accessManager),
        ownerSafe: address(executor), // the executor plays the Owner Safe in this topology
        operatorSafe: OPERATOR_SAFE
      });
  }

  function _assetAddresses()
    internal
    view
    returns (EtherfiCashLaunchPayload.AssetAddresses memory)
  {
    return
      EtherfiCashLaunchPayload.AssetAddresses({
        usdc: address(tokens[0]),
        usdcFeed: address(feeds[0]),
        usdt: address(tokens[1]),
        usdtFeed: address(feeds[1]),
        eurc: address(tokens[2]),
        eurcFeed: address(feeds[2]),
        frxUsd: address(tokens[3]),
        frxUsdFeed: address(feeds[3]),
        weth: address(tokens[4]),
        wethFeed: address(feeds[4]),
        weEth: address(tokens[5]),
        weEthFeed: address(feeds[5]),
        eBtc: address(tokens[6]),
        eBtcFeed: address(feeds[6]),
        eUsd: address(tokens[7]),
        eUsdFeed: address(feeds[7]),
        ethfi: address(tokens[8]),
        ethfiFeed: address(feeds[8]),
        sEthfi: address(tokens[9]),
        sEthfiFeed: address(feeds[9]),
        op: address(tokens[10]),
        opFeed: address(feeds[10]),
        wHype: address(tokens[11]),
        wHypeFeed: address(feeds[11]),
        beHype: address(tokens[12]),
        beHypeFeed: address(feeds[12]),
        liquidEth: address(tokens[13]),
        liquidEthFeed: address(feeds[13]),
        liquidBtc: address(tokens[14]),
        liquidBtcFeed: address(feeds[14]),
        liquidUsd: address(tokens[15]),
        liquidUsdFeed: address(feeds[15]),
        liquidReserve: address(tokens[16]),
        liquidReserveFeed: address(feeds[16]),
        weEur: address(tokens[17]),
        weEurFeed: address(feeds[17]),
        liquidRwa: address(tokens[18]),
        liquidRwaFeed: address(feeds[18])
      });
  }

  function _executePayload() internal {
    vm.prank(PAYLOADS_CONTROLLER);
    executor.executeTransaction(address(payload), abi.encodeCall(AaveV4Payload.execute, ()));
  }

  function test_specs_fullRoster() public view {
    EtherfiCashLaunchPayload.AssetSpec[] memory specs = payload.getAssetSpecs();
    assertEq(specs.length, NUM_ASSETS);

    uint256 borrowables;
    for (uint256 i; i < specs.length; i++) {
      if (specs[i].borrowable) borrowables++;
    }
    // final parameter sheet: only USDC and WETH borrowable; everything else collateral-only
    assertEq(borrowables, 2);
  }

  function test_execute_listsAllAssetsOnHub() public {
    _executePayload();

    EtherfiCashLaunchPayload.AssetSpec[] memory specs = payload.getAssetSpecs();
    for (uint256 i; i < specs.length; i++) {
      uint256 assetId = hub1().getAssetId(specs[i].underlying);

      IHub.Asset memory asset = hub1().getAsset(assetId);
      assertEq(asset.liquidityFee, specs[i].liquidityFee, 'liquidity fee mismatch');

      IAssetInterestRateStrategy.InterestRateData memory ir = irStrategy1().getInterestRateData(
        assetId
      );
      assertEq(ir.optimalUsageRatio, specs[i].irData.optimalUsageRatio, 'kink mismatch');
      assertEq(ir.baseDrawnRate, specs[i].irData.baseDrawnRate, 'base rate mismatch');
      assertEq(
        ir.rateGrowthBeforeOptimal,
        specs[i].irData.rateGrowthBeforeOptimal,
        'slope1 mismatch'
      );
      assertEq(
        ir.rateGrowthAfterOptimal,
        specs[i].irData.rateGrowthAfterOptimal,
        'slope2 mismatch'
      );
    }
  }

  function test_execute_registersCashSpokeWithCaps() public {
    _executePayload();

    EtherfiCashLaunchPayload.AssetSpec[] memory specs = payload.getAssetSpecs();
    for (uint256 i; i < specs.length; i++) {
      uint256 assetId = hub1().getAssetId(specs[i].underlying);
      IHub.SpokeConfig memory config = hub1().getSpokeConfig(assetId, address(spoke1()));

      assertFalse(config.active, 'spoke must register DORMANT (two-phase launch)');
      assertFalse(config.halted, 'spoke halted for asset');
      assertEq(config.addCap, specs[i].addCap, 'add cap mismatch');
      assertEq(config.drawCap, specs[i].drawCap, 'draw cap mismatch');
      assertEq(config.riskPremiumThreshold, 0, 'risk premium threshold not zero');
    }
  }

  function test_execute_listsReservesWithRiskParams() public {
    _executePayload();

    EtherfiCashLaunchPayload.AssetSpec[] memory specs = payload.getAssetSpecs();
    for (uint256 i; i < specs.length; i++) {
      uint256 assetId = hub1().getAssetId(specs[i].underlying);
      uint256 reserveId = spoke1().getReserveId(address(hub1()), assetId);

      ISpoke.ReserveConfig memory config = spoke1().getReserveConfig(reserveId);
      assertEq(config.collateralRisk, 0, 'collateral risk not zero');
      assertFalse(config.paused, 'reserve paused');
      assertFalse(config.frozen, 'reserve frozen');
      assertEq(config.borrowable, specs[i].borrowable, 'borrowable flag mismatch');
      assertTrue(config.receiveSharesEnabled, 'receiveSharesEnabled not set');

      ISpoke.DynamicReserveConfig memory dyn = spoke1().getDynamicReserveConfig(
        reserveId,
        uint32(DYNAMIC_CONFIG_KEY)
      );
      assertEq(dyn.collateralFactor, specs[i].collateralFactor, 'collateral factor mismatch');
      assertEq(dyn.maxLiquidationBonus, specs[i].maxLiquidationBonus, 'max liq bonus mismatch');
      assertEq(dyn.liquidationFee, specs[i].liquidationFee, 'liquidation fee mismatch');
    }
  }

  function test_activation_flipsAllSpokesActive() public {
    _executePayload();

    EtherfiCashActivationPayload activation = new EtherfiCashActivationPayload(
      hub1(),
      hubConfigurator
    );
    vm.prank(PAYLOADS_CONTROLLER);
    executor.executeTransaction(
      address(activation),
      abi.encodeCall(EtherfiCashActivationPayload.execute, ())
    );

    EtherfiCashLaunchPayload.AssetSpec[] memory specs = payload.getAssetSpecs();
    for (uint256 i; i < specs.length; i++) {
      uint256 assetId = hub1().getAssetId(specs[i].underlying);
      // the activation enumerates every spoke on every asset — check them all
      uint256 spokeCount = hub1().getSpokeCount(assetId);
      for (uint256 spokeId; spokeId < spokeCount; spokeId++) {
        address spokeAddress = hub1().getSpokeAddress(assetId, spokeId);
        assertTrue(
          hub1().getSpokeConfig(assetId, spokeAddress).active,
          'spoke not active after activation'
        );
      }
    }
  }

  function test_execute_grantsOperatorRoles() public {
    _executePayload();

    // both Safes hold the two new granular roles
    (bool isMember, ) = accessManager.hasRole(payload.HUB_CAPS_OPERATOR_ROLE(), OPERATOR_SAFE);
    assertTrue(isMember, 'operator safe missing hub caps role');
    (isMember, ) = accessManager.hasRole(payload.SPOKE_RISK_OPERATOR_ROLE(), OPERATOR_SAFE);
    assertTrue(isMember, 'operator safe missing spoke risk role');
    (isMember, ) = accessManager.hasRole(payload.HUB_CAPS_OPERATOR_ROLE(), address(executor));
    assertTrue(isMember, 'owner safe missing hub caps role');
    (isMember, ) = accessManager.hasRole(payload.SPOKE_RISK_OPERATOR_ROLE(), address(executor));
    assertTrue(isMember, 'owner safe missing spoke risk role');

    // cap / dynamic-config selectors now map to the granular roles
    assertEq(
      accessManager.getTargetFunctionRole(
        address(hubConfigurator),
        IHubConfigurator.updateSpokeCaps.selector
      ),
      payload.HUB_CAPS_OPERATOR_ROLE()
    );
    assertEq(
      accessManager.getTargetFunctionRole(
        address(hubConfigurator),
        IHubConfigurator.updateSpokeAddCap.selector
      ),
      payload.HUB_CAPS_OPERATOR_ROLE()
    );
    assertEq(
      accessManager.getTargetFunctionRole(
        address(hubConfigurator),
        IHubConfigurator.updateSpokeDrawCap.selector
      ),
      payload.HUB_CAPS_OPERATOR_ROLE()
    );
    assertEq(
      accessManager.getTargetFunctionRole(
        address(spokeConfigurator),
        ISpokeConfigurator.addDynamicReserveConfig.selector
      ),
      payload.SPOKE_RISK_OPERATOR_ROLE()
    );
    assertEq(
      accessManager.getTargetFunctionRole(
        address(spokeConfigurator),
        ISpokeConfigurator.updateDynamicReserveConfig.selector
      ),
      payload.SPOKE_RISK_OPERATOR_ROLE()
    );
  }

  function test_execute_setsLiquidationConfig() public {
    _executePayload();

    ISpoke.LiquidationConfig memory config = spoke1().getLiquidationConfig();
    assertEq(config.targetHealthFactor, payload.TARGET_HEALTH_FACTOR());
    assertEq(config.healthFactorForMaxBonus, payload.HEALTH_FACTOR_FOR_MAX_BONUS());
  }

  function test_unsetAssetIsSkipped() public {
    EtherfiCashLaunchPayload.AssetAddresses memory assets = _assetAddresses();
    assets.liquidRwa = address(0); // pending deployment at AIP stage

    EtherfiCashLaunchPayload partialPayload = new EtherfiCashLaunchPayload(
      _instanceAddresses(),
      assets
    );
    assertEq(partialPayload.getAssetSpecs().length, NUM_ASSETS - 1);

    vm.prank(PAYLOADS_CONTROLLER);
    executor.executeTransaction(
      address(partialPayload),
      abi.encodeCall(AaveV4Payload.execute, ())
    );

    // skipped asset never touched the hub
    vm.expectRevert();
    hub1().getAssetId(address(tokens[18]));
  }

  function test_constructor_revertsOnMissingInstanceAddress() public {
    EtherfiCashLaunchPayload.InstanceAddresses memory instance = _instanceAddresses();
    instance.cashSpoke = address(0);

    vm.expectRevert(EtherfiCashLaunchPayload.MissingInstanceAddress.selector);
    new EtherfiCashLaunchPayload(instance, _assetAddresses());
  }
}
