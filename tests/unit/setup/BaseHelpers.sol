// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseState} from 'tests/unit/setup/BaseState.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {ISpoke, ISpokeBase} from 'src/spoke/interfaces/ISpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {SpokeActions} from 'tests/helpers/spoke/SpokeActions.sol';

/// @title BaseHelpers
/// @notice Aggregates hub and spoke helpers and adds cross-layer assertion helpers.
abstract contract BaseHelpers is BaseState {
  // --- Reserve ID lookups (use spokeInfo state from BaseState) ---

  function _usdxReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdx.reserveId;
  }

  function _usdyReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdy.reserveId;
  }

  function _daiReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].dai.reserveId;
  }

  function _wethReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].weth.reserveId;
  }

  function _wbtcReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].wbtc.reserveId;
  }

  function _usdzReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdz.reserveId;
  }

  function _getReserveIds(ISpoke spoke) internal view returns (ReserveIds memory) {
    return
      ReserveIds({
        dai: _daiReserveId(spoke),
        weth: _wethReserveId(spoke),
        usdx: _usdxReserveId(spoke),
        wbtc: _wbtcReserveId(spoke)
      });
  }

  // --- Cross-layer helpers ---

  /// @dev Draws liquidity from the Hub via a specific spoke which is already active
  function _drawLiquidityFromSpoke(
    IHub hub,
    address spoke,
    uint256 assetId,
    uint256 reserveId,
    uint256 amount,
    uint256 skipTime,
    address collateralUser
  ) internal returns (uint256 drawn, uint256 premiumRay) {
    assertTrue(hub.getSpoke(assetId, spoke).active);

    deal(hub.getAsset(assetId).underlying, collateralUser, amount * 2);
    SpokeActions.supplyCollateral(
      ISpoke(spoke),
      reserveId,
      collateralUser,
      amount * 2,
      collateralUser
    );
    SpokeActions.borrow(ISpokeBase(spoke), reserveId, collateralUser, amount, collateralUser);

    skip(skipTime);

    (drawn, ) = hub.getAssetOwed(assetId);
    assertGt(drawn, 0); // non-zero drawn debt

    premiumRay = hub.getAssetPremiumRay(assetId);
    assertGt(premiumRay, 0); // non-zero premium debt
  }

  // --- Cross-layer assertion helpers ---

  function _assertOnlyOneUserDebt(
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

  // --- assertEq overloads for test types ---

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
}
