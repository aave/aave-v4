// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from 'src/dependencies/chainlink/AggregatorV3Interface.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {IAaveOracle, IPriceOracle} from 'src/interfaces/IAaveOracle.sol';

/**
 * @title AaveOracle contract
 * @author Aave Labs
 * @notice Oracle contract for the Aave protocol
 * @dev Oracles are spoke-specific: one oracle CAN'T be used across different spoke
 *   due to the usage of reserve id as index of the _reserveSource
 */
contract AaveOracle is IAaveOracle, AccessManaged {
  /// @inheritdoc IPriceOracle
  uint8 public immutable override DECIMALS;
  /// @inheritdoc IPriceOracle
  string public override DESCRIPTION;

  mapping(uint256 reserveId => AggregatorV3Interface source) internal _reserveSource;

  /**
   * @dev Constructor.
   * @dev The authority should implement the AccessManaged interface to control access.
   * @param authority The address of the authority contract which manages permissions.
   * @param decimals The number of decimals for the oracle.
   * @param description The description of the oracle.
   */
  constructor(
    address authority,
    uint8 decimals,
    string memory description
  ) AccessManaged(authority) {
    DECIMALS = decimals;
    DESCRIPTION = description;
    emit AaveOracleCreated(decimals, description);
  }

  /// @inheritdoc IAaveOracle
  function setReserveSource(uint256 reserveId, address source) external override restricted {
    AggregatorV3Interface targetSource = AggregatorV3Interface(source);
    require(targetSource.decimals() == DECIMALS, InvalidSourceDecimals(reserveId));
    _reserveSource[reserveId] = targetSource;
    _getSourcePrice(reserveId); // check if the source is valid
    emit ReserveSourceUpdated(reserveId, source);
  }

  /// @inheritdoc IPriceOracle
  function getReservePrice(uint256 reserveId) external view override returns (uint256) {
    return _getSourcePrice(reserveId);
  }

  /// @inheritdoc IAaveOracle
  function getReservesPrices(
    uint256[] calldata reserveIds
  ) external view override returns (uint256[] memory) {
    uint256[] memory prices = new uint256[](reserveIds.length);
    for (uint256 i = 0; i < reserveIds.length; i++) {
      prices[i] = _getSourcePrice(reserveIds[i]);
    }
    return prices;
  }

  /// @inheritdoc IAaveOracle
  function getReserveSource(uint256 reserveId) external view override returns (address) {
    return address(_reserveSource[reserveId]);
  }

  function _getSourcePrice(uint256 reserveId) internal view returns (uint256) {
    AggregatorV3Interface source = _reserveSource[reserveId];
    if (address(source) == address(0)) {
      revert InvalidSource(reserveId);
    }

    (, int256 price, , , ) = source.latestRoundData();
    if (price <= 0) {
      revert InvalidPrice(reserveId);
    }

    return uint256(price);
  }
}
