// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {QueryHelpers} from 'tests/helpers/QueryHelpers.sol';
import {Vm} from 'forge-std/Vm.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {
  IAssetInterestRateStrategy,
  IBasicInterestRateStrategy
} from 'src/hub/AssetInterestRateStrategy.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ReserveFlags, ReserveFlagsMap} from 'src/spoke/libraries/ReserveFlagsMap.sol';

/// @title Assertions
/// @notice Assertion helpers for the Aave V4 test suite.
abstract contract Assertions is QueryHelpers {
  using WadRayMath for *;
  using PercentageMath for uint256;
  using SafeCast for *;
  using ReserveFlagsMap for ReserveFlags;

  function _assertUserDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = spoke.getUserDebt(reserveId, user);
    assertApproxEqAbs(
      actualDrawnDebt,
      expectedDrawnDebt,
      1,
      string.concat('user drawn debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      3,
      string.concat('user premium debt ', label)
    );
    assertApproxEqAbs(
      spoke.getUserTotalDebt(reserveId, user),
      expectedDrawnDebt + expectedPremiumDebt,
      3,
      string.concat('user total debt ', label)
    );
  }

  function _assertReserveDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = spoke.getReserveDebt(reserveId);
    assertApproxEqAbs(
      actualDrawnDebt,
      expectedDrawnDebt,
      1,
      string.concat('reserve drawn debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      3,
      string.concat('reserve premium debt ', label)
    );
    assertApproxEqAbs(
      spoke.getReserveTotalDebt(reserveId),
      expectedDrawnDebt + expectedPremiumDebt,
      3,
      string.concat('reserve total debt ', label)
    );
  }

  function _assertSpokeDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = hub1.getSpokeOwed(
      assetId,
      address(spoke)
    );
    assertApproxEqAbs(
      actualDrawnDebt,
      expectedDrawnDebt,
      1,
      string.concat('spoke drawn debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      3,
      string.concat('spoke premium debt ', label)
    );
    assertApproxEqAbs(
      hub1.getSpokeTotalOwed(assetId, address(spoke)),
      expectedDrawnDebt + expectedPremiumDebt,
      3,
      string.concat('spoke total debt ', label)
    );
  }

  function _assertAssetDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = hub1.getAssetOwed(assetId);
    assertApproxEqAbs(
      actualDrawnDebt,
      expectedDrawnDebt,
      1,
      string.concat('asset drawn debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      3,
      string.concat('asset premium debt ', label)
    );
    assertApproxEqAbs(
      hub1.getAssetTotalOwed(assetId),
      expectedDrawnDebt + expectedPremiumDebt,
      3,
      string.concat('asset total debt ', label)
    );
  }

  function _assertSingleUserProtocolDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    _assertUserDebt(spoke, reserveId, user, expectedDrawnDebt, expectedPremiumDebt, label);
    _assertReserveDebt(spoke, reserveId, expectedDrawnDebt, expectedPremiumDebt, label);
    _assertSpokeDebt(spoke, reserveId, expectedDrawnDebt, expectedPremiumDebt, label);
    _assertAssetDebt(spoke, reserveId, expectedDrawnDebt, expectedPremiumDebt, label);
  }

  function _assertUserSupply(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    assertApproxEqAbs(
      spoke.getUserSuppliedAssets(reserveId, user),
      expectedSuppliedAmount,
      3,
      string.concat('user supplied amount ', label)
    );
  }

  function _assertReserveSupply(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    assertApproxEqAbs(
      spoke.getReserveSuppliedAssets(reserveId),
      expectedSuppliedAmount,
      3,
      string.concat('reserve supplied amount ', label)
    );
  }

  function _assertSpokeSupply(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    assertApproxEqAbs(
      hub1.getSpokeAddedAssets(assetId, address(spoke)),
      expectedSuppliedAmount,
      3,
      string.concat('spoke supplied amount ', label)
    );
  }

  function _assertAssetSupply(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    assertApproxEqAbs(
      hub1.getAddedAssets(assetId) - _calculateBurntInterest(hub1, assetId),
      expectedSuppliedAmount,
      3,
      string.concat('asset supplied amount ', label)
    );
  }

  function _assertSingleUserProtocolSupply(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    _assertUserSupply(spoke, reserveId, user, expectedSuppliedAmount, label);
    _assertReserveSupply(spoke, reserveId, expectedSuppliedAmount, label);
    _assertSpokeSupply(spoke, reserveId, expectedSuppliedAmount, label);
    _assertAssetSupply(spoke, reserveId, expectedSuppliedAmount, label);
  }

  function _checkSuppliedAmounts(
    uint256 assetId,
    uint256 reserveId,
    ISpoke spoke,
    address user,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    uint256 expectedSuppliedShares = hub1.previewAddByAssets(assetId, expectedSuppliedAmount);
    assertEq(
      hub1.getAddedShares(assetId),
      expectedSuppliedShares,
      string(abi.encodePacked('asset supplied shares ', label))
    );
    assertEq(
      hub1.getAddedAssets(assetId) - _calculateBurntInterest(hub1, assetId),
      expectedSuppliedAmount,
      string(abi.encodePacked('asset supplied amount ', label))
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(spoke)),
      expectedSuppliedShares,
      string(abi.encodePacked('spoke supplied shares ', label))
    );
    assertEq(
      hub1.getSpokeAddedAssets(assetId, address(spoke)),
      expectedSuppliedAmount,
      string(abi.encodePacked('spoke supplied amount ', label))
    );
    assertEq(
      spoke.getReserveSuppliedShares(reserveId),
      expectedSuppliedShares,
      string(abi.encodePacked('reserve supplied shares ', label))
    );
    assertEq(
      spoke.getReserveSuppliedAssets(reserveId),
      expectedSuppliedAmount,
      string(abi.encodePacked('reserve supplied amount ', label))
    );
    assertEq(
      spoke.getUserSuppliedShares(reserveId, user),
      expectedSuppliedShares,
      string(abi.encodePacked('user supplied shares ', label))
    );
    assertEq(
      spoke.getUserSuppliedAssets(reserveId, user),
      expectedSuppliedAmount,
      string(abi.encodePacked('user supplied amount ', label))
    );
  }

  function _checkSupplyRateIncreasing(
    uint256 oldRate,
    uint256 newRate,
    string memory label
  ) internal pure {
    assertGe(newRate, oldRate, string.concat('supply rate monotonically increasing ', label));
  }

  function _checkDebtRateConstant(
    uint256 oldRate,
    uint256 newRate,
    string memory label
  ) internal pure {
    assertEq(newRate, oldRate, string.concat('debt rate should be constant ', label));
  }

  function _assertBorrowRateSynced(
    IHub targetHub,
    uint256 assetId,
    string memory operation
  ) internal view {
    IHub.Asset memory asset = targetHub.getAsset(assetId);
    (uint256 drawn, ) = hub1.getAssetOwed(assetId);

    vm.assertEq(
      asset.drawnRate,
      IBasicInterestRateStrategy(asset.irStrategy).calculateInterestRate(
        assetId,
        asset.liquidity,
        drawn,
        asset.deficitRay,
        asset.swept
      ),
      string.concat('base borrow rate after ', operation)
    );
  }

  function _assertHubLiquidity(IHub targetHub, uint256 assetId, string memory label) internal view {
    IHub.Asset memory asset = targetHub.getAsset(assetId);
    uint256 currentHubBalance = IERC20(asset.underlying).balanceOf(address(targetHub));
    assertEq(
      targetHub.getAssetLiquidity(assetId),
      currentHubBalance,
      string.concat('hub liquidity ', label)
    );
  }

  function _assertEventNotEmitted(bytes32 eventSignature) internal {
    Vm.Log[] memory entries = vm.getRecordedLogs();
    for (uint256 i; i < entries.length; i++) {
      assertNotEq(entries[i].topics[0], eventSignature);
    }
    vm.recordLogs();
  }

  function _assertEventsNotEmitted(bytes32 event1Sig, bytes32 event2Sig) internal {
    Vm.Log[] memory entries = vm.getRecordedLogs();
    for (uint256 i; i < entries.length; i++) {
      assertNotEq(entries[i].topics[0], event1Sig);
      assertNotEq(entries[i].topics[0], event2Sig);
    }
    vm.recordLogs();
  }

  function _assertEventsNotEmitted(
    bytes32 event1Sig,
    bytes32 event2Sig,
    bytes32 event3Sig
  ) internal {
    Vm.Log[] memory entries = vm.getRecordedLogs();
    for (uint256 i; i < entries.length; i++) {
      assertNotEq(entries[i].topics[0], event1Sig);
      assertNotEq(entries[i].topics[0], event2Sig);
      assertNotEq(entries[i].topics[0], event3Sig);
    }
    vm.recordLogs();
  }

  function _assertDynamicConfigRefreshEventsNotEmitted() internal {
    _assertEventsNotEmitted(
      ISpoke.RefreshAllUserDynamicConfig.selector,
      ISpoke.RefreshSingleUserDynamicConfig.selector
    );
  }

  function _assertEntityHasNoBalanceOrAllowance(
    IERC20 underlying,
    address entity,
    address user
  ) internal {
    assertEq(underlying.balanceOf(entity), 0);
    assertEq(underlying.allowance({owner: user, spender: entity}), 0);
    assertEq(underlying.allowance({owner: entity, spender: vm.randomAddress()}), 0);
  }

  // --- assertEq overloads for protocol types ---

  function assertEq(IHubBase.PremiumDelta memory a, IHubBase.PremiumDelta memory b) internal pure {
    assertEq(a.sharesDelta, b.sharesDelta, 'sharesDelta');
    assertEq(a.offsetRayDelta, b.offsetRayDelta, 'offsetRayDelta');
    assertEq(a.restoredPremiumRay, b.restoredPremiumRay, 'restoredPremiumRay');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(IHub.AssetConfig memory a, IHub.AssetConfig memory b) internal pure {
    assertEq(a.feeReceiver, b.feeReceiver, 'feeReceiver');
    assertEq(a.liquidityFee, b.liquidityFee, 'liquidityFee');
    assertEq(a.irStrategy, b.irStrategy, 'irStrategy');
    assertEq(a.reinvestmentController, b.reinvestmentController, 'reinvestmentController');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(IHub.SpokeConfig memory a, IHub.SpokeConfig memory b) internal pure {
    assertEq(a.addCap, b.addCap, 'addCap');
    assertEq(a.drawCap, b.drawCap, 'drawCap');
    assertEq(a.riskPremiumThreshold, b.riskPremiumThreshold, 'riskPremiumThreshold');
    assertEq(a.active, b.active, 'active');
    assertEq(a.halted, b.halted, 'halted');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(
    ISpoke.LiquidationConfig memory a,
    ISpoke.LiquidationConfig memory b
  ) internal pure {
    assertEq(a.targetHealthFactor, b.targetHealthFactor, 'targetHealthFactor');
    assertEq(a.liquidationBonusFactor, b.liquidationBonusFactor, 'liquidationBonusFactor');
    assertEq(a.healthFactorForMaxBonus, b.healthFactorForMaxBonus, 'healthFactorForMaxBonus');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(ISpoke.ReserveConfig memory a, ISpoke.ReserveConfig memory b) internal pure {
    assertEq(a.paused, b.paused, 'paused');
    assertEq(a.frozen, b.frozen, 'frozen');
    assertEq(a.borrowable, b.borrowable, 'borrowable');
    assertEq(a.receiveSharesEnabled, b.receiveSharesEnabled, 'receiveSharesEnabled');
    assertEq(a.collateralRisk, b.collateralRisk, 'collateralRisk');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(
    ISpoke.DynamicReserveConfig memory a,
    ISpoke.DynamicReserveConfig memory b
  ) internal pure {
    assertEq(a.collateralFactor, b.collateralFactor, 'collateralFactor');
    assertEq(a.maxLiquidationBonus, b.maxLiquidationBonus, 'maxLiquidationBonus');
    assertEq(a.liquidationFee, b.liquidationFee, 'liquidationFee');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(
    IAssetInterestRateStrategy.InterestRateData memory a,
    IAssetInterestRateStrategy.InterestRateData memory b
  ) internal pure {
    assertEq(a.optimalUsageRatio, b.optimalUsageRatio, 'optimalUsageRatio');
    assertEq(a.baseVariableBorrowRate, b.baseVariableBorrowRate, 'baseVariableBorrowRate');
    assertEq(a.variableRateSlope1, b.variableRateSlope1, 'variableRateSlope1');
    assertEq(a.variableRateSlope2, b.variableRateSlope2, 'variableRateSlope2');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(SpokePosition memory a, AssetPosition memory b) internal pure {
    assertEq(a.assetId, b.assetId, 'assetId');
    assertEq(a.addedShares, b.addedShares, 'addedShares');
    assertEq(a.addedAmount, b.addedAmount, 'addedAmount');
    assertEq(a.drawnShares, b.drawnShares, 'drawnShares');
    assertEq(a.drawn, b.drawn, 'drawnDebt');
    assertEq(a.premiumShares, b.premiumShares, 'premiumShares');
    assertEq(a.premiumOffsetRay, b.premiumOffsetRay, 'premiumOffsetRay');
    assertEq(a.premium, b.premium, 'premium');
  }

  function assertEq(SpokePosition memory a, SpokePosition memory b) internal pure {
    assertEq(a.reserveId, b.reserveId, 'reserveId');
    assertEq(a.assetId, b.assetId, 'assetId');
    assertEq(a.addedShares, b.addedShares, 'addedShares');
    assertEq(a.addedAmount, b.addedAmount, 'addedAmount');
    assertEq(a.drawnShares, b.drawnShares, 'drawnShares');
    assertEq(a.drawn, b.drawn, 'drawn');
    assertEq(a.premiumShares, b.premiumShares, 'premiumShares');
    assertEq(a.premiumOffsetRay, b.premiumOffsetRay, 'premiumOffsetRay');
    assertEq(a.premium, b.premium, 'premium');
    assertEq(abi.encode(a), abi.encode(b)); // sanity check
  }

  function assertEq(ISpoke.Reserve memory a, ISpoke.Reserve memory b) internal pure {
    assertEq(address(a.hub), address(b.hub), 'hub');
    assertEq(a.assetId, b.assetId, 'asset Id');
    assertEq(a.decimals, b.decimals, 'decimals');
    assertEq(a.dynamicConfigKey, b.dynamicConfigKey, 'dynamicConfigKey');
    assertEq(a.flags.paused(), b.flags.paused(), 'paused');
    assertEq(a.flags.frozen(), b.flags.frozen(), 'frozen');
    assertEq(a.flags.borrowable(), b.flags.borrowable(), 'borrowable');
    assertEq(
      a.flags.receiveSharesEnabled(),
      b.flags.receiveSharesEnabled(),
      'receiveSharesEnabled'
    );
    assertEq(a.collateralRisk, b.collateralRisk, 'collateralRisk');
    assertEq(abi.encode(a), abi.encode(b)); // sanity check
  }

  function assertEq(ISpoke.UserPosition memory a, ISpoke.UserPosition memory b) internal pure {
    assertEq(a.suppliedShares, b.suppliedShares, 'suppliedShares');
    assertEq(a.drawnShares, b.drawnShares, 'drawnShares');
    assertEq(a.premiumShares, b.premiumShares, 'premiumShares');
    assertEq(a.premiumOffsetRay, b.premiumOffsetRay, 'premiumOffsetRay');
    assertEq(a.dynamicConfigKey, b.dynamicConfigKey, 'dynamicConfigKey');
    assertEq(abi.encode(a), abi.encode(b)); // sanity check
  }

  function assertEq(IHub.SpokeData memory a, IHub.SpokeData memory b) internal pure {
    assertEq(a.premiumShares, b.premiumShares, 'premiumShares');
    assertEq(a.premiumOffsetRay, b.premiumOffsetRay, 'premiumOffsetRay');
    assertEq(a.drawnShares, b.drawnShares, 'drawnShares');
    assertEq(a.addedShares, b.addedShares, 'addedShares');
    assertEq(a.addCap, b.addCap, 'addCap');
    assertEq(a.drawCap, b.drawCap, 'drawCap');
    assertEq(a.riskPremiumThreshold, b.riskPremiumThreshold, 'riskPremiumThreshold');
    assertEq(a.active, b.active, 'active');
    assertEq(a.halted, b.halted, 'halted');
    assertEq(a.deficitRay, b.deficitRay, 'deficitRay');
    assertEq(abi.encode(a), abi.encode(b)); // sanity check
  }

  function assertEq(
    ISpoke.UserAccountData memory a,
    ISpoke.UserAccountData memory b
  ) internal pure {
    assertEq(a.riskPremium, b.riskPremium, 'riskPremium');
    assertEq(a.avgCollateralFactor, b.avgCollateralFactor, 'avgCollateralFactor');
    assertEq(a.totalCollateralValue, b.totalCollateralValue, 'totalCollateralValue');
    assertEq(a.totalDebtValueRay, b.totalDebtValueRay, 'totalDebtValueRay');
    assertEq(a.healthFactor, b.healthFactor, 'healthFactor');
    assertEq(a.activeCollateralCount, b.activeCollateralCount, 'activeCollateralCount');
    assertEq(a.borrowCount, b.borrowCount, 'borrowCount');
    assertEq(abi.encode(a), abi.encode(b)); // sanity check
  }

  function assertEq(DebtData memory a, DebtData memory b) internal pure {
    assertEq(a.drawnDebt, b.drawnDebt, 'drawn debt');
    assertEq(a.premiumDebt, b.premiumDebt, 'premium debt');
    assertEq(a.totalDebt, b.totalDebt, 'total debt');
    assertEq(keccak256(abi.encode(a)), keccak256(abi.encode(b)), 'debt data'); // sanity
  }

  function assertEq(DynamicConfigEntry memory a, DynamicConfigEntry memory b) internal pure {
    assertEq(a.key, b.key, 'key');
    assertEq(a.enabled, b.enabled, 'enabled');
    assertEq(abi.encode(a), abi.encode(b)); // sanity
  }

  function assertEq(DynamicConfigEntry[] memory a, DynamicConfigEntry[] memory b) internal pure {
    require(a.length == b.length);
    for (uint256 i; i < a.length; ++i) {
      if (a[i].enabled && b[i].enabled) {
        assertEq(a[i].key, b[i].key, string.concat('reserve ', vm.toString(i)));
      }
    }
  }

  function assertNotEq(DynamicConfigEntry[] memory a, DynamicConfigEntry[] memory b) internal pure {
    require(a.length == b.length);
    for (uint256 i; i < a.length; ++i) {
      if (a[i].enabled && b[i].enabled) {
        assertNotEq(a[i].key, b[i].key, string.concat('reserve ', vm.toString(i)));
      }
    }
  }

  /// @dev notify is not called after supply or repay, thus refreshPremium should not be called
  function _assertRefreshPremiumNotCalled() internal {
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.refreshPremium.selector), 0);
  }
}
