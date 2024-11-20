// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../dependencies/openzeppelin/IERC20.sol';
import {WadRayMath} from './WadRayMath.sol';
import {MathUtils} from './MathUtils.sol';
import {ILiquidityHub} from '../interfaces/ILiquidityHub.sol';
import {ISpoke} from '../interfaces/ISpoke.sol';
import {IReserveInterestRateStrategy} from '../../src/interfaces/IReserveInterestRateStrategy.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';

contract Spoke is ISpoke {
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;

  address public liquidityHub;

  struct Reserve {
    uint256 id;
    address asset;
    // uint256 totalDebt;
    // uint256 lastUpdateIndex;
    // uint256 lastUpdateTimestamp;
    ReserveConfig config;
  }

  struct ReserveConfig {
    uint256 lt;
    uint256 lb; // TODO: liquidationProtocolFee
    bool borrowable;
    bool collateral;
  }

  struct UserConfig {
    uint256 supplyShares;
    uint256 debtShares;
    // uint256 balance;
    // uint256 lastUpdateIndex;
    // uint256 lastUpdateTimestamp;
  }

  // reserve id => user address => user data
  mapping(uint256 => mapping(address => UserConfig)) public users;
  // reserve id => reserveData
  mapping(uint256 => Reserve) public reserves;

  constructor(address liquidityHubAddress) {
    liquidityHub = liquidityHubAddress;
  }

  function getReserve(uint256 assetId) external view returns (Reserve memory) {
    return reserves[assetId];
  }

  function getUser(uint256 assetId, address user) external view returns (UserConfig memory) {
    UserConfig memory u = users[assetId][user];

    return u;
  }

  function getUserDebt(uint256 assetId, address user) external view returns (uint256) {
    // TODO: Instead use a getter from liquidity hub to get up-to-date user debt (with accrued debt)
    return 0;
  }

  function getReserveDebt(uint256 assetId) external view returns (uint256) {
    Reserve storage r = reserves[assetId];

    // TODO: Instead use a getter from liquidity hub to get up-to-date reserve debt (with accrued debt)
    return 0;
  }

  function supply(uint256 assetId, uint256 amount) external {
    Reserve storage r = reserves[assetId];

    _validateSupply(r, amount);

    // TODO: Refresh risk premium of user, and pass into following function
    (uint256 newRiskPremium, ) = _updateState();
    uint256 userShares = ILiquidityHub(liquidityHub).supply(assetId, amount, newRiskPremium);

    users[assetId][msg.sender].supplyShares += userShares;

    emit Supplied(assetId, msg.sender, amount);
  }

  function withdraw(uint256 assetId, address to, uint256 amount) external {
    Reserve storage r = reserves[assetId];

    _validateWithdraw(r, amount);

    // TODO: Refresh risk premium of user, and pass into following function
    (uint256 newRiskPremium, ) = _updateState();
    uint256 userShares = ILiquidityHub(liquidityHub).withdraw(assetId, to, amount, newRiskPremium);
    users[assetId][msg.sender].supplyShares -= userShares;

    emit Withdrawn(assetId, msg.sender, amount);
  }

  // TODO: On behalf of and referral code
  function borrow(uint256 assetId, address to, uint256 amount) external {
    Reserve storage r = reserves[assetId];
    _validateBorrow(r, amount);

    // TODO HF check
    // TODO: risk premium implementation
    (uint256 newRiskPremium, ) = _updateState();
    uint256 userDebtShares = ILiquidityHub(liquidityHub).draw(assetId, to, amount, newRiskPremium);
    users[assetId][msg.sender].debtShares += userDebtShares;

    // transfer liquidity to msg.sender
    IERC20(reserves[assetId].asset).safeTransfer(to, amount);

    emit Borrowed(assetId, to, amount);
  }

  // TODO: Implement repay, calls liquidity hub restore method
  // TODO: onBehalfOf
  function repay(uint256 assetId, uint256 amount) external {
    _validateRepay();

    (uint256 newRiskPremium, ) = _updateState();
    // TODO calculate risk premium and pass to LH
    uint256 userDebtShares = ILiquidityHub(liquidityHub).restore(assetId, amount, newRiskPremium);
    users[assetId][msg.sender].debtShares -= userDebtShares;

    emit Repaid(assetId, msg.sender, amount);
  }

  // TODO: Needed?
  function getInterestRate(uint256 assetId) public view returns (uint256) {
    // read from state, convert to ray
    return ILiquidityHub(liquidityHub).getInterestRate(assetId);
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
      borrowable: params.borrowable,
      collateral: params.collateral
    });
  }

  function updateReserve(uint256 assetId, ReserveConfig memory params) external {
    // TODO: More sophisticated
    require(reserves[assetId].id != 0, 'INVALID_RESERVE');
    // TODO: AccessControl
    reserves[assetId].config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
      borrowable: params.borrowable,
      collateral: params.collateral
    });
  }

  function _validateSupply(Reserve storage reserve, uint256 amount) internal view {
    // TODO: Decide where supply cap is checked
    require(reserve.asset != address(0), 'RESERVE_NOT_LISTED');
  }

  function _validateWithdraw(Reserve storage reserve, uint256 amount) internal view {
    // TODO: Call liqudity hub to get the conversion rate for assets to shares
    /*require(
      users[reserve.id][msg.sender].supplyShares >= amount.toSharesDown(),
      'INSUFFICIENT_BALANCE'
    );*/
  }

  function _validateBorrow(Reserve storage reserve, uint256 amount) internal view {
    require(reserve.config.borrowable, 'RESERVE_NOT_BORROWABLE');
  }

  function _validateRepay() internal view {
    //TODO: validate repay, ie there is outstanding debt
  }

  /**
  @return uint256 new risk premium
  @return uint256 new aggregated risk premium
  */
  function _updateState() internal returns (uint256, uint256) {
    // TODO: refresh risk premium of user; aggregated risk premium
    uint256 newRiskPremium = 0;
    uint256 newAggregatedRiskPremium = 0;
    return (newRiskPremium, newAggregatedRiskPremium);
  }
}
