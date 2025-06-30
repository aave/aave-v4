// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from 'src/dependencies/chainlink/AggregatorV3Interface.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {IAaveOracle} from 'src/interfaces/IAaveOracle.sol';

contract AaveOracle is IAaveOracle, AccessManaged {
  uint256 public immutable override DECIMALS;
  string public override DESCRIPTION;

  mapping(uint256 reserveId => AggregatorV3Interface source) public reserveSource;

  /**
   * @dev Constructor.
   * @dev The authority should implement the AccessManaged interface to control access.
   * @param authority The address of the authority contract which manages permissions.
   * @param decimals The number of decimals for the oracle.
   * @param description The description of the oracle.
   */
  constructor(
    address authority,
    uint256 decimals,
    string memory description
  ) AccessManaged(authority) {
    DECIMALS = decimals;
    DESCRIPTION = description;
    emit AaveOracleCreated(decimals, description);
  }

  function setReserveSource(uint256 reserveId, address source) external override restricted {
    AggregatorV3Interface targetSource = AggregatorV3Interface(source);
    require(targetSource.decimals() == DECIMALS, InvalidSourceDecimals(reserveId));
    reserveSource[reserveId] = targetSource;
    _getSourcePrice(reserveId); // check if the source is valid
    emit ReserveSourceUpdated(reserveId, source);
  }

  function getReservePrice(uint256 reserveId) external view override returns (uint256) {
    return _getSourcePrice(reserveId);
  }

  function getReservesPrices(
    uint256[] calldata reserveIds
  ) external view override returns (uint256[] memory) {
    uint256[] memory prices = new uint256[](reserveIds.length);
    for (uint256 i = 0; i < reserveIds.length; i++) {
      prices[i] = _getSourcePrice(reserveIds[i]);
    }
    return prices;
  }

  function getReserveSource(uint256 reserveId) external view override returns (address) {
    return address(reserveSource[reserveId]);
  }

  function _getSourcePrice(uint256 reserveId) internal view returns (uint256) {
    AggregatorV3Interface source = reserveSource[reserveId];
    if (address(source) == address(0)) {
      revert InvalidSource(reserveId);
    }

    (, int256 price, , , ) = source.latestRoundData();
    if (price < 0) {
      revert InvalidPrice(reserveId);
    }

    return uint256(price);
  }
}
