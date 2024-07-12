// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../dependencies/openzeppelin/IERC20.sol';
import {AccessManagerContract} from './AccessManagerContract.sol';

contract LiquidityHub is AccessManagerContract {
  using SafeERC20 for IERC20;

  struct Reserve {
    uint256 id;
    uint256 supplyIndex;
    uint256 supplyRate;
    uint256 borrowIndex;
    uint256 borrowRate;
    uint256 lastUpdateTimestamp;
    uint256 virtualBalance;
    ReserveConfig config;
  }

  struct ReserveConfig {
    address borrowModule;
    uint256 lt;
    uint256 lb; // TODO: liquidationProtocolFee
    // uint256 liquidityPremium; // TODO
    uint256 rf;
    uint256 decimals;
    bool active; // TODO: frozen, paused
    bool borrowable;
    uint256 supplyCap;
    uint256 borrowCap;
    // uint256 eModeCategory; // TODO eMode
    // uint256 debtCeiling; // TODO isolation mode
  }

  struct UserConfig {
    uint256 principalBalance;
    uint256 interestBalance;
    uint256 lastUpdateIndex;
    uint256 lastUpdateTimestamp;
  }

  // asset id => reserve data
  mapping(uint256 => Reserve) public reserves;
  address[] public reservesList; // TODO: Check if Enumerable or Set makes more sense
  uint256 reserveCount;

  // asset id => user address => user data
  mapping(uint256 => mapping(address => UserConfig)) public users;

  constructor() AccessManagerContract() {}

  // /////
  // Governance
  // /////

  function addReserve(ReserveConfig memory params, address asset) external onlyRole(RESERVE_CONTROLLER) {
    // TODO: AccessControl
    reservesList.push(asset);
    reserves[reserveCount] = Reserve({
      id: reserveCount,
      supplyIndex: 0,
      supplyRate: 0,
      borrowIndex: 0,
      borrowRate: 0,
      lastUpdateTimestamp: block.timestamp,
      virtualBalance: 0,
      config: ReserveConfig({
        borrowModule: params.borrowModule,
        lt: params.lt,
        lb: params.lb,
        rf: params.rf,
        decimals: params.decimals,
        active: params.active,
        borrowable: params.borrowable,
        supplyCap: params.supplyCap,
        borrowCap: params.borrowCap
      })
    });
    reserveCount++;
  }

  // /////
  // Users
  // /////

  function supply(uint256 assetId, uint256 amount) external {
    // TODO: onBehalf
    Reserve storage reserve = reserves[assetId];
    UserConfig storage user = users[assetId][msg.sender];

    _validateSupply(reserve, amount);

    // update indexes and IRs
    _updateState(reserve); // TODO

    // invokes borrow modules in case accounting update is needed
    // (eg, update premium for users borrowing using the asset as collateral)
    // TODO

    // updates user accounting
    // user.onSupply( assetData, amount);
    reserve.virtualBalance += amount;
    // TODO reserve.supplyIndex
    reserve.lastUpdateTimestamp = block.timestamp;
    user.principalBalance += amount;
    // TODO user.lastUpdateIndex
    // TODO accumulate user.interestBalance into user.principalBalance
    user.lastUpdateTimestamp = block.timestamp;

    // transferFrom
    IERC20(reservesList[assetId]).safeTransferFrom(msg.sender, address(this), amount); // TODO: fee-on-transfer
  }

  function withdraw(uint256 assetId, uint256 amount) external {
    // TODO: onBehalf
    Reserve storage reserve = reserves[assetId];
    UserConfig storage user = users[assetId][msg.sender];

    // asset can be withdrawn
    _validateWithdraw(reserve, amount);

    // update indexes and IRs
    _updateState(reserve);

    // invokes borrow modules in case accounting update is needed
    // (eg, update premium for users borrowing using the asset as collateral)
    // TODO

    // updates user accounting
    // user.onWithdraw( assetData, amount);
    reserve.virtualBalance -= amount;
    // TODO reserve.supplyIndex
    reserve.lastUpdateTimestamp = block.timestamp;
    user.principalBalance -= amount; // TODO clearer error msg
    // TODO user.lastUpdateIndex
    // TODO accumulate user.interestBalance into user.principalBalance
    user.lastUpdateTimestamp = block.timestamp;

    // transfer
    IERC20(reservesList[assetId]).safeTransfer(msg.sender, amount); // TODO: fee-on-transfer
  }

  function borrow(uint256 assetId, uint256 amount) external {
    // TODO: onBehalf
    Reserve storage reserve = reserves[assetId];
    UserConfig storage user = users[assetId][msg.sender];

    // asset can be borrowed
    // borrow cap not reached
    // msg.sender needs to be a valid module

    _validateBorrow();

    // update indexes and IRs
    _updateState(reserve);

    // invokes borrow modules in case accounting update is needed
    // (eg, update premium for users borrowing using the asset as collateral)
    // TODO

    // updates user accounting
    // user.onWithdraw( assetData, amount);

    // transfer
  }

  //
  // Internal
  //
  function _validateSupply(Reserve storage reserve, uint256 amount) internal view {
    // asset is listed
    require(reservesList[reserve.id] != address(0), 'ASSET_NOT_LISTED');
    // asset can be supplied
    require(reserve.config.active, 'NOT_ACTIVE');
    // supply cap not reached
    require(reserve.config.supplyCap > reserve.virtualBalance + amount, 'CAP_EXCEEDED');
  }

  function _validateWithdraw(Reserve storage reserve, uint256 amount) internal view {
    // asset can be withdrawn
    require(reserve.config.active, 'NOT_ACTIVE');
    // reserve with available liquidity
    require(reserve.virtualBalance >= amount, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateBorrow() internal {}

  function _updateState(Reserve storage reserve) internal {
    // Update indexes
    // Update interest rates
  }
}
