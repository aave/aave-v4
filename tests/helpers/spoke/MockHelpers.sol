// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CommonHelpers} from 'tests/helpers/commons/CommonHelpers.sol';
import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {MockPriceFeed} from 'tests/helpers/mocks/MockPriceFeed.sol';

/// @title MockHelpers
/// @notice Spoke-level mocking utilities for the Aave V4 test suite.
abstract contract MockHelpers is CommonHelpers {
  using WadRayMath for *;
  using PercentageMath for uint256;

  function _mockReservePrice(
    ISpoke spoke,
    uint256 reserveId,
    uint256 price,
    address admin
  ) internal {
    require(price > 0, 'mockReservePrice: price must be positive');
    AaveOracle oracle = AaveOracle(spoke.ORACLE());
    address mockPriceFeed = address(new MockPriceFeed(oracle.decimals(), 'mock price feed', price));
    vm.prank(admin);
    spoke.updateReservePriceSource(reserveId, mockPriceFeed);
  }

  function _mockReservePriceByPercent(
    ISpoke spoke,
    uint256 reserveId,
    uint256 percentage,
    address admin
  ) internal {
    uint256 initialPrice = IPriceOracle(spoke.ORACLE()).getReservePrice(reserveId);
    uint256 newPrice = initialPrice.percentMulDown(percentage);
    _mockReservePrice(spoke, reserveId, newPrice, admin);
  }

  function _deployMockPriceFeed(ISpoke spoke, uint256 price) internal returns (address) {
    AaveOracle oracle = AaveOracle(spoke.ORACLE());
    return address(new MockPriceFeed(oracle.decimals(), 'mock price feed', price));
  }

  function _mockDecimals(address underlying, uint8 decimals) internal {
    vm.mockCall(
      underlying,
      abi.encodeWithSelector(IERC20Metadata.decimals.selector),
      abi.encode(decimals)
    );
  }
}
