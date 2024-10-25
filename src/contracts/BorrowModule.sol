// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../dependencies/openzeppelin/IERC20.sol';
import {WadRayMath} from './WadRayMath.sol';
import {MathUtils} from './MathUtils.sol';
import {ILiquidityHub} from '../interfaces/ILiquidityHub.sol';
import {IBorrowModule} from '../interfaces/IBorrowModule.sol';
import {IReserveInterestRateStrategy} from '../../src/interfaces/IReserveInterestRateStrategy.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';

contract BorrowModule is IBorrowModule {
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;

  // debt balances, fetches indexes from liquidity layer

  // keep collateral configuration
  // By using BorrowModule, LPs can choose which collaterals are used to borrow their assets

  // keep hooks to be executed by LiquidityHub when there is supply/withdraw actions

  // fetch liquidity from liquidityHub
  address public liquidityHub;
  address public interestRateStrategy;

  struct Reserve {
    uint256 id;
    address asset;
    uint256 totalDebt;
    uint256 lastUpdateIndex;
    uint256 lastUpdateTimestamp;
    uint256 borrowRate;
    ReserveConfig config;
  }

  struct ReserveConfig {
    uint256 lt;
    uint256 lb; // TODO: liquidationProtocolFee
    uint256 rf;
    bool borrowable;
  }

  struct UserConfig {
    uint256 balance;
    uint256 lastUpdateIndex;
    uint256 lastUpdateTimestamp;
  }

  // asset id => user address => user data
  mapping(uint256 => mapping(address => UserConfig)) public users;
  // assetId => reserveData
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
      u.balance.rayMul(
        MathUtils.calculateCompoundedInterest(
          getInterestRate(assetId),
          uint40(u.lastUpdateTimestamp),
          block.timestamp
        )
      );
  }

  function getReserveDebt(uint256 assetId) external view returns (uint256) {
    Reserve storage r = reserves[assetId];
    return
      r.totalDebt.rayMul(
        MathUtils.calculateCompoundedInterest(
          getInterestRate(assetId),
          uint40(r.lastUpdateTimestamp),
          block.timestamp
        )
      );
  }

  function borrow(uint256 assetId, uint256 amount) external {
    Reserve storage r = reserves[assetId];
    _validateBorrow(r, amount);
    // TODO HF check

    ILiquidityHub(liquidityHub).draw(assetId, amount);

    _updateState(r, assetId, amount, msg.sender);

    // transfer liquidity to msg.sender
    IERC20(reserves[assetId].asset).safeTransfer(msg.sender, amount);

    emit Borrowed(assetId, msg.sender, amount);
  }

  // TODO: Implement repay, calls liquidity hub restore method
  // TODO: onBehalfOf
  function repay(uint256 assetId, uint256 amount) external {
    ILiquidityHub(liquidityHub).restore(assetId, amount);

    emit Repaid(assetId, msg.sender, amount);
  }

  function getInterestRate(uint256 assetId) public view returns (uint256) {
    // read from state, convert to ray
    return reserves[assetId].borrowRate * 1e23;
  }

  // /////
  // Governance
  // /////

  function addReserve(uint256 assetId, ReserveConfig memory params, address asset) external {
    // TODO: AccessControl
    reserves[assetId].id = assetId;
    reserves[assetId].asset = asset;
    reserves[assetId].config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
      rf: params.rf,
      borrowable: params.borrowable
    });

    reserves[assetId].borrowRate = IReserveInterestRateStrategy(interestRateStrategy)
      .calculateInterestRates(
        DataTypes.CalculateInterestRatesParams({
          liquidityAdded: 0,
          liquidityTaken: 0,
          totalDebt: 0,
          reserveFactor: params.rf,
          assetId: reserves[assetId].id,
          virtualUnderlyingBalance: 0,
          usingVirtualBalance: false
        })
      );
  }

  function updateReserve(uint256 assetId, ReserveConfig memory params) external {
    // TODO: More sophisticated
    require(reserves[assetId].id != 0, 'INVALID_RESERVE');
    // TODO: AccessControl
    reserves[assetId].config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
      rf: params.rf,
      borrowable: params.borrowable
    });
  }

  // TODO: access control
  function updateInterestRateStrategy(address newInterestRateStrategy) external {
    interestRateStrategy = newInterestRateStrategy;
  }

  function _validateBorrow(Reserve storage reserve, uint256 amount) internal view {
    require(reserve.config.borrowable, 'RESERVE_NOT_BORROWABLE');
  }

  /// @dev does 2 things - update borrow rate for this asset; update user and reserve debt balances
  function _updateState(
    Reserve storage reserve,
    uint256 assetId,
    uint256 amount,
    address user
  ) internal {
    UserConfig storage userConfig = users[assetId][user];
    _accrueUserInterest(userConfig, reserve, assetId, amount);

    reserves[assetId].borrowRate = IReserveInterestRateStrategy(interestRateStrategy)
      .calculateInterestRates(
        DataTypes.CalculateInterestRatesParams({
          liquidityAdded: 0, // TODO
          liquidityTaken: 0, // TODO
          totalDebt: reserve.totalDebt,
          reserveFactor: reserve.config.rf,
          assetId: reserve.id,
          virtualUnderlyingBalance: 0, // TODO
          usingVirtualBalance: false // TODO
        })
      );

    uint256 cumulatedInterest = MathUtils.calculateCompoundedInterest(
      getInterestRate(assetId),
      uint40(reserve.lastUpdateTimestamp),
      block.timestamp
    );
    reserve.lastUpdateIndex = reserve.totalDebt.rayMul(cumulatedInterest); // TODO: update index
  }

  function _accrueUserInterest(
    UserConfig storage user,
    Reserve storage reserve,
    uint256 assetId,
    uint256 amount
  ) internal {
    // update user debt balance
    // accrue interest
    // TODO: Risk premium for user and reserve
    user.balance =
      user.balance.rayMul(
        MathUtils.calculateCompoundedInterest(
          getInterestRate(assetId),
          uint40(user.lastUpdateTimestamp),
          block.timestamp
        )
      ) +
      amount;
    user.lastUpdateTimestamp = block.timestamp;

    reserve.totalDebt =
      reserve.totalDebt.rayMul(
        MathUtils.calculateCompoundedInterest(
          getInterestRate(assetId),
          uint40(reserve.lastUpdateTimestamp),
          block.timestamp
        )
      ) +
      amount;

    reserve.lastUpdateTimestamp = block.timestamp;

    // TODO: update index
  }
}
