// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../../src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../../src/dependencies/openzeppelin/IERC20.sol';
import {WadRayMath} from '../../src/contracts/WadRayMath.sol';
import {MathUtils} from '../../src/contracts/MathUtils.sol';
import {IBorrowModule} from '../../src/interfaces/IBorrowModule.sol';
import {ILiquidityHub} from '../../src/interfaces/ILiquidityHub.sol';
import {IReserveInterestRateStrategy} from '../../src/interfaces/IReserveInterestRateStrategy.sol';
import {DataTypes} from '../../src/libraries/types/DataTypes.sol';

import 'forge-std/console2.sol';

contract MockBorrowModuleCreditLine is IBorrowModule {
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;

  // fetch liquidity from liquidityHub
  address public liquidityHub;
  uint256 public borrowRate;
  address public interestRateStrategy;

  struct Reserve {
    uint256 id;
    address asset;
    uint256 totalDebt;
    uint256 lastUpdateIndex;
    uint256 lastUpdateTimestamp;
    ReserveConfig config;
  }

  struct ReserveConfig {
    uint256 lt;
    uint256 lb; // TODO: liquidationProtocolFee
    uint256 rf;
    bool borrowable;
  }

  struct UserConfig {
    uint256 principalBalance;
    uint256 interestBalance;
    uint256 lastUpdateIndex;
    uint256 lastUpdateTimestamp;
  }
  // asset id => user address => user data
  mapping(uint256 => mapping(address => UserConfig)) public users;
  mapping(uint256 => Reserve) public reserves;

  constructor(address liquidityHubAddress, address interestRateStrategyAddress) {
    liquidityHub = liquidityHubAddress;
    interestRateStrategy = interestRateStrategyAddress;
  }

  function getReserve(uint256 assetId) external view returns (Reserve memory) {
    return reserves[assetId];
  }

  function getUser(uint256 assetId, address user) external view returns (UserConfig memory) {
    UserConfig memory u = users[assetId][user];

    return u;
  }

  function getUserDebt(uint256 assetId, address user) external view returns (uint256) {
    return _getUserDebt(assetId, user);
  }

  function _getUserDebt(uint256 assetId, address user) internal view returns (uint256) {
    UserConfig memory u = users[assetId][user];

    return
      u.principalBalance +
      u.principalBalance.rayMul(
        MathUtils.calculateCompoundedInterest(
          u.lastUpdateIndex,
          uint40(u.lastUpdateTimestamp),
          block.timestamp
        )
      );
  }

  function getReserveDebt(uint256 assetId) external view returns (uint256) {
    Reserve storage r = reserves[assetId];
    return
      r.totalDebt +
      r.totalDebt.rayMul(
        MathUtils.calculateCompoundedInterest(
          r.lastUpdateIndex,
          uint40(r.lastUpdateTimestamp),
          block.timestamp
        )
      );
  }

  function setInterestRate(uint256 rate) external {
    borrowRate = rate;
  }

  function borrow(uint256 assetId, uint256 amount) external {
    Reserve storage r = reserves[assetId];
    _validateBorrow(r, amount);

    ILiquidityHub(liquidityHub).draw(assetId, amount);

    // TODO HF check

    UserConfig storage u = users[assetId][msg.sender];
    _accrueInterest(u, r, amount);

    // keep liquidity in borrow module
    IERC20(reserves[assetId].asset).safeTransfer(msg.sender, amount);

    emit Borrowed(assetId, msg.sender, amount);
  }

  // TODO: Implement repay, calls liquidity hub restore method
  function repay(uint256 assetId, uint256 amount, address onBehalfOf) external {
    ILiquidityHub(liquidityHub).restore(assetId, amount, onBehalfOf);

    emit Repaid(assetId, onBehalfOf, amount);
  }

  function getInterestRate() public view returns (uint256) {
    return borrowRate;
  }

  function calculateInterestRates(
    DataTypes.CalculateInterestRatesParams memory params
  ) public view returns (uint256) {
    return IReserveInterestRateStrategy(interestRateStrategy).calculateInterestRates(params);
  }

  function addReserve(uint256 assetId, ReserveConfig memory params, address asset) external {
    reserves[assetId].id = assetId;
    reserves[assetId].asset = asset;
    reserves[assetId].config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
      rf: params.rf,
      borrowable: params.borrowable
    });
  }
  function _validateBorrow(Reserve storage reserve, uint256 amount) internal view {
    require(reserve.config.borrowable, 'RESERVE_NOT_BORROWABLE');
  }

  function _accrueInterest(
    UserConfig storage user,
    Reserve storage reserve,
    uint256 amount
  ) internal {
    user.principalBalance =
      MathUtils.calculateLinearInterest(getInterestRate(), uint40(user.lastUpdateTimestamp)).rayMul(
        user.principalBalance
      ) +
      amount;
    user.lastUpdateTimestamp = block.timestamp;

    reserve.totalDebt =
      MathUtils
        .calculateLinearInterest(getInterestRate(), uint40(reserve.lastUpdateTimestamp))
        .rayMul(reserve.totalDebt) +
      amount;

    reserve.lastUpdateTimestamp = block.timestamp;
  }
}
