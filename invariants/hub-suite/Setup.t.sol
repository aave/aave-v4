// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Libraries
import {ActorsUtils} from '../shared/utils/ActorsUtils.sol';
import {Constants} from 'tests/Constants.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import {Actor} from '../shared/utils/Actor.sol';

// Test Contracts
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

// Contracts
import {BaseTest} from './base/BaseTest.t.sol';
import {DeployUtils} from 'tests/DeployUtils.sol';
import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {HubConfigurator, IHubConfigurator} from 'src/hub/HubConfigurator.sol';
import {Hub, IHub} from 'src/hub/Hub.sol';

/// @notice Setup contract for the invariant test Suite, inherited by Tester
contract Setup is BaseTest {
  /// @notice Number of actors to deploy
  function _setUp() internal {
    // Deploy the suite assets
    _deployAssets();

    // Deploy protocol contracts and protocol actors
    _deployProtocolCore();

    // Deploy actors
    _setUpActors();

    // Configure the token list on the protocol
    _configureTokenList();
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          ASSETS                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Deploy the suite assets
  function _deployAssets() internal {
    usdc = new TestnetERC20('USDC', 'USDC', 6);
    weth = new TestnetERC20('WETH', 'WETH', 18);
    wbtc = new TestnetERC20('WBTC', 'WBTC', 8);

    baseAssets.push(AssetInfo({underlying: address(usdc), decimals: 6}));
    baseAssets.push(AssetInfo({underlying: address(weth), decimals: 18}));
    baseAssets.push(AssetInfo({underlying: address(wbtc), decimals: 8}));

    vm.label(address(usdc), 'usdc');
    vm.label(address(weth), 'weth');
    vm.label(address(wbtc), 'wbtc');
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          CORE                                             //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Deploy protocol core contracts
  function _deployProtocolCore() internal {
    // Access manager
    accessManager = new AccessManager(admin);

    // Hub 1
    hub = new Hub(address(accessManager));
    irStrategy = new AssetInterestRateStrategy(address(hub));

    // Configurators
    hubConfigurator = new HubConfigurator(address(accessManager));
    _setUpConfiguratorRoles();

    vm.label(address(accessManager), 'accessManager');
    vm.label(address(hub), 'hub');
    vm.label(address(hubConfigurator), 'hubConfigurator');
    vm.label(address(irStrategy), 'irStrategy');
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          CONFIGS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _configureTokenList() internal {
    // Configure hubs
    _configureHubs();

    // Configure spokes
    _configureSpokes();
  }

  /// @notice Configure the hubs
  function _configureHubs() internal {
    // HUB 1
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: OPTIMAL_USAGE_RATIO_IR1,
        baseVariableBorrowRate: BASE_VARIABLE_BORROW_RATE_IR1,
        variableRateSlope1: VARIABLE_RATE_SLOPE_1_IR1,
        variableRateSlope2: VARIABLE_RATE_SLOPE_2_IR1
      })
    );

    // Add USDC
    usdcAssetId = hub.addAsset(
      address(usdc),
      usdc.decimals(),
      address(this),
      address(irStrategy),
      encodedIrData
    );
    hub.updateAssetConfig(
      usdcAssetId,
      IHub.AssetConfig({
        liquidityFee: 5_00,
        feeReceiver: address(this),
        irStrategy: address(irStrategy),
        reinvestmentController: address(this)
      }),
      new bytes(0)
    );
    hubAssetIds.push(usdcAssetId);
    assetIdToUnderlying[usdcAssetId] = address(usdc);
    underlyingToAssetId[address(usdc)] = usdcAssetId;

    // Add WETH
    wethAssetId = hub.addAsset(
      address(weth),
      weth.decimals(),
      address(this),
      address(irStrategy),
      encodedIrData
    );
    hub.updateAssetConfig(
      wethAssetId,
      IHub.AssetConfig({
        liquidityFee: 10_00,
        feeReceiver: address(this),
        irStrategy: address(irStrategy),
        reinvestmentController: address(this)
      }),
      new bytes(0)
    );
    hubAssetIds.push(wethAssetId);
    assetIdToUnderlying[wethAssetId] = address(weth);
    underlyingToAssetId[address(weth)] = wethAssetId;

    // Add WBTC
    wbtcAssetId = hub.addAsset(
      address(wbtc),
      wbtc.decimals(),
      address(this),
      address(irStrategy),
      encodedIrData
    );
    hub.updateAssetConfig(
      wbtcAssetId,
      IHub.AssetConfig({
        liquidityFee: 5_00,
        feeReceiver: address(this),
        irStrategy: address(irStrategy),
        reinvestmentController: address(this)
      }),
      new bytes(0)
    );
    hubAssetIds.push(wbtcAssetId);
    assetIdToUnderlying[wbtcAssetId] = address(wbtc);
    underlyingToAssetId[address(wbtc)] = wbtcAssetId;
  }

  function _configureSpokes() internal {
    // Spoke 1: usdc, weth and wbtc
    // Spoke 2: weth and wbtc
    // Spoke 3: usdc, weth and wbtc
    // Only Spoke 3 is granted DEFICIT_ELIMINATOR Role

    // Add SPOKE 1 assets to hub
    hub.addSpoke(
      usdcAssetId,
      address(userToActor[USER1]),
      IHub.SpokeConfig({
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
        active: true,
        halted: false
      })
    );
    hub.addSpoke(
      wethAssetId,
      address(userToActor[USER1]),
      IHub.SpokeConfig({
        addCap: (Constants.MAX_ALLOWED_SPOKE_CAP / 10) * 3,
        drawCap: (Constants.MAX_ALLOWED_SPOKE_CAP / 10) * 3,
        riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
        active: true,
        halted: false
      })
    );
    hub.addSpoke(
      wbtcAssetId,
      address(userToActor[USER1]),
      IHub.SpokeConfig({
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
        active: true,
        halted: false
      })
    );

    // Add SPOKE 2 assets to hub
    hub.addSpoke(
      wethAssetId,
      address(userToActor[USER2]),
      IHub.SpokeConfig({
        addCap: (Constants.MAX_ALLOWED_SPOKE_CAP / 10) * 2,
        drawCap: (Constants.MAX_ALLOWED_SPOKE_CAP / 10) * 2,
        riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
        active: true,
        halted: false
      })
    );
    hub.addSpoke(
      wbtcAssetId,
      address(userToActor[USER2]),
      IHub.SpokeConfig({
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
        active: true,
        halted: false
      })
    );

    // Add SPOKE 3 assets to hub
    hub.addSpoke(
      usdcAssetId,
      address(userToActor[USER3]),
      IHub.SpokeConfig({
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
        active: true,
        halted: false
      })
    );
    hub.addSpoke(
      wethAssetId,
      address(userToActor[USER3]),
      IHub.SpokeConfig({
        addCap: (Constants.MAX_ALLOWED_SPOKE_CAP / 10) * 2,
        drawCap: (Constants.MAX_ALLOWED_SPOKE_CAP / 10) * 2,
        riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
        active: true,
        halted: false
      })
    );
    hub.addSpoke(
      wbtcAssetId,
      address(userToActor[USER3]),
      IHub.SpokeConfig({
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
        active: true,
        halted: false
      })
    );

    usdc.approve(address(hub), type(uint256).max);
    weth.approve(address(hub), type(uint256).max);
    wbtc.approve(address(hub), type(uint256).max);

    accessManager.grantRole(Roles.DEFICIT_ELIMINATOR_ROLE, address(userToActor[USER3]), 0);
    {
      bytes4[] memory selectors = new bytes4[](1);
      selectors[0] = IHub.eliminateDeficit.selector;
      accessManager.setTargetFunctionRole(address(hub), selectors, Roles.DEFICIT_ELIMINATOR_ROLE);
    }
  }

  /// @notice Set up roles for the configurators
  function _setUpConfiguratorRoles() internal virtual {
    // Grant roles to configurators
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, address(hubConfigurator), 0);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, address(this), 0);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_ROLE, address(this), 0);

    // Grant responsibilities on hubs
    {
      bytes4[] memory selectors = new bytes4[](4);
      selectors[0] = IHub.updateSpokeConfig.selector;
      selectors[1] = IHub.setInterestRateData.selector;
      selectors[2] = IHub.updateAssetConfig.selector;
      selectors[3] = IHub.mintFeeShares.selector;
      accessManager.setTargetFunctionRole(address(hub), selectors, Roles.HUB_ADMIN_ROLE);
    }

    {
      bytes4[] memory selectors = new bytes4[](22);
      selectors[0] = IHubConfigurator.updateLiquidityFee.selector;
      selectors[1] = IHubConfigurator.updateFeeReceiver.selector;
      selectors[2] = IHubConfigurator.updateFeeConfig.selector;
      selectors[3] = IHubConfigurator.updateInterestRateStrategy.selector;
      selectors[4] = IHubConfigurator.updateReinvestmentController.selector;
      selectors[5] = IHubConfigurator.resetAssetCaps.selector;
      selectors[6] = IHubConfigurator.deactivateAsset.selector;
      selectors[7] = IHubConfigurator.haltAsset.selector;
      selectors[8] = IHubConfigurator.addSpoke.selector;
      selectors[9] = IHubConfigurator.addSpokeToAssets.selector;
      selectors[10] = IHubConfigurator.updateSpokeActive.selector;
      selectors[11] = IHubConfigurator.updateSpokeHalted.selector;
      selectors[12] = IHubConfigurator.updateSpokeAddCap.selector;
      selectors[13] = IHubConfigurator.updateSpokeDrawCap.selector;
      selectors[14] = IHubConfigurator.updateSpokeRiskPremiumThreshold.selector;
      selectors[15] = IHubConfigurator.updateSpokeCaps.selector;
      selectors[16] = IHubConfigurator.deactivateSpoke.selector;
      selectors[17] = IHubConfigurator.haltSpoke.selector;
      selectors[18] = IHubConfigurator.resetSpokeCaps.selector;
      selectors[19] = IHubConfigurator.updateInterestRateData.selector;
      selectors[20] = IHubConfigurator.addAsset.selector;
      selectors[21] = IHubConfigurator.addAssetWithDecimals.selector;

      accessManager.setTargetFunctionRole(
        address(hubConfigurator),
        selectors,
        Roles.HUB_CONFIGURATOR_ROLE
      );
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           ACTORS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Deploy protocol actors and initialize their balances
  function _setUpActors() internal {
    // Initialize the three actors of the fuzzers
    address[] memory addresses = new address[](3);
    addresses[0] = USER1;
    addresses[1] = USER2;
    addresses[2] = USER3;

    // Initialize the tokens array
    address[] memory tokens = new address[](3);
    tokens[0] = address(usdc);
    tokens[1] = address(weth);
    tokens[2] = address(wbtc);

    address[] memory contracts = new address[](1);
    contracts[0] = address(hub);

    actors = ActorsUtils.setUpActors(addresses, tokens, contracts);
    userToActor[USER1] = Actor(payable(actors[0]));
    userToActor[USER2] = Actor(payable(actors[1]));
    userToActor[USER3] = Actor(payable(actors[2]));
  }
}
