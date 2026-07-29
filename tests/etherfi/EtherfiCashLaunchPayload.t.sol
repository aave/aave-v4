// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {EtherfiCashLaunchPayload} from 'src/etherfi/EtherfiCashLaunchPayload.sol';
import {
  AaveV4EtherfiCash,
  AaveV4EtherfiCashHubs,
  AaveV4EtherfiCashSpokes,
  AaveV4EtherfiCashAssets
} from 'src/etherfi/AaveV4EtherfiCash.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @dev The payload is fully hardcoded from the AaveV4EtherfiCash address-book libraries, so
/// these tests assert the generated actions and parameters DIRECTLY against the final
/// parameter sheet ('Submit to AAVE' section, 2026-07-23 17:25 revision). Execution against a
/// live instance is covered by the fork dress rehearsal (EtherfiCashLaunchFork.t.sol), which
/// runs the full two-phase sequence and verifies the resulting on-chain state field by field.
contract EtherfiCashLaunchPayloadTest is Test {
  uint256 internal constant NUM_ASSETS = 19;

  EtherfiCashLaunchPayload internal payload;

  function setUp() public {
    payload = new EtherfiCashLaunchPayload();
  }

  function _spec(
    string memory symbol
  ) internal view returns (EtherfiCashLaunchPayload.AssetSpec memory) {
    EtherfiCashLaunchPayload.AssetSpec[] memory specs = payload.getAssetSpecs();
    for (uint256 i; i < specs.length; i++) {
      if (keccak256(bytes(specs[i].symbol)) == keccak256(bytes(symbol))) return specs[i];
    }
    revert('spec not found');
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

  function test_specs_borrowableParameters() public view {
    EtherfiCashLaunchPayload.AssetSpec memory usdc = _spec('USDC');
    assertEq(usdc.underlying, AaveV4EtherfiCashAssets.USDC_UNDERLYING);
    assertEq(usdc.priceFeed, AaveV4EtherfiCashAssets.USDC_ORACLE);
    assertEq(usdc.collateralFactor, 95_00);
    assertEq(usdc.maxLiquidationBonus, 101_00); // 1%
    assertEq(usdc.liquidationFee, 10_00);
    assertTrue(usdc.borrowable);
    assertEq(usdc.liquidityFee, 5_00);
    assertEq(usdc.irData.optimalUsageRatio, 92_00);
    assertEq(usdc.irData.baseDrawnRate, 0);
    assertEq(usdc.irData.rateGrowthBeforeOptimal, 4_00);
    assertEq(usdc.irData.rateGrowthAfterOptimal, 10_00);
    assertEq(usdc.addCap, 10_000_000);
    assertEq(usdc.drawCap, 7_000_000);

    EtherfiCashLaunchPayload.AssetSpec memory weth = _spec('WETH');
    assertEq(weth.underlying, AaveV4EtherfiCashAssets.WETH_UNDERLYING);
    assertEq(weth.collateralFactor, 75_00);
    assertEq(weth.maxLiquidationBonus, 103_50); // 3.5%
    assertTrue(weth.borrowable);
    assertEq(weth.liquidityFee, 7_00);
    assertEq(weth.irData.optimalUsageRatio, 92_00);
    assertEq(weth.irData.rateGrowthBeforeOptimal, 2_35);
    assertEq(weth.irData.rateGrowthAfterOptimal, 14_00);
    assertEq(weth.addCap, 1_000);
    assertEq(weth.drawCap, 100);
  }

  function test_specs_collateralOnlyParameters() public view {
    // representative spot checks per the final sheet
    EtherfiCashLaunchPayload.AssetSpec memory weEth = _spec('weETH');
    assertEq(weEth.collateralFactor, 75_00);
    assertEq(weEth.maxLiquidationBonus, 103_50);
    assertEq(weEth.addCap, 1_000);

    EtherfiCashLaunchPayload.AssetSpec memory usdt = _spec('USDT');
    assertEq(usdt.collateralFactor, 95_00);
    assertEq(usdt.addCap, 10_000_000);

    EtherfiCashLaunchPayload.AssetSpec memory liquidUsd = _spec('liquidUSD');
    assertEq(liquidUsd.collateralFactor, 80_00);
    assertEq(liquidUsd.maxLiquidationBonus, 102_00);
    assertEq(liquidUsd.addCap, 5_000_000);

    EtherfiCashLaunchPayload.AssetSpec memory ethfi = _spec('ETHFI');
    assertEq(ethfi.collateralFactor, 30_00);
    assertEq(ethfi.maxLiquidationBonus, 105_00);
    assertEq(ethfi.addCap, 2_000_000);

    EtherfiCashLaunchPayload.AssetSpec[] memory specs = payload.getAssetSpecs();
    for (uint256 i; i < specs.length; i++) {
      if (specs[i].borrowable) continue;
      assertEq(specs[i].liquidityFee, 0, 'collateral-only must have 0 liquidity fee');
      assertEq(specs[i].drawCap, 0, 'collateral-only must have 0 draw cap');
      assertEq(specs[i].irData.optimalUsageRatio, 99_00, 'collateral-only flat curve kink');
      assertEq(specs[i].irData.rateGrowthBeforeOptimal, 0);
      assertEq(specs[i].irData.rateGrowthAfterOptimal, 0);
      assertEq(specs[i].liquidationFee, 10_00, 'liquidation fee 10% everywhere');
    }
  }

  function test_actions_hubListings() public view {
    IAaveV4ConfigEngine.AssetListing[] memory listings = payload.hubAssetListings();
    assertEq(listings.length, NUM_ASSETS);
    for (uint256 i; i < listings.length; i++) {
      assertEq(address(listings[i].hubConfigurator), AaveV4EtherfiCash.HUB_CONFIGURATOR);
      assertEq(listings[i].hub, AaveV4EtherfiCashHubs.CASH_HUB);
      assertEq(listings[i].feeReceiver, AaveV4EtherfiCashSpokes.TREASURY_SPOKE);
      assertEq(listings[i].irStrategy, AaveV4EtherfiCashHubs.CASH_HUB_IR_STRATEGY);
      assertEq(listings[i].tokenization.proxyAdminOwner, address(0), 'no tokenization at launch');
    }
  }

  function test_actions_spokeRegistrationDormant() public view {
    IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory additions = payload
      .hubSpokeToAssetsAdditions();
    assertEq(additions.length, 1);
    assertEq(additions[0].spoke, AaveV4EtherfiCashSpokes.CASH_SPOKE);
    assertEq(additions[0].assets.length, NUM_ASSETS);
    for (uint256 i; i < additions[0].assets.length; i++) {
      assertFalse(
        additions[0].assets[i].config.active,
        'spoke must register DORMANT (two-phase launch)'
      );
      assertFalse(additions[0].assets[i].config.halted);
      assertEq(additions[0].assets[i].config.riskPremiumThreshold, 0);
    }
  }

  function test_actions_reserveListings() public view {
    IAaveV4ConfigEngine.ReserveListing[] memory listings = payload.spokeReserveListings();
    assertEq(listings.length, NUM_ASSETS);
    for (uint256 i; i < listings.length; i++) {
      assertEq(address(listings[i].spokeConfigurator), AaveV4EtherfiCash.SPOKE_CONFIGURATOR);
      assertEq(listings[i].spoke, AaveV4EtherfiCashSpokes.CASH_SPOKE);
      assertEq(listings[i].hub, AaveV4EtherfiCashHubs.CASH_HUB);
      assertEq(listings[i].config.collateralRisk, 0, 'risk premium unused at launch');
      assertFalse(listings[i].config.paused);
      assertFalse(listings[i].config.frozen);
      assertTrue(listings[i].config.receiveSharesEnabled);
    }
  }

  function test_actions_liquidationConfig() public view {
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory updates = payload
      .spokeLiquidationConfigUpdates();
    assertEq(updates.length, 1);
    assertEq(updates[0].spoke, AaveV4EtherfiCashSpokes.CASH_SPOKE);
    assertEq(updates[0].targetHealthFactor, 1.24e18);
    assertEq(updates[0].healthFactorForMaxBonus, 0.9e18);
  }

  function test_actions_operatorRoleWiring() public view {
    // grants: both roles to both Safes
    IAaveV4ConfigEngine.RoleMembership[] memory memberships = payload
      .accessManagerRoleMemberships();
    assertEq(memberships.length, 4);
    assertEq(memberships[0].account, AaveV4EtherfiCash.OPERATOR_SAFE);
    assertEq(memberships[0].roleId, payload.HUB_CAPS_OPERATOR_ROLE());
    assertEq(memberships[1].account, AaveV4EtherfiCash.OPERATOR_SAFE);
    assertEq(memberships[1].roleId, payload.SPOKE_RISK_OPERATOR_ROLE());
    assertEq(memberships[2].account, AaveV4EtherfiCash.OWNER_SAFE);
    assertEq(memberships[3].account, AaveV4EtherfiCash.OWNER_SAFE);
    for (uint256 i; i < memberships.length; i++) {
      assertTrue(memberships[i].granted);
      assertEq(memberships[i].executionDelay, 0);
      assertEq(memberships[i].authority, AaveV4EtherfiCash.ACCESS_MANAGER);
    }

    // selector reassignments: hub caps -> 201, spoke dynamic config -> 401
    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] memory fnUpdates = payload
      .accessManagerTargetFunctionRoleUpdates();
    assertEq(fnUpdates.length, 2);
    assertEq(fnUpdates[0].target, AaveV4EtherfiCash.HUB_CONFIGURATOR);
    assertEq(fnUpdates[0].roleId, payload.HUB_CAPS_OPERATOR_ROLE());
    assertEq(fnUpdates[0].selectors.length, 3);
    assertEq(fnUpdates[0].selectors[0], IHubConfigurator.updateSpokeCaps.selector);
    assertEq(fnUpdates[0].selectors[1], IHubConfigurator.updateSpokeAddCap.selector);
    assertEq(fnUpdates[0].selectors[2], IHubConfigurator.updateSpokeDrawCap.selector);
    assertEq(fnUpdates[1].target, AaveV4EtherfiCash.SPOKE_CONFIGURATOR);
    assertEq(fnUpdates[1].roleId, payload.SPOKE_RISK_OPERATOR_ROLE());
    assertEq(fnUpdates[1].selectors.length, 2);
    assertEq(fnUpdates[1].selectors[0], ISpokeConfigurator.addDynamicReserveConfig.selector);
    assertEq(fnUpdates[1].selectors[1], ISpokeConfigurator.updateDynamicReserveConfig.selector);
  }
}
