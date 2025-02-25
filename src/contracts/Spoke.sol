// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WadRayMath} from 'src/contracts/WadRayMath.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {MathUtils} from 'src/contracts/MathUtils.sol';
import {KeyValueListInMemory} from 'src/contracts/KeyValueListInMemory.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';

contract Spoke is ISpoke {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeERC20 for IERC20;
  using KeyValueListInMemory for KeyValueListInMemory.List;

  uint256 public constant DEFAULT_SPOKE_INDEX = 0;
  // todo capitalize, oracle should be mutable?
  ILiquidityHub public immutable liquidityHub;
  IPriceOracle public immutable oracle;

  struct Reserve {
    uint256 assetId;
    address asset;
    uint256 baseDebt;
    uint256 outstandingPremium;
    uint256 suppliedShares;
    uint256 baseBorrowIndex;
    uint256 lastUpdateTimestamp;
    uint256 riskPremium; // rayified bps: weighted average risk premium of all users with ray precision
    ReserveConfig config;
  }

  struct ReserveConfig {
    uint256 lt; // 1e4 == 100%, BPS
    uint256 lb; // TODO: liquidationProtocolFee
    uint256 liquidityPremium; // BPS
    bool borrowable;
    bool collateral;
  }

  // todo rename to UserPosition
  struct UserConfig {
    bool usingAsCollateral;
    uint256 baseDebt;
    uint256 outstandingPremium;
    uint256 suppliedShares;
    uint256 baseBorrowIndex;
    uint256 lastUpdateTimestamp;
  }

  struct UserData {
    /**
     * ray-extended risk premium bps of user
     * for example, if risk premium bps is 15_50 (15.5%),
     * then this value is 1550_000000000000000000000000000 (1550 * 1e27),
     * stored with high precision to be equivalent with other RPs (Asset, Spoke/Reserve)
     * since they have to maintain a running weighted average
     * todo optimize: user RP doesn't need to be stored in full precision as described above
     */
    uint256 riskPremium;
    // todo supplied/borrowed (2d) bitmap
  }

  struct CalculateUserAccountDataVars {
    uint256 i;
    uint256 reserveId;
    uint256 assetId;
    uint256 assetPrice;
    uint256 assetUnit;
    uint256 userCollateralInBaseCurrency;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 avgLiquidationThreshold;
    uint256 userRiskPremium;
    uint256 liquidityPremium;
    uint256 healthFactor;
    // number of assets used as collateral for the risk premium calculation
    uint256 collateralReserveCount;
  }

  // todo rename UserConfig => UserPosition
  mapping(address user => mapping(uint256 reserveId => UserConfig position)) internal _users;
  mapping(address user => UserData data) internal _userData;
  mapping(uint256 reserveId => Reserve reserveData) internal _reserves;

  uint256[] public reservesList; // todo: rm, not needed
  uint256 public reserveCount;

  constructor(address liquidityHubAddress, address oracleAddress) {
    liquidityHub = ILiquidityHub(liquidityHubAddress);
    oracle = IPriceOracle(oracleAddress);
  }

  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256) {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = _previewUserInterest(
      _users[user][reserveId],
      _userData[user],
      liquidityHub.previewNextBorrowIndex(_reserves[reserveId].assetId)
    );
    return (cumulatedBaseDebt, cumulatedOutstandingPremium);
  }

  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256) {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = _previewSpokeInterest(
      _reserves[reserveId],
      liquidityHub.previewNextBorrowIndex(_reserves[reserveId].assetId)
    );
    return (cumulatedBaseDebt, cumulatedOutstandingPremium);
  }

  function getUserCumulativeDebt(uint256 reserveId, address user) external view returns (uint256) {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = _previewUserInterest(
      _users[user][reserveId],
      _userData[user],
      liquidityHub.previewNextBorrowIndex(_reserves[reserveId].assetId)
    );
    return cumulatedBaseDebt + cumulatedOutstandingPremium;
  }

  function getReserveCumulativeDebt(uint256 reserveId) external view returns (uint256) {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = _previewSpokeInterest(
      _reserves[reserveId],
      liquidityHub.previewNextBorrowIndex(_reserves[reserveId].assetId)
    );
    return cumulatedBaseDebt + cumulatedOutstandingPremium;
  }

  function getSuppliedAmount(uint256 reserveId, address user) external view returns (uint256) {
    return
      liquidityHub.convertToAssets(
        _reserves[reserveId].assetId,
        _users[user][reserveId].suppliedShares
      );
  }

  function getSuppliedShares(uint256 reserveId, address user) external view returns (uint256) {
    return _users[user][reserveId].suppliedShares;
  }

  function getReserveRiskPremium(uint256 reserveId) external view returns (uint256) {
    return _reserves[reserveId].riskPremium.derayify();
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
    UserData storage userData = _userData[msg.sender];

    _accrueInterest(reserve, user, userData);
    _validateSupply(reserve, amount);

    // Update user's risk premium and wAvgRP across all users of spoke
    uint32 newAggregatedRiskPremium = _updateRiskPremiumAndBaseDebt({
      reserve: reserve,
      user: user,
      userData: userData,
      userAddress: msg.sender,
      baseDebtChange: 0
    });
    uint256 suppliedShares = liquidityHub.supply(
      reserve.assetId,
      amount,
      newAggregatedRiskPremium,
      msg.sender // supplier
    );
    _notifyRiskPremiumUpdate(reserve.assetId, msg.sender);

    user.suppliedShares += suppliedShares;
    reserve.suppliedShares += suppliedShares;

    emit Supplied(reserveId, amount, msg.sender);
  }

  function withdraw(uint256 reserveId, uint256 amount, address to) external {
    // TODO: Be able to pass max(uint) as amount to withdraw all supplied shares
    Reserve storage reserve = _reserves[reserveId];
    UserConfig storage user = _users[msg.sender][reserveId];
    UserData storage userData = _userData[msg.sender];

    _accrueInterest(reserve, user, userData);
    _validateWithdraw(reserve, user, amount);

    // Update user's risk premium and wAvgRP across all users of spoke
    uint32 newAggregatedRiskPremium = _updateRiskPremiumAndBaseDebt({
      reserve: reserve,
      user: user,
      userData: userData,
      userAddress: msg.sender,
      baseDebtChange: 0
    });
    uint256 withdrawnShares = liquidityHub.withdraw(
      reserve.assetId,
      amount,
      newAggregatedRiskPremium,
      to
    );
    _notifyRiskPremiumUpdate(reserve.assetId, msg.sender);

    user.suppliedShares -= withdrawnShares;
    reserve.suppliedShares -= withdrawnShares;

    emit Withdrawn(reserveId, amount, msg.sender);
  }

  function borrow(uint256 reserveId, uint256 amount, address to) external {
    // TODO: referral code
    // TODO: onBehalfOf with credit delegation
    Reserve storage reserve = _reserves[reserveId];
    UserConfig storage user = _users[msg.sender][reserveId];
    UserData storage userData = _userData[msg.sender];

    _accrueInterest(reserve, user, userData);
    _validateBorrow(reserve, amount);

    // TODO HF check
    uint32 newAggregatedRiskPremium = _updateRiskPremiumAndBaseDebt({
      reserve: reserve,
      user: user,
      userData: userData,
      userAddress: msg.sender,
      baseDebtChange: int256(amount)
    });
    liquidityHub.draw(reserve.assetId, amount, newAggregatedRiskPremium, to);
    _notifyRiskPremiumUpdate(reserve.assetId, msg.sender);

    emit Borrowed(reserveId, amount, to);
  }

  function repay(uint256 reserveId, uint256 amount) external {
    // TODO: Be able to pass max(uint) as amount to restore all debt
    // TODO: onBehalfOf
    UserConfig storage user = _users[msg.sender][reserveId];
    Reserve storage reserve = _reserves[reserveId];
    UserData storage userData = _userData[msg.sender];

    _accrueInterest(reserve, user, userData);
    _validateRepay(reserve, user, amount);

    // Repaid debt happens first from premium, then base
    uint256 baseDebtRestored = _deductFromOutstandingPremium(reserve, user, amount);

    uint32 newAggregatedRiskPremium = _updateRiskPremiumAndBaseDebt({
      reserve: reserve,
      user: user,
      userData: userData,
      userAddress: msg.sender,
      baseDebtChange: -int256(baseDebtRestored)
    });

    liquidityHub.restore(
      reserve.assetId,
      amount,
      newAggregatedRiskPremium,
      msg.sender // repayer
    );
    _notifyRiskPremiumUpdate(reserve.assetId, msg.sender);

    emit Repaid(reserveId, amount, msg.sender);
  }

  function getUserRiskPremium(address user) external view returns (uint256) {
    (uint256 userRiskPremium, , ) = _calculateUserAccountData(user);
    return userRiskPremium.derayify();
  }

  // todo: for tests, imo value should be read through events
  function getLastUsedUserRiskPremium(address user) external view returns (uint256) {
    return _userData[user].riskPremium.derayify();
  }

  function getHealthFactor(address user) external view returns (uint256) {
    (, , uint256 healthFactor) = _calculateUserAccountData(user);
    return healthFactor;
  }

  function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) public {
    Reserve storage reserve = _reserves[reserveId];
    UserConfig storage user = _users[msg.sender][reserveId];

    _validateSetUsingAsCollateral(reserve, user);
    user.usingAsCollateral = usingAsCollateral;

    emit UsingAsCollateral(reserveId, usingAsCollateral, msg.sender);
  }

  function getReservePrice(uint256 reserveId) public view returns (uint256) {
    return oracle.getAssetPrice(_reserves[reserveId].assetId);
  }

  function getLiquidityPremium(uint256 reserveId) public view returns (uint256) {
    return _reserves[reserveId].config.liquidityPremium;
  }

  // /////
  // Governance
  // /////

  function addReserve(
    uint256 assetId,
    ReserveConfig memory params,
    address asset
  ) external returns (uint256) {
    uint256 _reserveCount = reserveCount;
    Reserve storage reserve = _reserves[_reserveCount];
    // TODO: validate reserveId does not exist already, valid asset
    require(
      params.liquidityPremium <= PercentageMath.PERCENTAGE_FACTOR * 10,
      'INVALID_LIQUIDITY_PREMIUM'
    );

    // TODO: AccessControl
    reservesList.push(reserveCount++);
    _reserves[_reserveCount] = Reserve({
      assetId: assetId,
      asset: asset,
      baseDebt: 0,
      outstandingPremium: 0,
      suppliedShares: 0,
      baseBorrowIndex: DEFAULT_SPOKE_INDEX,
      lastUpdateTimestamp: 0,
      riskPremium: 0,
      config: ReserveConfig({
        lt: params.lt,
        lb: params.lb,
        liquidityPremium: params.liquidityPremium,
        borrowable: params.borrowable,
        collateral: params.collateral
      })
    });

    return _reserveCount;
    // todo: emit event
  }

  function updateReserve(uint256 reserveId, ReserveConfig memory params) external {
    // TODO: More sophisticated
    require(_reserves[reserveId].asset != address(0), 'INVALID_RESERVE');
    require(
      params.liquidityPremium <= PercentageMath.PERCENTAGE_FACTOR * 10,
      'INVALID_LIQUIDITY_PREMIUM'
    );

    // TODO: AccessControl
    _reserves[reserveId].config = ReserveConfig({
      lt: params.lt,
      lb: params.lb,
      liquidityPremium: params.liquidityPremium,
      borrowable: params.borrowable,
      collateral: params.collateral
    });
  }

  // todo: access control, general setter like maker's dss, flag engine like v3
  function updateLiquidityPremium(uint256 reserveId, uint256 liquidityPremium) external {
    require(_reserves[reserveId].asset != address(0), 'INVALID_RESERVE');
    require(liquidityPremium <= PercentageMath.PERCENTAGE_FACTOR * 10, 'INVALID_LIQUIDITY_PREMIUM');
    _reserves[reserveId].config.liquidityPremium = liquidityPremium;
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
    Reserve storage reserve,
    UserConfig storage user,
    uint256 amount
  ) internal view {
    require(
      liquidityHub.convertToAssetsDown(reserve.assetId, user.suppliedShares) >= amount,
      'INSUFFICIENT_SUPPLY'
    );
  }

  function _validateBorrow(Reserve storage reserve, uint256 amount) internal view {
    require(reserve.config.borrowable, 'RESERVE_NOT_BORROWABLE');
    // TODO: validation on HF to allow borrowing amount
  }

  // TODO: Place this and LH equivalent in a generic logic library
  function _validateRepay(
    Reserve storage reserve,
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
    UserData storage userData,
    address userAddress,
    int256 baseDebtChange
  ) internal returns (uint32) {
    // Calculate risk premium of user
    (uint256 newUserRiskPremium, , ) = _calculateUserAccountData(userAddress); // todo pass this around in cached object (rm dup run in _notify)
    // Refresh weighted average risk premium across all users of spoke
    uint256 newAggregatedRiskPremium = _updateSpokeRiskPremiumAndBaseDebt(
      reserve,
      user,
      userData,
      newUserRiskPremium,
      baseDebtChange
    );
    return uint32(newAggregatedRiskPremium.derayify());
  }

  /// @dev It's assumed interest has been accrued before this function call.
  function _updateSpokeRiskPremiumAndBaseDebt(
    Reserve storage reserve,
    UserConfig storage user,
    UserData storage userData,
    uint256 newUserRiskPremium,
    int256 baseDebtChange
  ) internal returns (uint256) {
    uint256 existingReserveDebt = reserve.baseDebt;
    uint256 existingUserDebt = user.baseDebt;

    // Weighted average risk premium of all users without current user
    (uint256 reserveRiskPremiumWithoutCurrent, uint256 reserveDebtWithoutCurrent) = MathUtils
      .subtractFromWeightedAverage(
        reserve.riskPremium,
        existingReserveDebt,
        userData.riskPremium,
        existingUserDebt
      );

    uint256 newUserDebt = baseDebtChange > 0
      ? existingUserDebt + uint256(baseDebtChange) // debt added
      : existingUserDebt - uint256(-baseDebtChange); // debt restored
    // force underflow^: only possible when user takes repays amount more than net drawn

    (uint256 newReserveRiskPremium, uint256 newReserveDebt) = MathUtils.addToWeightedAverage(
      reserveRiskPremiumWithoutCurrent,
      reserveDebtWithoutCurrent,
      newUserRiskPremium,
      newUserDebt
    );

    reserve.baseDebt = newReserveDebt;
    user.baseDebt = newUserDebt;

    reserve.riskPremium = newReserveRiskPremium;
    userData.riskPremium = newUserRiskPremium;
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

  // todo opt: use bitmap
  function _isBorrowing(UserConfig storage user) internal view returns (bool) {
    return user.baseDebt + user.outstandingPremium > 0;
  }

  // todo opt: use bitmap
  function _usingAsCollateralOrBorrowing(UserConfig storage user) internal view returns (bool) {
    return _usingAsCollateral(user) || _isBorrowing(user);
  }

  function _calculateUserAccountData(
    address userAddress
  ) internal view returns (uint256, uint256, uint256) {
    CalculateUserAccountDataVars memory vars;
    uint256 reservesListLength = reservesList.length;

    while (vars.reserveId < reservesListLength) {
      UserConfig storage user = _users[userAddress][vars.reserveId];
      UserData storage userData = _userData[userAddress];

      if (!_usingAsCollateralOrBorrowing(user)) {
        unchecked {
          ++vars.reserveId;
        }
        continue;
      }
      vars.assetId = _reserves[vars.reserveId].assetId;

      vars.assetPrice = oracle.getAssetPrice(vars.assetId);
      unchecked {
        vars.assetUnit = 10 ** liquidityHub.getAssetConfig(vars.assetId).decimals;
      }

      if (_usingAsCollateral(user)) {
        // @dev opt: this can be extracted by counting number of set bits in a supplied (only) bitmap saving one loop
        unchecked {
          ++vars.collateralReserveCount;
        }
      }

      if (_isBorrowing(user)) {
        vars.totalDebtInBaseCurrency += _getUserDebtInBaseCurrency(
          user,
          userData,
          vars.assetId,
          vars.assetPrice,
          vars.assetUnit
        );
      }

      unchecked {
        ++vars.reserveId;
      }
    }

    // @dev only allocate required memory at the cost of an extra loop
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(vars.collateralReserveCount);
    vars.i = 0;
    vars.reserveId = 0;
    while (vars.reserveId < reservesListLength) {
      UserConfig storage user = _users[userAddress][vars.reserveId];
      Reserve storage reserve = _reserves[vars.reserveId];
      if (_usingAsCollateral(user)) {
        vars.assetId = reserve.assetId;
        vars.liquidityPremium = reserve.config.liquidityPremium;
        vars.assetPrice = oracle.getAssetPrice(vars.assetId);
        unchecked {
          vars.assetUnit = 10 ** liquidityHub.getAssetConfig(vars.assetId).decimals;
        }
        vars.userCollateralInBaseCurrency = _getUserBalanceInBaseCurrency(
          user,
          vars.assetId,
          vars.assetPrice,
          vars.assetUnit
        );

        vars.totalCollateralInBaseCurrency += vars.userCollateralInBaseCurrency;
        list.add(vars.i, vars.liquidityPremium, vars.userCollateralInBaseCurrency);
        vars.avgLiquidationThreshold += vars.userCollateralInBaseCurrency * reserve.config.lt;

        unchecked {
          ++vars.i;
        }
      }

      unchecked {
        ++vars.reserveId;
      }
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

    list.sortByKey(); // sort by liquidity premium
    vars.i = 0;
    // @dev from this point onwards, `totalCollateralInBaseCurrency` represents running collateral
    // value used in risk premium, `totalDebtInBaseCurrency` represents running outstanding debt
    vars.totalCollateralInBaseCurrency = 0;

    while (vars.i < vars.collateralReserveCount && vars.totalDebtInBaseCurrency > 0) {
      if (vars.totalDebtInBaseCurrency == 0) break;
      (vars.liquidityPremium, vars.userCollateralInBaseCurrency) = list.get(vars.i);
      if (vars.userCollateralInBaseCurrency > vars.totalDebtInBaseCurrency) {
        vars.userCollateralInBaseCurrency = vars.totalDebtInBaseCurrency;
      }
      vars.userRiskPremium += vars.userCollateralInBaseCurrency * vars.liquidityPremium;
      vars.totalCollateralInBaseCurrency += vars.userCollateralInBaseCurrency;
      vars.totalDebtInBaseCurrency -= vars.userCollateralInBaseCurrency;
      ++vars.i;
    }

    if (vars.totalCollateralInBaseCurrency > 0) {
      vars.userRiskPremium = (vars.userRiskPremium / vars.totalCollateralInBaseCurrency).rayify();
    }

    return (vars.userRiskPremium, vars.avgLiquidationThreshold, vars.healthFactor);
  }

  function _getUserDebtInBaseCurrency(
    UserConfig storage user,
    UserData storage userData,
    uint256 assetId,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    (uint256 cumulativeBaseDebt, uint256 cumulativeOutstandingPremium) = _previewUserInterest(
      user,
      userData,
      liquidityHub.previewNextBorrowIndex(assetId)
    );
    return ((cumulativeBaseDebt + cumulativeOutstandingPremium) * assetPrice) / assetUnit;
  }

  function _getUserBalanceInBaseCurrency(
    UserConfig storage user,
    uint256 assetId,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    return (liquidityHub.convertToAssets(assetId, user.suppliedShares) * assetPrice) / assetUnit;
  }

  function _accrueInterest(
    Reserve storage reserve,
    UserConfig storage user,
    UserData storage userData
  ) internal {
    uint256 nextBaseBorrowIndex = liquidityHub.previewNextBorrowIndex(reserve.assetId);

    // todo: lib migration
    _accrueSpokeInterest(reserve, nextBaseBorrowIndex);
    _accrueUserInterest(user, userData, nextBaseBorrowIndex);
  }

  function _previewSpokeInterest(
    Reserve storage reserve,
    uint256 nextBaseBorrowIndex
  ) internal view returns (uint256, uint256) {
    uint256 existingBaseDebt = reserve.baseDebt;
    uint256 existingOutstandingPremium = reserve.outstandingPremium;

    if (existingBaseDebt == 0 || reserve.lastUpdateTimestamp == block.timestamp) {
      return (existingBaseDebt, existingOutstandingPremium);
    }

    uint256 cumulatedBaseDebt = existingBaseDebt.rayMul(nextBaseBorrowIndex).rayDiv(
      reserve.baseBorrowIndex
    );

    return (
      cumulatedBaseDebt,
      existingOutstandingPremium +
        (cumulatedBaseDebt - existingBaseDebt).percentMul(reserve.riskPremium.derayify())
    );
  }

  function _accrueSpokeInterest(Reserve storage reserve, uint256 nextBaseBorrowIndex) internal {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = _previewSpokeInterest(
      reserve,
      nextBaseBorrowIndex
    );

    reserve.baseDebt = cumulatedBaseDebt;
    reserve.outstandingPremium = cumulatedOutstandingPremium;
    reserve.baseBorrowIndex = nextBaseBorrowIndex;
    reserve.lastUpdateTimestamp = block.timestamp;
  }

  function _previewUserInterest(
    UserConfig storage user,
    UserData storage userData, // todo opt: pass user rp only
    uint256 nextBaseBorrowIndex
  ) internal view returns (uint256, uint256) {
    uint256 existingBaseDebt = user.baseDebt;
    uint256 existingOutstandingPremium = user.outstandingPremium;

    if (existingBaseDebt == 0 || user.lastUpdateTimestamp == block.timestamp) {
      return (existingBaseDebt, existingOutstandingPremium);
    }

    uint256 cumulatedBaseDebt = existingBaseDebt.rayMul(nextBaseBorrowIndex).rayDiv(
      user.baseBorrowIndex
    );

    return (
      cumulatedBaseDebt,
      existingOutstandingPremium +
        (cumulatedBaseDebt - existingBaseDebt).percentMul(userData.riskPremium.derayify())
    );
  }

  function _accrueUserInterest(
    UserConfig storage user,
    UserData storage userData,
    uint256 nextBaseBorrowIndex
  ) internal {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = _previewUserInterest(
      user,
      userData,
      nextBaseBorrowIndex
    );

    user.baseDebt = cumulatedBaseDebt;
    user.outstandingPremium = cumulatedOutstandingPremium;
    user.baseBorrowIndex = nextBaseBorrowIndex;
    user.lastUpdateTimestamp = block.timestamp;
  }

  /**
   * @dev Trigger risk premium update on all drawn reserves of `user` except the reserve's corresponding
   * to `assetIdToAvoid` as those are expected to be updated outside of this method.
   * We only update risk premium for drawn assets and not supplied bc user RP does not contribute to
   * the other two RPs (Asset, Spoke/Reserve) as by definition they're based on drawn assets only.
   */
  function _notifyRiskPremiumUpdate(uint256 assetIdToAvoid, address userAddress) internal {
    uint256 reserveCount_ = reserveCount;
    uint256 i;
    UserData storage userData = _userData[userAddress];
    while (i < reserveCount_) {
      UserConfig storage user = _users[userAddress][i];
      Reserve storage reserve = _reserves[i];
      uint256 assetId = reserve.assetId;
      // todo keep borrowed assets in transient storage/pass through?
      if (_isBorrowing(user) && assetId != assetIdToAvoid) {
        _accrueInterest(reserve, user, userData);
        uint32 newRiskPremium = _updateRiskPremiumAndBaseDebt(
          reserve,
          user,
          userData,
          userAddress,
          0
        );
        liquidityHub.accrueInterest(assetId, newRiskPremium);
      }
      unchecked {
        ++i;
      }
    }
  }
}
