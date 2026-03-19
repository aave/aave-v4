// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CommonHelpers} from 'tests/helpers/commons/CommonHelpers.sol';
import {Constants} from 'tests/helpers/hub/Constants.sol';
import {HubActions} from 'tests/helpers/hub/HubActions.sol';
import {SlotDerivation} from 'src/dependencies/openzeppelin/SlotDerivation.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {
  IAssetInterestRateStrategy,
  IBasicInterestRateStrategy
} from 'src/hub/AssetInterestRateStrategy.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

/// @title MockHelpers
/// @notice Hub-level mocking utilities for the Aave V4 test suite.
abstract contract MockHelpers is CommonHelpers, Constants {
  using WadRayMath for *;
  using PercentageMath for uint256;

  function _mockDrawnRateBps(address irStrategy, uint256 drawnRateBps) internal {
    vm.mockCall(
      irStrategy,
      IBasicInterestRateStrategy.calculateInterestRate.selector,
      abi.encode(_bpsToRay(drawnRateBps))
    );
  }

  function _mockDrawnRateBps(
    address irStrategy,
    uint256 drawnRateBps,
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn,
    uint256 deficit,
    uint256 swept
  ) internal {
    vm.mockCall(
      irStrategy,
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (assetId, liquidity, drawn, deficit, swept)
      ),
      abi.encode(_bpsToRay(drawnRateBps))
    );
  }

  function _mockDrawnRateRay(address irStrategy, uint256 drawnRateRay) internal {
    vm.mockCall(
      irStrategy,
      IBasicInterestRateStrategy.calculateInterestRate.selector,
      abi.encode(drawnRateRay)
    );
  }

  function _mockDrawnRateRay(
    address irStrategy,
    uint256 drawnRateRay,
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn,
    uint256 deficit,
    uint256 swept
  ) internal {
    vm.mockCall(
      irStrategy,
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (assetId, liquidity, drawn, deficit, swept)
      ),
      abi.encode(drawnRateRay)
    );
  }

  // @dev Requires no previously added assets
  // @dev Update _assetsSlot below if it changes
  //   Run: forge inspect HubInstance storage-layout
  // @dev Update _addedSharesOffset below if it changes
  //   Have a look at IHub.Asset struct
  function _mockSupplySharePrice(
    IHub hub,
    uint256 assetId,
    uint256 totalAddedAssets,
    uint256 addedShares,
    address spoke,
    address admin,
    uint24 riskPremiumThreshold
  ) internal {
    if (!hub.isSpokeListed(assetId, spoke)) {
      vm.prank(admin);
      hub.addSpoke(
        assetId,
        spoke,
        IHub.SpokeConfig({
          active: true,
          halted: false,
          addCap: MAX_ALLOWED_SPOKE_CAP,
          drawCap: MAX_ALLOWED_SPOKE_CAP,
          riskPremiumThreshold: riskPremiumThreshold
        })
      );
    }
    HubActions.add({
      hub: hub,
      assetId: assetId,
      caller: spoke,
      amount: totalAddedAssets,
      user: makeAddr('alice')
    });
    assertEq(hub.getAddedAssets(assetId), totalAddedAssets, '_mockSupplySharePrice: addedAssets');

    uint256 _assetsSlot = 1;
    uint256 _addedSharesOffset = 1;
    vm.store(
      address(hub),
      bytes32(
        uint256(SlotDerivation.deriveMapping({slot: bytes32(_assetsSlot), key: assetId})) +
          _addedSharesOffset
      ),
      bytes32(addedShares)
    );
    assertEq(hub.getAddedShares(assetId), addedShares, '_mockSupplySharePrice: addedShares');
  }

  function _setConstantDrawnRateBps(
    IHub hub,
    uint256 assetId,
    uint32 drawnRateBps,
    address hubAdmin
  ) internal {
    vm.prank(hubAdmin);
    hub.setInterestRateData(
      assetId,
      abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00,
          baseDrawnRate: drawnRateBps,
          rateGrowthBeforeOptimal: 0,
          rateGrowthAfterOptimal: 0
        })
      )
    );
  }
}
