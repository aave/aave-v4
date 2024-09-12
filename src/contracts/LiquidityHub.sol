// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../dependencies/openzeppelin/IERC20.sol';
import {WadRayMath} from './WadRayMath.sol';
import {SharesMath} from './SharesMath.sol';
import {MathUtils} from './MathUtils.sol';
import {IBorrowModule} from './IBorrowModule.sol';
import {DataTypes} from './types/DataTypes.sol';
import {ReserveConfiguration} from './ReserveConfiguration.sol';

import 'forge-std/console2.sol';

contract LiquidityHub {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using ReserveConfiguration for DataTypes.ReserveConfig;

  event Supply(
    uint256 indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referralCode
  );
  event Withdraw(uint256 indexed reserve, address indexed user, address indexed to, uint256 amount);

  event Borrow(uint256 indexed reserve, address indexed user, uint256 amount);

  struct Reserve {
    uint256 id;
    uint256 totalShares;
    uint256 totalAssets;
    uint256 lastUpdateTimestamp;
    address borrowModule;
    address supplyModule;
    DataTypes.ReserveConfig config;
  }

  struct UserConfig {
    uint256 shares;
  }

  // asset id => reserve data
  mapping(uint256 => Reserve) public reserves;
  address[] public reservesList; // TODO: Check if Enumerable or Set makes more sense
  uint256 public reserveCount;

  // asset id => user address => user data
  mapping(uint256 => mapping(address => UserConfig)) public users;

  // asset id => user address => user's reserve config
  mapping(uint256 => mapping(address => DataTypes.ReserveConfig)) public userReserveConfigs;

  function getReserve(uint256 assetId) external view returns (Reserve memory) {
    return reserves[assetId];
  }

  function getUser(uint256 assetId, address user) external view returns (UserConfig memory) {
    UserConfig memory u = users[assetId][user];

    return u;
  }

  function getUserReserveConfig(
    uint256 assetId,
    address user
  ) external view returns (DataTypes.ReserveConfig memory) {
    DataTypes.ReserveConfig memory c = userReserveConfigs[assetId][user];

    return c;
  }

  function getUserBalance(uint256 assetId, address user) external view returns (uint256) {
    UserConfig memory u = users[assetId][user];

    return u.shares.toAssetsDown(reserves[assetId].totalAssets, reserves[assetId].totalShares);
  }

  // /////
  // Governance
  // /////

  function addReserve(DataTypes.ReserveConfigurationParams memory params, address asset) external {
    // TODO: AccessControl
    DataTypes.ReserveConfig memory config = DataTypes.ReserveConfig({data: 0});
    config.setConfigFromParams(params);

    reservesList.push(asset);
    reserves[reserveCount] = Reserve({
      id: reserveCount,
      totalShares: 0,
      totalAssets: 0,
      lastUpdateTimestamp: block.timestamp,
      borrowModule: params.borrowModule,
      supplyModule: params.supplyModule,
      config: config
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
    console2.log('- supply', msg.sender);
    console2.log('  params:', assetId, amount, onBehalfOf);
    Reserve storage reserve = reserves[assetId];
    UserConfig storage user = users[assetId][onBehalfOf];

    _validateSupply(reserve, amount);

    // update indexes and IRs
    _updateState(reserve); // TODO

    // Update user reserve config
    _updateUserReserveConfig(onBehalfOf, assetId);

    // TODO: init user lastUpdateIndex
    // TODO Set as collateral if first supply?

    // invokes borrow modules in case accounting update is needed
    // (eg, update premium for users borrowing using the asset as collateral)
    // TODO

    // updates user accounting
    // user.onSupply( assetData, amount);
    // TODO Mitigate inflation attack (burn some amount if first supply)

    uint256 sharesAmount = amount.toSharesDown(reserve.totalAssets, reserve.totalShares);
    require(sharesAmount > 0, 'INVALID_AMOUNT');
    user.shares += sharesAmount;
    reserve.totalShares += sharesAmount;
    reserve.totalAssets += amount;

    // transferFrom
    IERC20(reservesList[assetId]).safeTransferFrom(msg.sender, address(this), amount); // TODO: fee-on-transfer

    emit Supply(assetId, msg.sender, onBehalfOf, amount, referralCode);
  }

  function withdraw(uint256 assetId, uint256 amount, address to) external {
    // TODO: onBehalf
    // TODO: onBehalf
    Reserve storage reserve = reserves[assetId];
    UserConfig storage user = users[assetId][msg.sender];

    // asset can be withdrawn
    _validateWithdraw(reserve, amount);

    // TODO HF check

    // update indexes and IRs
    _updateState(reserve);

    // Update user reserve config
    _updateUserReserveConfig(msg.sender, assetId);

    // invokes borrow modules in case accounting update is needed
    // (eg, update premium for users borrowing using the asset as collateral)
    // TODO

    // updates user accounting
    // user.onWithdraw( assetData, amount);

    uint256 sharesAmount = amount.toSharesUp(reserve.totalAssets, reserve.totalShares);
    user.shares -= sharesAmount;
    reserve.totalShares -= sharesAmount;
    reserve.totalAssets -= amount;

    // transfer
    IERC20(reservesList[assetId]).safeTransfer(to, amount);

    emit Withdraw(assetId, msg.sender, to, amount);
  }

  function borrow(uint256 assetId, uint256 amount) external {
    // TODO: onBehalf
    // TODO: onBehalf
    Reserve storage reserve = reserves[assetId];
    UserConfig storage user = users[assetId][msg.sender];

    uint256 totalBorrows; // TODO
    _validateBorrow(reserve, totalBorrows, amount);

    // TODO HF check

    // update indexes and IRs
    _updateState(reserve);

    // Update user reserve config
    _updateUserReserveConfig(msg.sender, assetId);

    // invokes borrow modules in case accounting update is needed
    // (eg, update premium for users borrowing using the asset as collateral)
    // TODO
    //IBorrowModule(reserve.config.borrowModule).onBorrow(assetId, msg.sender, amount);

    // updates user accounting
    // TODO: increase totalBorrows

    // transfer
    IERC20(reservesList[assetId]).safeTransfer(msg.sender, amount);

    emit Borrow(assetId, msg.sender, amount);
  }

  function repay(uint256 assetId, uint256 amount, address onBehalfOf) external {
    _updateUserReserveConfig(onBehalfOf, assetId);
  }

  //
  // Internal
  //
  function _validateSupply(Reserve storage reserve, uint256 amount) internal view {
    // asset is listed
    require(reservesList[reserve.id] != address(0), 'ASSET_NOT_LISTED');
    // asset can be supplied
    require(reserve.config.getActive(), 'RESERVE_NOT_ACTIVE');
    // supply cap not reached
    require(
      reserve.config.getSupplyCap() == 0 ||
        reserve.config.getSupplyCap() > reserve.totalAssets + amount,
      'CAP_EXCEEDED'
    );
  }

  function _validateWithdraw(Reserve storage reserve, uint256 amount) internal view {
    // asset can be withdrawn
    require(reserve.config.getActive(), 'RESERVE_NOT_ACTIVE');
    // reserve with available liquidity
    require(reserve.totalAssets >= amount, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateBorrow(Reserve storage reserve, uint256 totalBorrows, uint256 amount) internal {
    // asset can be borrowed
    require(reserve.config.getActive(), 'RESERVE_NOT_ACTIVE');
    require(reserve.config.getBorrowingEnabled(), 'RESERVE_NOT_BORROWABLE');
    // borrow cap not reached
    require(
      reserve.config.getBorrowCap() == 0 || reserve.config.getBorrowCap() > totalBorrows + amount,
      'CAP_EXCEEDED'
    ); // TODO probably better in borrow module
    // msg.sender needs to be a valid module
    // TODO
  }

  function _updateState(Reserve storage reserve) internal {
    // Update interest rates
    uint256 borrowRate = IBorrowModule(reserve.borrowModule).calculateInterestRates(); // TODO: coupling here, must be more abstract?
    // TODO: only borrowRate? supplyRate can be calculated using borrowRate and RF
    // borrow module and liquidity hub coupling

    // Update indexes
    _accrueReserveInterest(reserve, borrowRate);
    // TODO borrowIndex
    // _accrueReserveInterest(reserve.borrowIndex, reserve.borrowRate, elapsed);
    // Accrue RF?
  }

  function _accrueReserveInterest(Reserve storage r, uint256 borrowRate) internal {
    uint256 elapsed = block.timestamp - r.lastUpdateTimestamp;
    if (elapsed > 0) {
      console2.log('_accrueReserveInterest');
      // linear interest
      uint256 cumulated = MathUtils
        .calculateLinearInterest(borrowRate, uint40(r.lastUpdateTimestamp))
        .rayMul(r.totalAssets); // TODO rounding
      console2.log('cumulated %e', cumulated);
      r.totalAssets += cumulated;

      // TODO: fee shares

      r.lastUpdateTimestamp = block.timestamp;
    }
  }

  function _updateUserReserveConfig(address user, uint256 reserve) internal {
    userReserveConfigs[reserve][user] = reserves[reserve].config;
  }
}
