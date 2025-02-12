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
    uint256 assetId;
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

  // user address => reserve id => user data
  mapping(address => mapping(uint256 => UserConfig)) internal _users;
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
    UserConfig memory user = _users[user][reserveId];
    // TODO: Instead use a getter from liquidity hub to get up-to-date user debt (with accrued debt)
    return
      user.baseDebt.rayMul(
        MathUtils.calculateCompoundedInterest(
          getInterestRate(_reserves[reserveId].assetId),
          uint40(user.lastUpdateTimestamp),
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
    UserConfig storage user = _users[msg.sender][reserveId];

    _accrueAssetInterest(reserveId, liquidityHub.previewNextBorrowIndex(reserve.assetId));
    _validateSupply(reserve, amount);

    // Update user's risk premium and wAvgRP across all users of spoke
    uint256 newAggregatedRiskPremium = _updateRiskPremiumAndBaseDebt({
      reserve: reserve,
      user: user,
      userAddress: msg.sender,
      baseDebtChange: 0
    });
    uint256 suppliedShares = liquidityHub.supply(
      reserve.assetId,
      amount,
      newAggregatedRiskPremium,
      msg.sender // supplier
    );

    user.suppliedShares += suppliedShares;
    reserve.suppliedShares += suppliedShares;

    emit Supplied(reserveId, amount, msg.sender);
  }

  function withdraw(uint256 reserveId, uint256 amount, address to) external {
    // TODO: Be able to pass max(uint) as amount to withdraw all supplied shares
    Reserve storage reserve = _reserves[reserveId];
    UserConfig storage user = _users[msg.sender][reserveId];

    _accrueAssetInterest(reserveId, liquidityHub.previewNextBorrowIndex(reserve.assetId));
    _validateWithdraw(reserveId, reserve, user, amount);

    // Update user's risk premium and wAvgRP across all users of spoke
    uint256 newAggregatedRiskPremium = _updateRiskPremiumAndBaseDebt({
      reserve: reserve,
      user: user,
      userAddress: msg.sender,
      baseDebtChange: 0
    });
    uint256 withdrawnShares = liquidityHub.withdraw(
      reserve.assetId,
      amount,
      newAggregatedRiskPremium,
      to
    );

    user.suppliedShares -= withdrawnShares;
    reserve.suppliedShares -= withdrawnShares;

    emit Withdrawn(reserveId, amount, msg.sender);
  }

  function borrow(uint256 reserveId, uint256 amount, address to) external {
    // TODO: referral code
    // TODO: onBehalfOf with credit delegation
    Reserve storage reserve = _reserves[reserveId];
    UserConfig storage user = _users[msg.sender][reserveId];

    _accrueAssetInterest(reserveId, liquidityHub.previewNextBorrowIndex(reserve.assetId));
    _validateBorrow(reserve, amount);

    // TODO HF check
    uint256 newAggregatedRiskPremium = _updateRiskPremiumAndBaseDebt({
      reserve: reserve,
      user: user,
      userAddress: msg.sender,
      baseDebtChange: int256(amount)
    });
    liquidityHub.draw(reserve.assetId, amount, newAggregatedRiskPremium, to);

    emit Borrowed(reserveId, amount, to);
  }

  function repay(uint256 reserveId, uint256 amount) external {
    // TODO: Be able to pass max(uint) as amount to restore all debt
    // TODO: onBehalfOf
    UserConfig storage user = _users[msg.sender][reserveId];
    Reserve storage reserve = _reserves[reserveId];

    _accrueAssetInterest(reserveId, liquidityHub.previewNextBorrowIndex(reserve.assetId));
    _validateRepay(reserveId, user, amount);

    // Repaid debt happens first from premium, then base
    uint256 baseDebtRestored = _deductFromOutstandingPremium(reserve, user, amount);

    uint256 newAggregatedRiskPremium = _updateRiskPremiumAndBaseDebt({
      reserve: reserve,
      user: user,
      userAddress: msg.sender,
      baseDebtChange: -int256(baseDebtRestored)
    });

    liquidityHub.restore(
      reserve.assetId,
      amount,
      newAggregatedRiskPremium,
      msg.sender // repayer
    );

    emit Repaid(reserveId, amount, msg.sender);
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
    Reserve storage reserve = _reserves[reserveId];
    UserConfig storage user = _users[msg.sender][reserveId];

    _validateSetUsingAsCollateral(reserve, user);
    user.usingAsCollateral = usingAsCollateral;

    emit UsingAsCollateral(reserveId, usingAsCollateral, msg.sender);
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

  function addReserve(
    uint256 assetId,
    ReserveConfig memory params,
    address asset
  ) external returns (uint256) {
    Reserve storage reserve = _reserves[reserveCount];
    // TODO: validate reserveId does not exist already, valid asset
    // require(asset != address(0), 'INVALID_ASSET');
    // require(_reserves[reserveId].asset == address(0), 'RESERVE_ID_ALREADY_EXISTS');

    // TODO: AccessControl
    reservesList.push(reserveCount);
    reserve.assetId = assetId;
    reserve.asset = asset;
    reserve.config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
      liquidityPremium: params.liquidityPremium,
      borrowable: params.borrowable,
      collateral: params.collateral
    });

    return reserveCount++;

    // emit event
  }

  function updateReserve(uint256 reserveId, ReserveConfig memory params) external {
    // TODO: More sophisticated
    require(_reserves[reserveId].asset != address(0), 'INVALID_RESERVE');
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
    UserConfig memory user = _users[user][reserveId];
    return user;
  }

  // internal
  function _validateSupply(Reserve storage reserve, uint256 amount) internal view {
    require(reserve.asset != address(0), 'RESERVE_NOT_LISTED');
  }

  function _validateWithdraw(
    uint256 reserveId,
    Reserve storage reserve,
    UserConfig storage user,
    uint256 amount
  ) internal view {
    require(
      liquidityHub.convertToAssetsDown(_reserves[reserveId].assetId, user.suppliedShares) >= amount,
      'INSUFFICIENT_SUPPLY'
    );
  }

  function _validateBorrow(Reserve storage reserve, uint256 amount) internal view {
    require(reserve.config.borrowable, 'RESERVE_NOT_BORROWABLE');
    // TODO: validation on HF to allow borrowing amount
  }

  // TODO: Place this and LH equivalent in a generic logic library
  function _validateRepay(
    uint256 reserveId,
    UserConfig storage user,
    uint256 amount
  ) internal view {
    require(amount <= user.baseDebt + user.outstandingPremium, 'REPAY_EXCEEDS_DEBT');
  }

  function _deductFromOutstandingPremium(
    Reserve storage reserve,
    UserConfig storage user,
    uint256 amount
  ) internal returns (uint256) {
    uint256 userOutstandingPremium = user.outstandingPremium;

    uint256 baseDebtRestored;

    if (amount > userOutstandingPremium) {
      baseDebtRestored = amount - userOutstandingPremium;
      user.outstandingPremium = 0;
      // underflow not possible bc of invariant: reserve.outstandingPremium >= user.outstandingPremium
      reserve.outstandingPremium -= userOutstandingPremium;
    } else {
      // no base debt is restored, only outstanding premium
      user.outstandingPremium -= amount;
      reserve.outstandingPremium -= amount;
    }

    return baseDebtRestored;
  }

  /**
  @param baseDebtChange The change in base debt of the reserve.
  @return The new aggregated risk premium.
  */
  function _updateRiskPremiumAndBaseDebt(
    Reserve storage reserve,
    UserConfig storage user,
    address userAddress,
    int256 baseDebtChange
  ) internal returns (uint256) {
    // Calculate risk premium of user
    uint256 newUserRiskPremium = _calcUserRiskPremium(_users[userAddress]);
    // Refresh weighted average risk premium across all users of spoke
    uint256 newAggregatedRiskPremium = _updateSpokeRiskPremiumAndBaseDebt(
      reserve,
      user,
      newUserRiskPremium,
      baseDebtChange
    );
    return newAggregatedRiskPremium;
  }

  /// @dev TODO: It's assumed reservesList (or similar) is sorted by liquidity premium
  /// @dev It's assumed interest has been accrued before this function call.
  function _calcUserRiskPremium(
    mapping(uint256 => UserConfig) storage userData
  ) internal returns (uint256) {
    uint256 reservesListLength = reservesList.length;

    // Variable to decrement as we count up user RP
    uint256 tempDebt = 0;
    uint256 newUserRiskPremium = 0;
    uint256 collateralValue = 0;
    uint256 reserveId;
    uint256 userSupply;

    // Add up user debt for each reserve, including price
    for (uint256 i; i < reservesListLength; ++i) {
      reserveId = reservesList[i];
      tempDebt += userData[reserveId].baseDebt * IPriceOracle(oracle).getAssetPrice(reserveId);
    }

    // If user has no debt, return 0 risk premium
    if (tempDebt == 0) return 0;

    // While the tempDebt variable is non-zero, loop over collateral reserves, adding up weighted risk premium, and subtract corresponding amt from tempDebt
    for (uint256 i; i < reservesListLength; ++i) {
      reserveId = reservesList[i];
      if (!_usingAsCollateral(userData[reserveId])) continue;

      // Convert user's supply shares for this reserve to collateral value
      userSupply =
        liquidityHub.convertToAssetsDown(
          _reserves[reserveId].assetId,
          userData[reserveId].suppliedShares
        ) *
        IPriceOracle(oracle).getAssetPrice(reserveId);

      if (userSupply >= tempDebt) {
        // This reserve completes user debt, so add up weighted risk premium and break
        newUserRiskPremium += tempDebt * _reserves[reserveId].config.liquidityPremium;
        collateralValue += tempDebt;
        break;
      } else {
        // Add up weighted risk premium
        newUserRiskPremium += userSupply * _reserves[reserveId].config.liquidityPremium;
        collateralValue += userSupply;
        // Subtract user supply from tempDebt
        tempDebt -= userSupply;
      }
    }

    if (collateralValue == 0) return 0;
    return newUserRiskPremium / collateralValue;
  }

  /// @dev It's assumed interest has been accrued before this function call.
  function _updateSpokeRiskPremiumAndBaseDebt(
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

  function _validateSetUsingAsCollateral(
    Reserve storage reserve,
    UserConfig storage user
  ) internal view {
    require(reserve.config.collateral, 'RESERVE_NOT_COLLATERAL');
  }

  function _usingAsCollateral(UserConfig storage user) internal view returns (bool) {
    return user.usingAsCollateral;
  }

  function _borrowing(UserConfig storage user) internal view returns (bool) {
    return user.baseDebt + user.outstandingPremium > 0;
  }

  function _usingAsCollateralOrBorrowing(UserConfig storage user) internal view returns (bool) {
    return _usingAsCollateral(user) || _borrowing(user);
  }

  function _calculateUserAccountData(
    address userAddress
  ) internal view returns (uint256, uint256, uint256, uint256, uint256) {
    CalculateUserAccountDataVars memory vars;
    uint256 reservesListLength = reservesList.length;
    while (vars.i < reservesListLength) {
      vars.reserveId = reservesList[vars.i];
      if (!_usingAsCollateralOrBorrowing(_users[userAddress][vars.reserveId])) {
        vars.i++;
        continue;
      }

      UserConfig memory user = getUser(vars.reserveId, userAddress);
      Reserve memory reserve = getReserve(vars.reserveId);

      vars.reservePrice = IPriceOracle(oracle).getAssetPrice(vars.reserveId);

      if (_usingAsCollateral(_users[userAddress][vars.reserveId])) {
        vars.userCollateralInBaseCurrency =
          vars.reservePrice *
          liquidityHub.convertToAssetsDown(
            _reserves[vars.reserveId].assetId,
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
          getInterestRate(_reserves[reserveId].assetId),
          uint40(0),
          block.timestamp
        )
      );
  }

  function _accrueAssetInterest(uint256 reserveId, uint256 newBaseBorrowIndex) internal {
    Reserve storage reserve = _reserves[reserveId];
    UserConfig storage user = _users[msg.sender][reserveId];

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
