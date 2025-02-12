// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../../src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../../src/dependencies/openzeppelin/IERC20.sol';
import {WadRayMath} from '../../src/contracts/WadRayMath.sol';
import {MathUtils} from '../../src/contracts/MathUtils.sol';
import {ISpoke} from '../../src/interfaces/ISpoke.sol';
import {ILiquidityHub} from '../../src/interfaces/ILiquidityHub.sol';
import {IReserveInterestRateStrategy} from '../../src/interfaces/IReserveInterestRateStrategy.sol';
import {DataTypes} from '../../src/libraries/types/DataTypes.sol';
import {IDefaultInterestRateStrategy} from '../../src/interfaces/IDefaultInterestRateStrategy.sol';

import 'forge-std/console2.sol';

// Multi asset borrow module with credit line, ie fixed IR for all users
contract MockSpokeCreditLine is ISpoke {
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;

  // fetch liquidity from liquidityHub
  address public liquidityHub;
  address public interestRateStrategy;

  struct Reserve {
    uint256 id;
    address asset;
    uint256 totalDebt;
    uint256 lastUpdateIndex; // TODO? What is this supposed to index on
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
    uint256 balance; // TODO: name to principal balance?
    uint256 lastUpdateIndex; // TODO? What is this supposed to index on
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
      u.balance.rayMul(
        MathUtils.calculateLinearInterest(getInterestRate(assetId), uint40(u.lastUpdateTimestamp))
      );
  }

  function getReserveDebt(uint256 assetId) external view returns (uint256) {
    Reserve storage r = reserves[assetId];
    return
      r.totalDebt.rayMul(
        MathUtils.calculateLinearInterest(getInterestRate(assetId), uint40(r.lastUpdateTimestamp))
      );
  }

  function borrow(uint256 assetId, uint256 amount, address to) external {
    Reserve storage r = reserves[assetId];
    _validateBorrow(r, amount);
    // TODO: decide if state should be updated before or after liquidity hub call
    // update state will update the IR based on total debt
    _updateState(r, assetId, amount, msg.sender);

    // TODO: risk premium; to
    ILiquidityHub(liquidityHub).draw(assetId, amount, 0, to);

    // keep liquidity in borrow module
    IERC20(reserves[assetId].asset).safeTransfer(to, amount);

    emit Borrowed(assetId, amount, to);
  }

  // TODO: Implement repay, calls liquidity hub restore method
  // TODO: onBehalfOf
  function repay(uint256 assetId, uint256 amount) external {
    Reserve storage r = reserves[assetId];
    _updateState(r, assetId, amount, msg.sender);
    ILiquidityHub(liquidityHub).restore(assetId, amount, 0, msg.sender);

    emit Repaid(assetId, amount, msg.sender);
  }

  function setUsingAsCollateral(uint256 assetId, bool usingAsCollateral) external {
    // intentionally left blank
  }

  function supply(uint256 assetId, uint256 amount) external {
    // intentionally left blank
  }

  function withdraw(uint256 assetId, uint256 amount, address to) external {
    // intentionally left blank
  }

  function getHealthFactor(address user) external view returns (uint256) {
    // intentionally left blank
  }

  function getInterestRate(uint256 assetId) public view returns (uint256) {
    // read from state, convert to ray
    return reserves[assetId].borrowRate * 1e23;
  }

  function getUserRiskPremium(address user) external view returns (uint256) {
    // intentionally left blank
  }

  /// governance
  function addReserve(uint256 assetId, ReserveConfig memory params, address asset) external {
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
          assetId: assetId,
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

  function _updateState(
    Reserve storage reserve,
    uint256 assetId,
    uint256 amount,
    address user
  ) internal {
    UserConfig storage userConfig = users[assetId][user];

    _accrueUserInterest(userConfig, reserve, assetId, amount);

    // not needed to update borrow rate for credit line bc IR is fixed
  }

  function _accrueUserInterest(
    UserConfig storage user,
    Reserve storage reserve,
    uint256 assetId,
    uint256 amount
  ) internal {
    user.balance =
      user.balance.rayMul(
        MathUtils.calculateLinearInterest(
          getInterestRate(assetId),
          uint40(user.lastUpdateTimestamp)
        )
      ) +
      amount;
    user.lastUpdateTimestamp = block.timestamp;

    reserve.totalDebt =
      reserve.totalDebt.rayMul(
        MathUtils.calculateLinearInterest(
          getInterestRate(assetId),
          uint40(reserve.lastUpdateTimestamp)
        )
      ) +
      amount;

    reserve.lastUpdateTimestamp = block.timestamp;
  }
}
