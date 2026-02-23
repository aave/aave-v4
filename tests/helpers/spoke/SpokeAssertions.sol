// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SpokeQueryHelpers} from 'tests/helpers/spoke/SpokeQueryHelpers.sol';
import {Vm} from 'forge-std/Vm.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {ReserveFlags, ReserveFlagsMap} from 'src/spoke/libraries/ReserveFlagsMap.sol';

/// @title SpokeAssertions
/// @notice Spoke-level assertion helpers for the Aave V4 test suite.
abstract contract SpokeAssertions is SpokeQueryHelpers {
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

  function _assertSpokeDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    IHub hub = _hub(spoke, reserveId);
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = hub.getSpokeOwed(
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
      hub.getSpokeTotalOwed(assetId, address(spoke)),
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
    IHub hub = _hub(spoke, reserveId);
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = hub.getAssetOwed(assetId);
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
      hub.getAssetTotalOwed(assetId),
      expectedDrawnDebt + expectedPremiumDebt,
      3,
      string.concat('asset total debt ', label)
    );
  }

  function _assertSpokeSupply(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    IHub hub = _hub(spoke, reserveId);
    assertApproxEqAbs(
      hub.getSpokeAddedAssets(assetId, address(spoke)),
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
    IHub hub = _hub(spoke, reserveId);
    assertApproxEqAbs(
      hub.getAddedAssets(assetId) - _calculateBurntInterest(hub, assetId),
      expectedSuppliedAmount,
      3,
      string.concat('asset supplied amount ', label)
    );
  }

  function _assertSuppliedAmounts(
    uint256 assetId,
    uint256 reserveId,
    ISpoke spoke,
    address user,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    IHub hub = _hub(spoke, reserveId);
    uint256 expectedSuppliedShares = hub.previewAddByAssets(assetId, expectedSuppliedAmount);
    assertEq(
      hub.getAddedShares(assetId),
      expectedSuppliedShares,
      string(abi.encodePacked('asset supplied shares ', label))
    );
    assertEq(
      hub.getAddedAssets(assetId) - _calculateBurntInterest(hub, assetId),
      expectedSuppliedAmount,
      string(abi.encodePacked('asset supplied amount ', label))
    );
    assertEq(
      hub.getSpokeAddedShares(assetId, address(spoke)),
      expectedSuppliedShares,
      string(abi.encodePacked('spoke supplied shares ', label))
    );
    assertEq(
      hub.getSpokeAddedAssets(assetId, address(spoke)),
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

  // --- assertEq overloads for Spoke types ---

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

  // --- Generic event assertion helpers ---

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
}
