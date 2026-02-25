// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseState} from 'tests/setup/BaseState.sol';
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
}
