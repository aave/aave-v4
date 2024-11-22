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
    UserConfig memory u = users[assetId][user];
    // TODO: Instead use a getter from liquidity hub to get up-to-date user debt (with accrued debt)
    return
      u.debtShares.rayMul(
        MathUtils.calculateCompoundedInterest(getInterestRate(assetId), uint40(0), block.timestamp)
      );
  }

  function getReserveDebt(uint256 assetId) external view returns (uint256) {
    Reserve storage r = reserves[assetId];

    // TODO: Instead use a getter from liquidity hub to get up-to-date reserve debt (with accrued debt)
    // return
    //   r.totalDebt.rayMul(
    //     MathUtils.calculateCompoundedInterest(getInterestRate(assetId), uint40(0), block.timestamp)
    //   );
    return 0;
  }

  // /////
  // Users
  // /////

  function supply(uint256 assetId, uint256 amount) external {
    Reserve storage r = reserves[assetId];

    _validateSupply(r, amount);

    (, uint256 newAggregatedRiskPremium) = _refreshRiskPremium();
    IERC20(r.asset).safeTransferFrom(msg.sender, liquidityHub, amount);
    uint256 userShares = ILiquidityHub(liquidityHub).supply(
      assetId,
      amount,
      newAggregatedRiskPremium
    );

    users[assetId][msg.sender].supplyShares += userShares;

    emit Supplied(assetId, msg.sender, amount);
  }

  function withdraw(uint256 assetId, address to, uint256 amount) external {
    Reserve storage r = reserves[assetId];
    UserConfig storage u = users[assetId][msg.sender];
    _validateWithdraw(assetId, r, u, amount);

    (, uint256 newAggregatedRiskPremium) = _refreshRiskPremium();
    uint256 userShares = ILiquidityHub(liquidityHub).withdraw(
      assetId,
      to,
      amount,
      newAggregatedRiskPremium
    );
    users[assetId][msg.sender].supplyShares -= userShares;

    emit Withdrawn(assetId, msg.sender, amount);
  }

  function borrow(uint256 assetId, address to, uint256 amount) external {
    // TODO: referral code
    // TODO: onBehalfOf with credit delegation
    Reserve storage r = reserves[assetId];
    _validateBorrow(r, amount);

    // TODO HF check
    (, uint256 newAggregatedRiskPremium) = _refreshRiskPremium();
    uint256 userShares = ILiquidityHub(liquidityHub).draw(
      assetId,
      to,
      amount,
      newAggregatedRiskPremium
    );
    // debt still goes to original msg.sender
    users[assetId][msg.sender].debtShares += userShares;

    emit Borrowed(assetId, to, amount);
  }

  function repay(uint256 assetId, uint256 amount) external {
    // TODO: Implement repay, calls liquidity hub restore method
    // TODO: onBehalfOf

    UserConfig storage u = users[assetId][msg.sender];
    Reserve storage r = reserves[assetId];
    _validateRepay(assetId, u, amount);

    (, uint256 newAggregatedRiskPremium) = _refreshRiskPremium();
    IERC20(r.asset).safeTransferFrom(msg.sender, liquidityHub, amount);
    uint256 userShares = ILiquidityHub(liquidityHub).restore(
      assetId,
      amount,
      newAggregatedRiskPremium
    );
    users[assetId][msg.sender].debtShares -= userShares;

    emit Repaid(assetId, msg.sender, amount);
  }

  // TODO: Needed?
  function getInterestRate(uint256 assetId) public view returns (uint256) {
    // read from state, convert to ray
    // TODO: should be final IR rather than base?
    return ILiquidityHub(liquidityHub).getBaseInterestRate(assetId);
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

  function _validateWithdraw(
    uint256 assetId,
    Reserve storage reserve,
    UserConfig storage user,
    uint256 amount
  ) internal view {
    require(
      ILiquidityHub(liquidityHub).convertSharesToAssetsDown(assetId, user.supplyShares) >= amount,
      'INSUFFICIENT_SUPPLY'
    );
  }

  function _validateBorrow(Reserve storage reserve, uint256 amount) internal view {
    require(reserve.config.borrowable, 'RESERVE_NOT_BORROWABLE');
  }

  function _validateRepay(uint256 assetId, UserConfig storage user, uint256 amount) internal view {
    require(
      ILiquidityHub(liquidityHub).convertSharesToAssetsUp(assetId, user.debtShares) >= amount,
      'REPAY_EXCEEDS_DEBT'
    );
  }

  /**
  @return uint256 new risk premium
  @return uint256 new aggregated risk premium
  */
  function _refreshRiskPremium() internal returns (uint256, uint256) {
    // TODO: update state - debt shares

    // TODO: refresh risk premium of user, specific assets user has supplied
    uint256 newUserRiskPremium = 0;
    // TODO: aggregated risk premium, ie loop over all assets and sum up risk premium
    uint256 newAggregatedRiskPremium = 0;
    return (newUserRiskPremium, newAggregatedRiskPremium);
  }
}
