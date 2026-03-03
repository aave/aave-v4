// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
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

  function _mockInterestRateBps(address interestRateStrategy, uint256 interestRateBps) internal {
    vm.mockCall(
      interestRateStrategy,
      IBasicInterestRateStrategy.calculateInterestRate.selector,
      abi.encode(_bpsToRay(interestRateBps))
    );
  }

  function _mockInterestRateBps(
    address interestRateStrategy,
    uint256 interestRateBps,
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn,
    uint256 deficit,
    uint256 swept
  ) internal {
    vm.mockCall(
      interestRateStrategy,
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (assetId, liquidity, drawn, deficit, swept)
      ),
      abi.encode(_bpsToRay(interestRateBps))
    );
  }

  function _mockInterestRateRay(address interestRateStrategy, uint256 interestRateRay) internal {
    vm.mockCall(
      interestRateStrategy,
      IBasicInterestRateStrategy.calculateInterestRate.selector,
      abi.encode(interestRateRay)
    );
  }

  function _mockInterestRateRay(
    address interestRateStrategy,
    uint256 interestRateRay,
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn,
    uint256 deficit,
    uint256 swept
  ) internal {
    vm.mockCall(
      interestRateStrategy,
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (assetId, liquidity, drawn, deficit, swept)
      ),
      abi.encode(interestRateRay)
    );
  }

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

    uint256 _assetsSlot = 2;
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

  function _setConstantInterestRateBps(
    IHub hub,
    uint256 assetId,
    uint32 interestRateBps,
    address hubAdmin
  ) internal {
    vm.prank(hubAdmin);
    hub.setInterestRateData(
      assetId,
      abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00,
          baseVariableBorrowRate: interestRateBps,
          variableRateSlope1: 0,
          variableRateSlope2: 0
        })
      )
    );
  }
}
