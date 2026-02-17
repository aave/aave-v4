// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseState} from 'tests/base/BaseState.sol';
import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {SlotDerivation} from 'src/dependencies/openzeppelin/SlotDerivation.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {
  IAssetInterestRateStrategy,
  IBasicInterestRateStrategy
} from 'src/hub/AssetInterestRateStrategy.sol';
import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {Constants} from 'tests/Constants.sol';
import {Utils} from 'tests/Utils.sol';
import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';

abstract contract MockHelpers is BaseState {
  using WadRayMath for *;
  using PercentageMath for uint256;

  function _mockInterestRateBps(uint256 interestRateBps) internal {
    _mockInterestRateBps(address(irStrategy), interestRateBps);
  }

  function _mockInterestRateBps(address interestRateStrategy, uint256 interestRateBps) internal {
    vm.mockCall(
      interestRateStrategy,
      IBasicInterestRateStrategy.calculateInterestRate.selector,
      abi.encode(_bpsToRay(interestRateBps))
    );
  }

  function _mockInterestRateBps(
    uint256 interestRateBps,
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn,
    uint256 deficit,
    uint256 swept
  ) internal {
    _mockInterestRateBps(
      address(irStrategy),
      interestRateBps,
      assetId,
      liquidity,
      drawn,
      deficit,
      swept
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

  function _mockInterestRateRay(uint256 interestRateRay) internal {
    _mockInterestRateRay(address(irStrategy), interestRateRay);
  }

  function _mockInterestRateRay(address interestRateStrategy, uint256 interestRateRay) internal {
    vm.mockCall(
      interestRateStrategy,
      IBasicInterestRateStrategy.calculateInterestRate.selector,
      abi.encode(interestRateRay)
    );
  }

  function _mockInterestRateRay(
    uint256 interestRateRay,
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn
  ) internal {
    _mockInterestRateRay(address(irStrategy), interestRateRay, assetId, liquidity, drawn, 0, 0);
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

  function _mockReservePrice(ISpoke spoke, uint256 reserveId, uint256 price) internal {
    require(price > 0, 'mockReservePrice: price must be positive');
    AaveOracle oracle = AaveOracle(spoke.ORACLE());
    address mockPriceFeed = address(
      new MockPriceFeed(oracle.DECIMALS(), oracle.DESCRIPTION(), price)
    );
    vm.prank(address(ADMIN));
    spoke.updateReservePriceSource(reserveId, mockPriceFeed);
  }

  function _mockReservePriceByPercent(
    ISpoke spoke,
    uint256 reserveId,
    uint256 percentage
  ) internal {
    uint256 initialPrice = IPriceOracle(spoke.ORACLE()).getReservePrice(reserveId);
    uint256 newPrice = initialPrice.percentMulDown(percentage);
    _mockReservePrice(spoke, reserveId, newPrice);
  }

  function _deployMockPriceFeed(ISpoke spoke, uint256 price) internal returns (address) {
    AaveOracle oracle = AaveOracle(spoke.ORACLE());
    return address(new MockPriceFeed(oracle.DECIMALS(), oracle.DESCRIPTION(), price));
  }

  function _mockDecimals(address underlying, uint8 decimals) internal {
    vm.mockCall(
      underlying,
      abi.encodeWithSelector(IERC20Metadata.decimals.selector),
      abi.encode(decimals)
    );
  }

  function _mockSupplySharePrice(
    IHub hub,
    uint256 assetId,
    uint256 totalAddedAssets,
    uint256 addedShares
  ) internal {
    if (!hub.isSpokeListed(assetId, address(spoke1))) {
      vm.prank(ADMIN);
      hub.addSpoke(
        assetId,
        address(spoke1),
        IHub.SpokeConfig({
          active: true,
          halted: false,
          addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
          drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
          riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
        })
      );
    }
    Utils.add({
      hub: hub,
      assetId: assetId,
      caller: address(spoke1),
      amount: totalAddedAssets,
      user: alice
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

  function _setConstantInterestRateBps(IHub hub, uint256 assetId, uint32 interestRateBps) internal {
    vm.prank(HUB_ADMIN);
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
