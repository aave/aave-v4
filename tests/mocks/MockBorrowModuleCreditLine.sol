// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../../src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../../src/dependencies/openzeppelin/IERC20.sol';
import {WadRayMath} from '../../src/contracts/WadRayMath.sol';
import {IBorrowModule} from '../../src/interfaces/IBorrowModule.sol';
import {ILiquidityHub} from '../../src/interfaces/ILiquidityHub.sol';

contract BorrowModule is IBorrowModule {
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;

  // fetch liquidity from liquidityHub

  address public liquidityHub;

  constructor(address liquidityHubAddress) {
    liquidityHub = liquidityHubAddress;
  }

  function borrow(uint256 assetId, uint256 amount) external {
    ILiquidityHub(liquidityHub).draw(assetId, amount);
  }

  function repay(uint256 assetId, uint256 amount, address onBehalfOf) external {}

  function getInterestRate() public pure returns (uint256) {
    return 0.1e27; // 10%
  }

  function calculateInterestRates() public pure returns (uint256) {
    // borrowRate
    return 0;
  }
}
