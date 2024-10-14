// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../dependencies/openzeppelin/IERC20.sol';
import {WadRayMath} from './WadRayMath.sol';
import {IBorrowModule} from './IBorrowModule.sol';
import {MathUtils} from './MathUtils.sol';

contract BorrowModule is IBorrowModule {
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;

  // debt balances, fetches indexes from liquidity layer

  // keep collateral configuration
  // By using BorrowModule, LPs can choose which collaterals are used to borrow their assets

  // keep hooks to be executed by LiquidityHub when there is supply/withdraw actions

  // fetch liquidity from liquidityHub

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
  // assetId => reserveData
  mapping(uint256 => Reserve) public reserves;

  address public liquidityHub;

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

  // TODO: Implement drawLiquidity, calls liquidity hub draw method
  function drawLiquidity(uint256 assetId, uint256 amount) external {
    // // TODO: onBehalf
    // Reserve storage reserve = reserves[assetId];
    // UserConfig storage user = users[assetId][msg.sender];
    // _validateBorrow(reserve, amount);
    // // update indexes and IRs
    // _updateState(reserve);
    // // TODO: update avgRiskPremium if collateral
    // // if collateral
    // _updateRiskPremium(msg.sender);
    // // updates accounting
    // reserve.totalDrawn += amount;
    // // invokes borrow modules in case accounting update is needed
    // // (eg, update premium for users borrowing using the asset as collateral)
    // // TODO
    // // Allow transfer of funds for borrow module
    // IERC20(reservesList[assetId]).forceApprove(reserve.config.borrowModule, amount);
    // // TODO: transfer instead? the module can take less than approved
    // IBorrowModule(reserve.config.borrowModule).onBorrow(
    //   assetId,
    //   msg.sender,
    //   userRiskPremium[msg.sender],
    //   amount
    // );
    // // reset allowance
    // IERC20(reservesList[assetId]).forceApprove(reserve.config.borrowModule, 0);
    // emit Draw(assetId, reserve.config.borrowModule, amount);
  }

  // TODO: Implement restoreLiquidity, calls liquidity hub restore method
  function restoreLiquidity() external {}

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

  function calculateInterestRates() public pure returns (uint256) {
    // borrowRate
    return 0;
  }

  function onBorrow(
    uint256 assetId,
    address user,
    uint256 userRiskPremium,
    uint256 amount
  ) external {
    Reserve storage r = reserves[assetId];
    _validateBorrow(r, amount);

    // accrue
    _updateState(r);

    // TODO HF check

    // update user debt balance
    UserConfig storage u = users[assetId][user];
    // accrue interest
    // TODO: Risk premium for user and reserve
    u.principalBalance +=
      u.principalBalance.rayMul(
        MathUtils.calculateCompoundedInterest(
          u.lastUpdateIndex,
          uint40(u.lastUpdateTimestamp),
          block.timestamp
        )
      ) +
      amount;
    u.lastUpdateTimestamp = block.timestamp;

    // update reserve debt balance
    r.totalDebt +=
      r.totalDebt.rayMul(
        MathUtils.calculateCompoundedInterest(
          r.lastUpdateIndex,
          uint40(r.lastUpdateTimestamp),
          block.timestamp
        )
      ) +
      amount;

    // compatible collaterals assets?

    // TODO reference of liqHub instead of msg.sender
    IERC20(reserves[assetId].asset).safeTransferFrom(msg.sender, user, amount);
  }

  function _validateBorrow(Reserve storage reserve, uint256 amount) internal view {
    require(reserve.config.borrowable, 'RESERVE_NOT_BORROWABLE');
  }

  function _updateState(Reserve storage reserve) internal {
    // TODO: Move this call to IR
    uint256 borrowRate = calculateInterestRates(); // TODO: coupling here, must be more abstract?
    uint256 cumulatedInterest = MathUtils.calculateCompoundedInterest(
      borrowRate,
      uint40(reserve.lastUpdateTimestamp),
      block.timestamp
    );

    reserve.lastUpdateIndex = reserve.totalDebt.rayMul(cumulatedInterest);
    reserve.lastUpdateTimestamp = block.timestamp;
  }
}
