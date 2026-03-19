// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {QueryHelpers} from 'tests/helpers/hub/QueryHelpers.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {
  IAssetInterestRateStrategy,
  IBasicInterestRateStrategy
} from 'src/hub/AssetInterestRateStrategy.sol';

/// @title Assertions
/// @notice Hub-level assertion helpers for the Aave V4 test suite.
abstract contract Assertions is QueryHelpers {
  using WadRayMath for *;
  using PercentageMath for uint256;
  using SafeCast for *;

  function _assertHubLiquidity(IHub targetHub, uint256 assetId, string memory label) internal view {
    IHub.Asset memory asset = targetHub.getAsset(assetId);
    uint256 currentHubBalance = IERC20(asset.underlying).balanceOf(address(targetHub));
    assertEq(
      targetHub.getAssetLiquidity(assetId),
      currentHubBalance,
      string.concat('hub liquidity ', label)
    );
  }

  function _assertDrawnRateSynced(
    IHub targetHub,
    uint256 assetId,
    string memory operation
  ) internal view {
    IHub.Asset memory asset = targetHub.getAsset(assetId);
    (uint256 drawn, ) = targetHub.getAssetOwed(assetId);

    vm.assertEq(
      asset.drawnRate,
      IBasicInterestRateStrategy(asset.irStrategy).calculateInterestRate(
        assetId,
        asset.liquidity,
        drawn,
        asset.deficitRay,
        asset.swept
      ),
      string.concat('base drawn rate after ', operation)
    );
  }

  /// @dev notify is not called after supply or repay, thus refreshPremium should not be called
  function _assertRefreshPremiumNotCalled(IHub hub) internal {
    vm.expectCall(address(hub), abi.encodeWithSelector(IHubBase.refreshPremium.selector), 0);
  }

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
}
