// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';
import {MathUtils} from 'src/contracts/MathUtils.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {IReserveInterestRateStrategy} from 'src/interfaces/IReserveInterestRateStrategy.sol';
import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

contract Spoke is ISpoke {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeERC20 for IERC20;

  ILiquidityHub public liquidityHub;

  struct Reserve {
    uint256 id;
    address asset;
    uint256 baseDebt;
    uint256 outstandingPremium;
    uint256 suppliedShares;
    uint256 baseBorrowIndex;
    uint256 lastUpdateTimestamp;
    uint256 riskPremiumRad;
    ReserveConfig config;
  }

  struct ReserveConfig {
    uint256 lt; // 1e4 == 100%, BPS
    uint256 lb; // TODO: liquidationProtocolFee
    uint256 liquidityPremium; // BPS
    bool borrowable;
    bool collateral;
  }

  struct ReservePremium {
    uint256 reserveId;
    uint256 liquidityPremium;
  }

  struct UserConfig {
    bool usingAsCollateral;
    uint256 baseDebt;
    uint256 outstandingPremium;
    uint256 suppliedShares;
    uint256 baseBorrowIndex;
    uint256 riskPremium;
    uint256 lastUpdateTimestamp;
  }

  struct CalculateUserAccountDataVars {
    uint256 i;
    uint256 reserveId;
    uint256 reservePrice;
    uint256 liquidityPremium;
    uint256 userCollateralInBaseCurrency;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 avgLiquidationThreshold;
    uint256 userRiskPremium;
    uint256 healthFactor;
  }

  // reserve id => user address => user data
  mapping(uint256 => mapping(address => UserConfig)) internal _users;
  // reserve id => reserveData
  mapping(uint256 => Reserve) internal _reserves;
  uint256[] public reservesList; // reserveIds
  uint256 public reserveCount;
  address public oracle;

  constructor(address liquidityHubAddress, address oracleAddress) {
    liquidityHub = ILiquidityHub(liquidityHubAddress);
    oracle = oracleAddress;
  }

  function getUserDebt(uint256 reserveId, address user) external view returns (uint256) {
    UserConfig memory user = _users[reserveId][user];
    // TODO: Instead use a getter from liquidity hub to get up-to-date user debt (with accrued debt)
    return
      user.baseDebt.rayMul(
        MathUtils.calculateCompoundedInterest(
          getInterestRate(reserveId),
          uint40(0),
          block.timestamp
        )
      );
  }

  function getReserveDebt(uint256 reserveId) external view returns (uint256) {
    Reserve storage reserve = _reserves[reserveId];

    // TODO: Instead use a getter from liquidity hub to get up-to-date reserve debt (with accrued debt)
    // return
    //   r.totalDebt.rayMul(
    //     MathUtils.calculateCompoundedInterest(getInterestRate(reserveId), uint40(0), block.timestamp)
    //   );
    return 0;
  }

  /// governance
  function updateReserveConfig(uint256 reserveId, ReserveConfig calldata params) external {
    // TODO: AccessControl
    _reserves[reserveId].config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
      liquidityPremium: params.liquidityPremium,
      borrowable: params.borrowable,
      collateral: params.collateral
    });

    emit ReserveConfigUpdated(
      reserveId,
      params.lt,
      params.lb,
      params.liquidityPremium,
      params.borrowable,
      params.collateral
    );
  }

  // /////
  // Users
  // /////

  function supply(uint256 reserveId, uint256 amount) external {
    Reserve storage reserve = _reserves[reserveId];
    UserConfig storage user = _users[reserveId][msg.sender];

    _accrueAssetInterest(reserveId, liquidityHub.previewNextBorrowIndex(reserveId));
    _validateSupply(reserve, amount);

    // Update user's risk premium and wAvgRP across all users of spoke
    uint256 newAggregatedRiskPremium = _updateRiskPremium({
      reserve: reserve,
      user: user,
      baseDebtChange: 0
    });
    (, uint256 userShares) = liquidityHub.supply(
      reserveId,
      amount,
      newAggregatedRiskPremium,
      msg.sender // supplier
    );

    user.suppliedShares += userShares;
    reserve.suppliedShares += userShares;

    emit Supplied(reserveId, msg.sender, amount);
  }

  function withdraw(uint256 reserveId, address to, uint256 amount) external {
    Reserve storage reserve = _reserves[reserveId];
    UserConfig storage user = _users[reserveId][msg.sender];

    _validateWithdraw(reserveId, reserve, user, amount);

    uint256 newAggregatedRiskPremium = _updateRiskPremium({
      reserve: reserve,
      user: user,
      baseDebtChange: 0
    });
    uint256 userShares = liquidityHub.withdraw(reserveId, amount, newAggregatedRiskPremium, to);
    user.suppliedShares -= userShares;

    emit Withdrawn(reserveId, msg.sender, amount);
  }

  function borrow(uint256 reserveId, address to, uint256 amount) external {
    // TODO: referral code
    // TODO: onBehalfOf with credit delegation
    Reserve storage reserve = _reserves[reserveId];
    UserConfig storage user = _users[reserveId][msg.sender];

    _validateBorrow(reserve, amount);

    // TODO HF check
    uint256 newAggregatedRiskPremium = _updateRiskPremium({
      reserve: reserve,
      user: user,
      baseDebtChange: int256(amount)
    });
    uint256 userDebt = liquidityHub.draw(reserveId, amount, newAggregatedRiskPremium, to);
    // debt still goes to original msg.sender
    user.baseDebt += userDebt;

    emit Borrowed(reserveId, to, amount);
  }

  function repay(uint256 reserveId, uint256 amount) external {
    // TODO: Implement repay, calls liquidity hub restore method
    // TODO: onBehalfOf
    UserConfig storage user = _users[reserveId][msg.sender];
    Reserve storage reserve = _reserves[reserveId];

    _validateRepay(reserveId, user, amount);

    // TODO: Should only be the base debt restored instead of amount in following line
    uint256 newAggregatedRiskPremium = _updateRiskPremium({
      reserve: reserve,
      user: user,
      baseDebtChange: -int256(amount)
    });
    // TODO: Spoke should calculate the amountFromPremium and amountFromBase
    uint256 repaidDebt = liquidityHub.restore(
      reserveId,
      amount,
      newAggregatedRiskPremium,
      msg.sender // repayer
    );
    user.baseDebt -= repaidDebt;

    emit Repaid(reserveId, msg.sender, amount);
  }

  function getUserRiskPremium(address user) external view returns (uint256) {
    (, , , uint256 userRiskPremium, ) = _calculateUserAccountData(user);
    return userRiskPremium;
  }

  function getHealthFactor(address user) external view returns (uint256) {
    (, , , , uint256 healthFactor) = _calculateUserAccountData(user);
    return healthFactor;
  }

  function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) external {
    _validateSetUsingAsCollateral(reserveId, msg.sender);
    _users[reserveId][msg.sender].usingAsCollateral = usingAsCollateral;

    emit UsingAsCollateral(reserveId, msg.sender, usingAsCollateral);
  }

  // TODO: Needed?
  function getInterestRate(uint256 reserveId) public view returns (uint256) {
    // read from state, convert to ray
    // TODO: should be final IR rather than base?
    return ILiquidityHub(liquidityHub).getBaseInterestRate(reserveId);
  }

  // /////
  // Governance
  // /////

  function addReserve(uint256 reserveId, ReserveConfig memory params, address asset) external {
    Reserve storage reserve = _reserves[reserveId];
    // TODO: validate reserveId does not exist already, valid asset
    // require(asset != address(0), 'INVALID_ASSET');
    // require(_reserves[reserveId].asset == address(0), 'RESERVE_ID_ALREADY_EXISTS');

    // TODO: AccessControl
    // TODO: assigning reserveId as the latest reserveCount
    reservesList.push(reserveId);
    reserve.id = reserveId;
    reserve.asset = asset;
    reserve.config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
      liquidityPremium: params.liquidityPremium,
      borrowable: params.borrowable,
      collateral: params.collateral
    });
    reserveCount++;

    // emit event
  }

  function updateReserve(uint256 reserveId, ReserveConfig memory params) external {
    // TODO: More sophisticated
    require(_reserves[reserveId].id != 0, 'INVALID_RESERVE');
    // TODO: AccessControl
    _reserves[reserveId].config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
      liquidityPremium: params.liquidityPremium,
      borrowable: params.borrowable,
      collateral: params.collateral
    });
  }

  // public
  function getReserve(uint256 reserveId) public view returns (Reserve memory) {
    return _reserves[reserveId];
  }

  function getUser(uint256 reserveId, address user) public view returns (UserConfig memory) {
    UserConfig memory user = _users[reserveId][user];
    return user;
  }

  // internal
  function _validateSupply(Reserve storage reserve, uint256 amount) internal view {
    // TODO: Decide where supply cap is checked
    require(reserve.asset != address(0), 'RESERVE_NOT_LISTED');
  }

  function _validateWithdraw(
    uint256 reserveId,
    Reserve storage reserve,
    UserConfig storage user,
    uint256 amount
  ) internal view {
    require(
      liquidityHub.convertToAssetsDown(reserveId, user.suppliedShares) >= amount,
      'INSUFFICIENT_SUPPLY'
    );
  }

  function _validateBorrow(Reserve storage reserve, uint256 amount) internal view {
    require(reserve.config.borrowable, 'RESERVE_NOT_BORROWABLE');
    // TODO: validation on HF to allow borrowing amount
  }

  function _validateRepay(
    uint256 reserveId,
    UserConfig storage user,
    uint256 amount
  ) internal view {
    require(amount <= user.baseDebt, 'REPAY_EXCEEDS_DEBT');
  }

  /**
  @param baseDebtChange The change in base debt of the reserve
  @return uint256 new aggregated risk premium
  */
  function _updateRiskPremium(
    Reserve storage reserve,
    UserConfig storage user,
    int256 baseDebtChange
  ) internal returns (uint256) {
    // Refresh risk premium of user, specific assets user has supplied
    uint256 newUserRiskPremium = _updateUserRiskPremium(msg.sender);
    // Refresh weighted average risk premium across all users of spoke
    uint256 newAggregatedRiskPremium = _updateSpokeRiskPremium(
      reserve,
      user,
      newUserRiskPremium,
      baseDebtChange
    );
    return newAggregatedRiskPremium;
  }

  /// @dev It's assumed interest has been accrued before this function call
  function _updateUserRiskPremium(address user) internal returns (uint256) {
    uint256 reservesListLength = reservesList.length;
    ReservePremium[] memory reservePremium = new ReservePremium[](reservesListLength);

    // Variable to decrement as we count up user RP
    uint256 tempDebt = 0;
    uint256 newUserRiskPremium = 0;
    uint256 collateralValue = 0;
    uint256 reserveId;
    uint256 userSupply;

    // Get all reserve risk premiums
    for (uint256 i = 0; i < reservesListLength; i++) {
      reserveId = reservesList[i];
      reservePremium[i] = ReservePremium({
        reserveId: reserveId,
        liquidityPremium: _reserves[reserveId].config.liquidityPremium
      });
      // Add up user debt for each reserve, including price
      tempDebt += _users[reserveId][user].baseDebt * IPriceOracle(oracle).getAssetPrice(reserveId);
    }

    // If user has no debt, return 0 risk premium
    if (tempDebt == 0) return 0;

    // TODO: Reconsider this n^2 sort, potentially just keep sorted list of reserves (by LP)
    // Sort reserves by ascending order of liquidity premium using bubble sort for small arrays
    for (uint256 i = 0; i < reservesListLength - 1; i++) {
      for (uint256 j = 0; j < reservesListLength - i - 1; j++) {
        if (reservePremium[j].liquidityPremium > reservePremium[j + 1].liquidityPremium) {
          // Swap elements
          ReservePremium memory temp = reservePremium[j];
          reservePremium[j] = reservePremium[j + 1];
          reservePremium[j + 1] = temp;
        }
      }
    }

    // While the tempDebt variable is non-zero, loop over collateral reserves, adding up weighted risk premium, and subtract corresponding amt from tempDebt
    for (uint256 i = 0; i < reservesListLength; i++) {
      reserveId = reservePremium[i].reserveId;
      if (!_usingAsCollateral(reserveId, user)) continue;

      // Convert user's supply shares for this reserve to collateral value
      userSupply =
        liquidityHub.convertToAssetsDown(reserveId, _users[reserveId][user].suppliedShares) *
        IPriceOracle(oracle).getAssetPrice(reserveId);

      if (userSupply >= tempDebt) {
        // This reserve completes user debt, so add up weighted risk premium and break
        newUserRiskPremium += tempDebt * reservePremium[i].liquidityPremium;
        collateralValue += tempDebt;
        break;
      } else {
        // Add up weighted risk premium
        newUserRiskPremium += userSupply * reservePremium[i].liquidityPremium;
        collateralValue += userSupply;
        // Subtract user supply from tempDebt
        tempDebt -= userSupply;
      }
    }

    if (collateralValue == 0) return 0;
    return newUserRiskPremium.percentDiv(collateralValue);
  }

  /// @dev It's assumed interest has been accrued before this function call
  function _updateSpokeRiskPremium(
    Reserve storage reserve,
    UserConfig storage user,
    uint256 newUserRiskPremium,
    int256 baseDebtChange
  ) internal returns (uint256) {
    uint256 existingReserveDebt = reserve.baseDebt;
    uint256 existingUserDebt = user.baseDebt;

    // Weighted average risk premium of all users without current user
    (uint256 reserveRiskPremiumWithoutCurrent, uint256 reserveDebtWithoutCurrent) = MathUtils
      .subtractFromWeightedAverage(
        reserve.riskPremiumRad,
        existingReserveDebt,
        user.riskPremium,
        existingUserDebt
      );

    uint256 newUserDebt = baseDebtChange > 0
      ? existingUserDebt + uint256(baseDebtChange) // debt added
      : // force underflow: only possible when user takes repays amount more than net drawn
      existingUserDebt - uint256(-baseDebtChange); // debt restored

    (uint256 newReserveRiskPremium, uint256 newReserveDebt) = MathUtils.addToWeightedAverage(
      reserveRiskPremiumWithoutCurrent,
      reserveDebtWithoutCurrent,
      newUserRiskPremium,
      newUserDebt
    );

    reserve.baseDebt = newReserveDebt;
    user.baseDebt = newUserDebt;

    reserve.riskPremiumRad = newReserveRiskPremium;
    user.riskPremium = newUserRiskPremium;
  }

  function _validateSetUsingAsCollateral(uint256 reserveId, address user) internal view {
    require(_reserves[reserveId].config.collateral, 'RESERVE_NOT_COLLATERAL');
    require(_users[reserveId][user].suppliedShares > 0, 'NO_SUPPLY');
  }

  function _usingAsCollateralOrBorrowing(
    uint256 reserveId,
    address user
  ) internal view returns (bool) {
    return _usingAsCollateral(reserveId, user) || _borrowing(reserveId, user);
  }

  function _usingAsCollateral(uint256 reserveId, address user) internal view returns (bool) {
    return _users[reserveId][user].usingAsCollateral;
  }

  function _borrowing(uint256 reserveId, address user) internal view returns (bool) {
    return _users[reserveId][user].baseDebt > 0;
  }

  function _calculateUserAccountData(
    address userAddress
  ) internal view returns (uint256, uint256, uint256, uint256, uint256) {
    CalculateUserAccountDataVars memory vars;
    uint256 reservesListLength = reservesList.length;
    while (vars.i < reservesListLength) {
      vars.reserveId = reservesList[vars.i];
      if (!_usingAsCollateralOrBorrowing(vars.reserveId, userAddress)) {
        vars.i++;
        continue;
      }

      UserConfig memory user = getUser(vars.reserveId, userAddress);
      Reserve memory reserve = getReserve(vars.reserveId);

      vars.reservePrice = IPriceOracle(oracle).getAssetPrice(vars.reserveId);

      if (_usingAsCollateral(vars.reserveId, userAddress)) {
        vars.userCollateralInBaseCurrency =
          vars.reservePrice *
          liquidityHub.convertToAssetsDown(
            vars.reserveId,
            _calculateAccruedInterest(vars.reserveId, user.suppliedShares)
          );
        vars.liquidityPremium = 1; // TODO: get LP from LH
        vars.totalCollateralInBaseCurrency += vars.userCollateralInBaseCurrency;
        vars.avgLiquidationThreshold += vars.userCollateralInBaseCurrency * reserve.config.lt;
        vars.userRiskPremium += vars.userCollateralInBaseCurrency * vars.liquidityPremium;
      }

      vars.totalDebtInBaseCurrency += user.baseDebt > 0
        ? vars.reservePrice * _calculateAccruedInterest(vars.reserveId, user.baseDebt)
        : 0;

      vars.i++;
    }

    vars.avgLiquidationThreshold = vars.totalCollateralInBaseCurrency == 0
      ? 0
      : vars.avgLiquidationThreshold / vars.totalCollateralInBaseCurrency;

    vars.userRiskPremium = vars.totalCollateralInBaseCurrency == 0
      ? 0
      : vars.userRiskPremium.wadDiv(vars.totalCollateralInBaseCurrency);

    vars.healthFactor = vars.totalDebtInBaseCurrency == 0
      ? type(uint256).max
      : (vars.totalCollateralInBaseCurrency.percentMul(vars.avgLiquidationThreshold)).wadDiv(
        vars.totalDebtInBaseCurrency
      ); // HF of 1 -> 1e18

    return (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      vars.userRiskPremium,
      vars.healthFactor
    );
  }

  function _calculateAccruedInterest(
    uint256 reserveId,
    uint256 debt
  ) internal view returns (uint256) {
    // TODO: use lastUpdatedTimestamp in interest math, make sure total debt includes accrued interest
    return
      debt.rayMul(
        MathUtils.calculateCompoundedInterest(
          getInterestRate(reserveId),
          uint40(0),
          block.timestamp
        )
      );
  }

  function _accrueAssetInterest(uint256 reserveId, uint256 newBaseBorrowIndex) internal {
    Reserve storage reserve = _reserves[reserveId];
    UserConfig storage user = _users[reserveId][msg.sender];

    // no interest to accrue if no time passed
    if (reserve.lastUpdateTimestamp == block.timestamp) return;

    uint256 existingBaseDebt = reserve.baseDebt;
    // no interest to accrue since no liquidity has been drawn
    if (existingBaseDebt == 0) return;

    uint256 cumulatedBaseDebt = existingBaseDebt.rayMul(
      newBaseBorrowIndex.rayDiv(reserve.baseBorrowIndex)
    );

    // accrue premium interest on the accrued base interest
    reserve.baseDebt = cumulatedBaseDebt;
    reserve.outstandingPremium += (cumulatedBaseDebt - existingBaseDebt).radMul(
      reserve.riskPremiumRad
    );
    reserve.baseBorrowIndex = newBaseBorrowIndex;
    reserve.lastUpdateTimestamp = block.timestamp;

    // User specific updates
    existingBaseDebt = user.baseDebt;
    // no interest to accrue since no liquidity has been drawn
    if (existingBaseDebt == 0) return;

    cumulatedBaseDebt = existingBaseDebt.rayMul(newBaseBorrowIndex.rayDiv(user.baseBorrowIndex));

    user.baseDebt = cumulatedBaseDebt;
    user.outstandingPremium += (cumulatedBaseDebt - existingBaseDebt).radMul(user.riskPremium);
    user.baseBorrowIndex = newBaseBorrowIndex;
    user.lastUpdateTimestamp = block.timestamp;
  }
}
