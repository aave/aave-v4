// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IPriceOracle} from './IPriceOracle.sol';

interface IAaveOracle is IPriceOracle {
  event AaveOracleCreated(uint256 indexed decimals, string indexed description);
  event ReserveSourceUpdated(uint256 indexed reserveId, address indexed source);

  error InvalidSourceDecimals(uint256 reserveId);
  error InvalidSource(uint256 reserveId);
  error InvalidPrice(uint256 reserveId);

  function setReserveSource(uint256 reserveId, address source) external;

  function getReservesPrices(
    uint256[] calldata reserveIds
  ) external view returns (uint256[] memory);

  function getReserveSource(uint256 reserveId) external view returns (address);
}
