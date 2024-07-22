// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../dependencies/openzeppelin/IERC20.sol';
import {WadRayMath} from './WadRayMath.sol';
import {MathUtils} from './MathUtils.sol';
import {IBorrowModule} from './IBorrowModule.sol';

import 'forge-std/console2.sol';

contract LiquidityHub {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;

  event Supply(
    uint256 indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referralCode
  );
  event Withdraw(uint256 indexed reserve, address indexed user, address indexed to, uint256 amount);

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
  uint256 public reserveCount;

  // asset id => user address => user data
  mapping(uint256 => mapping(address => UserConfig)) public users;

  constructor() {}

  function getReserve(uint256 assetId) external view returns (Reserve memory) {
    return reserves[assetId];
  }

  function getUser(uint256 assetId, address user) external view returns (UserConfig memory) {
    UserConfig memory u = users[assetId][user];

    // Refresh user position
    uint256 userElapsed = block.timestamp - u.lastUpdateTimestamp;
    if (userElapsed > 0) {
      u.principalBalance += u.interestBalance;
      u.interestBalance = (reserves[assetId].supplyIndex - u.lastUpdateIndex).rayMul(
        u.principalBalance
      ); // rounding up?
    }

    return u;
  }

  // /////
  // Governance
  // /////

  function addReserve(ReserveConfig memory params, address asset) external {
    // TODO: AccessControl
    reservesList.push(asset);
    reserves[reserveCount] = Reserve({
      id: reserveCount,
      supplyIndex: WadRayMath.RAY,
      supplyRate: 0,
      borrowIndex: WadRayMath.RAY,
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

  function supply(
    uint256 assetId,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external {
    Reserve storage reserve = reserves[assetId];
    UserConfig storage user = users[assetId][onBehalfOf];

    _validateSupply(reserve, amount);

    // update indexes and IRs
    _updateState(reserve); // TODO
    // TODO: init user lastUpdateIndex
    // TODO Set as collateral if first supply?
    _accrueUserInterest(reserves[assetId], user);

    // invokes borrow modules in case accounting update is needed
    // (eg, update premium for users borrowing using the asset as collateral)
    // TODO

    // updates user accounting
    // user.onSupply( assetData, amount);
    // TODO Mitigate inflation attack (burn some amount if first supply)

    reserve.virtualBalance += amount;
    user.principalBalance += amount;

    // transferFrom
    IERC20(reservesList[assetId]).safeTransferFrom(msg.sender, address(this), amount); // TODO: fee-on-transfer

    emit Supply(assetId, msg.sender, onBehalfOf, amount, referralCode);
  }

  function withdraw(uint256 assetId, uint256 amount, address to) external {
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
    user.principalBalance -= amount; // TODO clearer error msg
    _accrueUserInterest(reserves[assetId], user);

    // transfer
    IERC20(reservesList[assetId]).safeTransfer(to, amount); // TODO: fee-on-transfer

    emit Withdraw(assetId, msg.sender, to, amount);
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
    require(reserve.config.active, 'RESERVE_NOT_ACTIVE');
    // supply cap not reached
    require(reserve.config.supplyCap > reserve.virtualBalance + amount, 'CAP_EXCEEDED');
  }

  function _validateWithdraw(Reserve storage reserve, uint256 amount) internal view {
    // asset can be withdrawn
    require(reserve.config.active, 'RESERVE_NOT_ACTIVE');
    // reserve with available liquidity
    require(reserve.virtualBalance >= amount, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateBorrow() internal {}

  function _updateState(Reserve storage reserve) internal {
    // Update interest rates
    (reserve.supplyRate, reserve.borrowRate) = IBorrowModule(reserve.config.borrowModule)
      .calculateInterestRates();
    // TODO: only borrowRate? supplyRate can be calculated using borrowRate and RF
    // borrow module and liquidity hub coupling

    // Update indexes
    _accrueReserveInterest(reserve);
    // TODO borrowIndex
    // _accrueReserveInterest(reserve.borrowIndex, reserve.borrowRate, elapsed);
    // Accrue RF?

    reserve.lastUpdateTimestamp = block.timestamp;
  }

  function _accrueReserveInterest(Reserve storage r) internal {
    uint256 elapsed = block.timestamp - r.lastUpdateTimestamp;
    if (elapsed > 0) {
      // linear interest
      uint256 cumulated = MathUtils.calculateLinearInterest(r.supplyRate, uint40(r.lastUpdateTimestamp));
      r.supplyIndex = r.supplyIndex.rayMul(cumulated);
      // TODO: update reserve.virtualBalance ?
      r.lastUpdateTimestamp = block.timestamp;
    }
  }

  function _accrueUserInterest(Reserve storage r, UserConfig storage u) internal {
    uint256 userElapsed = block.timestamp - u.lastUpdateTimestamp;
    if (userElapsed > 0) {
      u.principalBalance += u.interestBalance; // TODO: event?
      u.interestBalance = (r.supplyIndex - u.lastUpdateIndex).rayMul(u.principalBalance);

      u.lastUpdateIndex = r.supplyIndex;
      u.lastUpdateTimestamp = block.timestamp;
    }
  }
}
