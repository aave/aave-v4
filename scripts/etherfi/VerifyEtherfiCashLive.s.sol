// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

import {EtherfiCashLaunchPayload} from 'src/etherfi/EtherfiCashLaunchPayload.sol';
import {EtherfiCashOpMainnet} from 'src/etherfi/EtherfiCashOpMainnet.sol';
import {EtherfiCashScriptBase} from 'scripts/etherfi/EtherfiCashScriptBase.s.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @title VerifyEtherfiCashLive
/// @notice Read-only check that the LIVE hub/spoke state matches the launch payload spec —
/// every listing, cap, collateral factor, bonus, curve and the liquidation config.
/// Run after the payload executes (fork rehearsal or the real post-AIP state):
///   forge script scripts/etherfi/VerifyEtherfiCashLive.s.sol --rpc-url <optimism|fork>
/// Reverts with a mismatch count if anything differs. Never broadcasts.
contract VerifyEtherfiCashLiveScript is EtherfiCashScriptBase {
  uint256 internal mismatches;

  function verify() external returns (uint256) {
    _requireOpMainnet();

    // two-phase launch: EXPECT_ACTIVE=false verifies the dormant state between phase 1
    // (config payload) and phase 2 (activation payload); default checks the final live state
    bool expectActive = vm.envOr('EXPECT_ACTIVE', true);

    // in-memory expectedPayload payload: same constants + address resolution as the deploy script
    EtherfiCashLaunchPayload expectedPayload = new EtherfiCashLaunchPayload(
      _instanceAddresses(),
      _assetAddresses()
    );

    IHub hub = IHub(expectedPayload.HUB());
    ISpoke spoke = ISpoke(expectedPayload.CASH_SPOKE());
    IAssetInterestRateStrategy irStrategy = IAssetInterestRateStrategy(expectedPayload.IR_STRATEGY());

    EtherfiCashLaunchPayload.AssetSpec[] memory specs = expectedPayload.getAssetSpecs();
    console2.log('verifying', specs.length, 'assets against live state');

    for (uint256 i; i < specs.length; i++) {
      EtherfiCashLaunchPayload.AssetSpec memory spec = specs[i];

      uint256 assetId = hub.getAssetId(spec.underlying);
      IHub.Asset memory asset = hub.getAsset(assetId);
      _check(spec.symbol, 'liquidityFee', asset.liquidityFee, spec.liquidityFee);

      IAssetInterestRateStrategy.InterestRateData memory ir = irStrategy.getInterestRateData(
        assetId
      );
      _check(spec.symbol, 'kink', ir.optimalUsageRatio, spec.irData.optimalUsageRatio);
      _check(spec.symbol, 'baseRate', ir.baseDrawnRate, spec.irData.baseDrawnRate);
      _check(spec.symbol, 'slope1', ir.rateGrowthBeforeOptimal, spec.irData.rateGrowthBeforeOptimal);
      _check(spec.symbol, 'slope2', ir.rateGrowthAfterOptimal, spec.irData.rateGrowthAfterOptimal);

      IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, address(spoke));
      _check(spec.symbol, 'active', spokeConfig.active ? 1 : 0, expectActive ? 1 : 0);
      _check(spec.symbol, 'halted', spokeConfig.halted ? 1 : 0, 0);
      _check(spec.symbol, 'addCap', spokeConfig.addCap, spec.addCap);
      _check(spec.symbol, 'drawCap', spokeConfig.drawCap, spec.drawCap);
      _check(spec.symbol, 'riskPremiumThreshold', spokeConfig.riskPremiumThreshold, 0);

      uint256 reserveId = spoke.getReserveId(address(hub), assetId);
      ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(reserveId);
      _check(spec.symbol, 'collateralRisk', reserveConfig.collateralRisk, 0);
      _check(spec.symbol, 'paused', reserveConfig.paused ? 1 : 0, 0);
      _check(spec.symbol, 'frozen', reserveConfig.frozen ? 1 : 0, 0);
      _check(spec.symbol, 'borrowable', reserveConfig.borrowable ? 1 : 0, spec.borrowable ? 1 : 0);

      ISpoke.DynamicReserveConfig memory dyn = spoke.getDynamicReserveConfig(reserveId, 0);
      _check(spec.symbol, 'collateralFactor', dyn.collateralFactor, spec.collateralFactor);
      _check(spec.symbol, 'maxLiquidationBonus', dyn.maxLiquidationBonus, spec.maxLiquidationBonus);
      _check(spec.symbol, 'liquidationFee', dyn.liquidationFee, spec.liquidationFee);

      console2.log(string.concat('  [checked] ', spec.symbol));
    }

    ISpoke.LiquidationConfig memory liq = spoke.getLiquidationConfig();
    _check('spoke', 'targetHealthFactor', liq.targetHealthFactor, expectedPayload.TARGET_HEALTH_FACTOR());
    _check(
      'spoke',
      'healthFactorForMaxBonus',
      liq.healthFactorForMaxBonus,
      expectedPayload.HEALTH_FACTOR_FOR_MAX_BONUS()
    );

    // operator role wiring (Owner + Operator Safes, selector reassignments)
    IAccessManager accessManager = IAccessManager(expectedPayload.ACCESS_MANAGER());
    uint64 hubRole = expectedPayload.HUB_CAPS_OPERATOR_ROLE();
    uint64 spokeRole = expectedPayload.SPOKE_RISK_OPERATOR_ROLE();
    address[2] memory safes = [expectedPayload.OPERATOR_SAFE(), expectedPayload.OWNER_SAFE()];
    for (uint256 i; i < safes.length; i++) {
      (bool isMember, ) = accessManager.hasRole(hubRole, safes[i]);
      _check('accessManager', 'hasRole(hubCaps)', isMember ? 1 : 0, 1);
      (isMember, ) = accessManager.hasRole(spokeRole, safes[i]);
      _check('accessManager', 'hasRole(spokeRisk)', isMember ? 1 : 0, 1);
    }
    _check(
      'accessManager',
      'updateSpokeCaps role',
      accessManager.getTargetFunctionRole(
        address(expectedPayload.HUB_CONFIGURATOR()),
        IHubConfigurator.updateSpokeCaps.selector
      ),
      hubRole
    );
    _check(
      'accessManager',
      'updateDynamicReserveConfig role',
      accessManager.getTargetFunctionRole(
        address(expectedPayload.SPOKE_CONFIGURATOR()),
        ISpokeConfigurator.updateDynamicReserveConfig.selector
      ),
      spokeRole
    );

    require(mismatches == 0, string.concat('MISMATCHES: ', vm.toString(mismatches)));
    console2.log(
      expectActive
        ? 'VERIFIED: live state matches the launch payload spec (ACTIVE)'
        : 'VERIFIED: live state matches the launch payload spec (DORMANT - ready for activation)'
    );
    return specs.length;
  }

  function _check(
    string memory symbol,
    string memory field,
    uint256 actual,
    uint256 expected
  ) internal {
    if (actual != expected) {
      console2.log(
        string.concat(
          '  [MISMATCH] ',
          symbol,
          '.',
          field,
          ': actual=',
          vm.toString(actual),
          ' expected=',
          vm.toString(expected)
        )
      );
      mismatches++;
    }
  }
}
