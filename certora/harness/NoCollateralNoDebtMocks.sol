// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from 'src/dependencies/openzeppelin/ERC20.sol';

/// @notice The real OpenZeppelin ERC20, made deployable. Used as the underlying of every asset.
contract NoCollateralNoDebtERC20 is ERC20 {
  constructor() ERC20('', '') {}
}

/// @notice One price per reserve, held in storage so the Prover picks any value.
/// @dev Like AaveOracle._getSourcePrice, a zero price reverts.
contract NoCollateralNoDebtOracle {
  mapping(uint256 reserveId => uint256) internal _prices;

  function getReservePrice(uint256 reserveId) external view returns (uint256) {
    uint256 price = _prices[reserveId];
    require(price > 0);
    return price;
  }
}
