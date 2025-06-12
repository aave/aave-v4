// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';

contract MockPriceOracle is IPriceOracle {
  // Map of reserve prices (reserveId => price)
  mapping(uint256 => uint256) internal prices;

  uint256 internal ethPriceUsd;

  event ReservePriceUpdated(uint256 reserveId, uint256 price, uint256 timestamp);
  event EthPriceUpdated(uint256 price, uint256 timestamp);

  function getReservePrice(uint256 reserveId) external view override returns (uint256) {
    return prices[reserveId];
  }

  function setReservePrice(uint256 reserveId, uint256 price) external {
    prices[reserveId] = price;
    emit ReservePriceUpdated(reserveId, price, block.timestamp);
  }

  function getEthUsdPrice() external view returns (uint256) {
    return ethPriceUsd;
  }

  function setEthUsdPrice(uint256 price) external {
    ethPriceUsd = price;
    emit EthPriceUpdated(price, block.timestamp);
  }
}
