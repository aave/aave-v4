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
import {IDefaultInterestRateStrategy} from '../../src/interfaces/IDefaultInterestRateStrategy.sol';

import 'forge-std/console2.sol';

// Multi asset borrow module with credit line, ie fixed IR for all users
contract MockBorrowModuleCreditLine is IBorrowModule {
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;

  // fetch liquidity from liquidityHub
  address public liquidityHub;
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
  mapping(uint256 => uint256) public borrowRates; // assetId => borrowRate

  constructor(
    address liquidityHubAddress,
    address interestRateStrategyAddress,
    uint256[] memory assetIds
  ) {
    liquidityHub = liquidityHubAddress;
    interestRateStrategy = interestRateStrategyAddress;
    for (uint256 i; i < assetIds.length; i++) {
      borrowRates[assetIds[i]] = calculateInterestRates(
        DataTypes.CalculateInterestRatesParams({
          liquidityAdded: 0,
          liquidityTaken: 0,
          totalDebt: 0,
          reserveFactor: 0,
          assetId: assetIds[i],
          virtualUnderlyingBalance: 0,
          usingVirtualBalance: false
        })
      );
    }
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
      r.totalDebt.rayMul(
        MathUtils.calculateLinearInterest(getInterestRate(assetId), uint40(r.lastUpdateTimestamp))
      );
  }

  function borrow(uint256 assetId, uint256 amount) external {
    Reserve storage r = reserves[assetId];
    _validateBorrow(r, amount);

    _updateState(r);

    ILiquidityHub(liquidityHub).draw(assetId, amount);

    UserConfig storage u = users[assetId][msg.sender];
    _accrueInterest(u, r, assetId, amount);

    // keep liquidity in borrow module
    IERC20(reserves[assetId].asset).safeTransfer(msg.sender, amount);

    emit Borrowed(assetId, msg.sender, amount);
  }

  // TODO: Implement repay, calls liquidity hub restore method
  function repay(uint256 assetId, uint256 amount, address onBehalfOf) external {
    Reserve storage r = reserves[assetId];
    _updateState(r);
    ILiquidityHub(liquidityHub).restore(assetId, amount, onBehalfOf);

    emit Repaid(assetId, onBehalfOf, amount);
  }

  function getInterestRate(uint256 assetId) public view returns (uint256) {
    return borrowRates[assetId];
  }

  function calculateInterestRates(
    DataTypes.CalculateInterestRatesParams memory params
  ) public view returns (uint256) {
    return IReserveInterestRateStrategy(interestRateStrategy).calculateInterestRates(params) * 1e24; // convert to ray
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

  function _updateState(Reserve memory reserve) internal {
    borrowRates[reserve.id] = calculateInterestRates(
      DataTypes.CalculateInterestRatesParams({
        liquidityAdded: 0,
        liquidityTaken: 0,
        totalDebt: reserve.totalDebt,
        reserveFactor: 0,
        assetId: reserve.id,
        virtualUnderlyingBalance: 0,
        usingVirtualBalance: false
      })
    );
  }

  function _accrueInterest(
    UserConfig storage user,
    Reserve storage reserve,
    uint256 assetId,
    uint256 amount
  ) internal {
    user.principalBalance =
      MathUtils
        .calculateLinearInterest(getInterestRate(assetId), uint40(user.lastUpdateTimestamp))
        .rayMul(user.principalBalance) +
      amount;
    user.lastUpdateTimestamp = block.timestamp;

    reserve.totalDebt =
      MathUtils
        .calculateLinearInterest(getInterestRate(assetId), uint40(reserve.lastUpdateTimestamp))
        .rayMul(reserve.totalDebt) +
      amount;

    reserve.lastUpdateTimestamp = block.timestamp;
  }
}
