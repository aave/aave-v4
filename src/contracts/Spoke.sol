// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WadRayMath} from 'src/contracts/WadRayMath.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {MathUtils} from 'src/contracts/MathUtils.sol';
import {KeyValueListInMemory} from 'src/contracts/KeyValueListInMemory.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

contract Spoke is ISpoke {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using KeyValueListInMemory for KeyValueListInMemory.List;

  uint256 public constant DEFAULT_SPOKE_INDEX = 0;
  // todo capitalize, oracle should be mutable?
  ILiquidityHub public immutable liquidityHub;
  IPriceOracle public immutable oracle;

  mapping(address user => mapping(uint256 reserveId => DataTypes.UserPosition position))
    internal _users;
  mapping(address user => DataTypes.UserData data) internal _userData;
  mapping(uint256 reserveId => DataTypes.Reserve reserveData) internal _reserves;

  uint256[] public reservesList; // todo: rm, not needed
  uint256 public reserveCount;

  constructor(address liquidityHubAddress, address oracleAddress) {
    liquidityHub = ILiquidityHub(liquidityHubAddress);
    oracle = IPriceOracle(oracleAddress);
  }

  // /////
  // Governance
  // /////

  function addReserve(
    uint256 assetId,
    DataTypes.ReserveConfig memory params,
    address asset
  ) external returns (uint256) {
    uint256 _reserveCount = reserveCount;
    DataTypes.Reserve storage reserve = _reserves[_reserveCount];
    // TODO: validate reserveId does not exist already, valid asset
    require(
      params.liquidityPremium <= PercentageMath.PERCENTAGE_FACTOR * 10,
      InvalidLiquidityPremium()
    );

    // TODO: AccessControl
    reservesList.push(reserveCount++);
    _reserves[_reserveCount] = DataTypes.Reserve({
      reserveId: _reserveCount,
      assetId: assetId,
      asset: asset,
      baseDebt: 0,
      outstandingPremium: 0,
      suppliedShares: 0,
      baseBorrowIndex: DEFAULT_SPOKE_INDEX,
      lastUpdateTimestamp: 0,
      riskPremium: 0,
      config: DataTypes.ReserveConfig({
        lt: params.lt,
        lb: params.lb,
        liquidityPremium: params.liquidityPremium,
        borrowable: params.borrowable,
        collateral: params.collateral
      })
    });

    emit ReserveAdded(_reserveCount, assetId);

    return _reserveCount;
  }

  function updateReserveConfig(
    uint256 reserveId,
    DataTypes.ReserveConfig calldata params
  ) external {
    // TODO: More sophisticated
    require(_reserves[reserveId].asset != address(0), InvalidReserve());
    require(
      params.liquidityPremium <= PercentageMath.PERCENTAGE_FACTOR * 10,
      InvalidLiquidityPremium()
    );
    // TODO: AccessControl
    _reserves[reserveId].config = DataTypes.ReserveConfig({
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

  // todo: access control, general setter like maker's dss, flag engine like v3
  function updateLiquidityPremium(uint256 reserveId, uint256 liquidityPremium) external {
    require(_reserves[reserveId].asset != address(0), InvalidReserve());
    require(liquidityPremium <= PercentageMath.PERCENTAGE_FACTOR * 10, InvalidLiquidityPremium());
    _reserves[reserveId].config.liquidityPremium = liquidityPremium;

    emit LiquidityPremiumUpdated(reserveId, liquidityPremium);
  }

  // /////
  // Users
  // /////

  function supply(uint256 reserveId, uint256 amount) external {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage user = _users[msg.sender][reserveId];
    DataTypes.UserData storage userData = _userData[msg.sender];

    _accrueInterest(reserve, user, userData);
    _validateSupply(reserve, amount);

    (uint256 newReserveRiskPremium, uint256 newUserRiskPremium) = _updateRiskPremiumAndBaseDebt({
      reserve: reserve,
      user: user,
      userData: userData,
      userAddress: msg.sender,
      baseDebtChange: 0
    });
    uint256 suppliedShares = liquidityHub.supply(
      reserve.assetId,
      amount,
      uint32(newReserveRiskPremium.derayify()),
      msg.sender // supplier
    );
    _notifyRiskPremiumUpdate(reserve.assetId, msg.sender, newUserRiskPremium);

    user.suppliedShares += suppliedShares;
    reserve.suppliedShares += suppliedShares;

    emit Supplied(reserveId, msg.sender, amount);
  }

  function withdraw(uint256 reserveId, uint256 amount, address to) external {
    // TODO: Be able to pass max(uint) as amount to withdraw all supplied shares
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage user = _users[msg.sender][reserveId];
    DataTypes.UserData storage userData = _userData[msg.sender];

    _accrueInterest(reserve, user, userData);
    _validateWithdraw(reserve, user, amount);

    // Update user's risk premium and wAvgRP across all users of spoke
    (uint256 newReserveRiskPremium, uint256 newUserRiskPremium) = _updateRiskPremiumAndBaseDebt({
      reserve: reserve,
      user: user,
      userData: userData,
      userAddress: msg.sender,
      baseDebtChange: 0
    });
    uint256 withdrawnShares = liquidityHub.withdraw(
      reserve.assetId,
      amount,
      uint32(newReserveRiskPremium.derayify()),
      to
    );
    _notifyRiskPremiumUpdate(reserve.assetId, msg.sender, newUserRiskPremium);

    user.suppliedShares -= withdrawnShares;
    reserve.suppliedShares -= withdrawnShares;

    emit Withdrawn(reserveId, msg.sender, amount);
  }

  function borrow(uint256 reserveId, uint256 amount, address to) external {
    // TODO: referral code
    // TODO: onBehalfOf with credit delegation
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage user = _users[msg.sender][reserveId];
    DataTypes.UserData storage userData = _userData[msg.sender];

    _accrueInterest(reserve, user, userData);
    _validateBorrow(reserve, amount);

    // TODO HF check
    (uint256 newReserveRiskPremium, uint256 newUserRiskPremium) = _updateRiskPremiumAndBaseDebt({
      reserve: reserve,
      user: user,
      userData: userData,
      userAddress: msg.sender,
      baseDebtChange: int256(amount)
    });
    liquidityHub.draw(reserve.assetId, amount, uint32(newReserveRiskPremium.derayify()), to);
    _notifyRiskPremiumUpdate(reserve.assetId, msg.sender, newUserRiskPremium);

    emit Borrowed(reserveId, to, amount);
  }

  function repay(uint256 reserveId, uint256 amount) external {
    // TODO: Be able to pass max(uint) as amount to restore all debt
    // TODO: onBehalfOf
    DataTypes.UserPosition storage user = _users[msg.sender][reserveId];
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserData storage userData = _userData[msg.sender];

    _accrueInterest(reserve, user, userData);
    _validateRepay(reserve, user, amount);

    // Repaid debt happens first from premium, then base
    uint256 baseDebtRestored = _deductFromOutstandingPremium(reserve, user, amount);

    (uint256 newReserveRiskPremium, uint256 newUserRiskPremium) = _updateRiskPremiumAndBaseDebt({
      reserve: reserve,
      user: user,
      userData: userData,
      userAddress: msg.sender,
      baseDebtChange: -int256(baseDebtRestored)
    });

    liquidityHub.restore(
      reserve.assetId,
      amount,
      uint32(newReserveRiskPremium.derayify()),
      msg.sender // repayer
    );
    _notifyRiskPremiumUpdate(reserve.assetId, msg.sender, newUserRiskPremium);

    emit Repaid(reserveId, msg.sender, amount);
  }

  function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) external {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage user = _users[msg.sender][reserveId];

    _validateSetUsingAsCollateral(reserve, user);
    user.usingAsCollateral = usingAsCollateral;

    emit UsingAsCollateral(reserveId, msg.sender, usingAsCollateral);
  }

  function getUsingAsCollateral(uint256 reserveId, address user) external view returns (bool) {
    return _users[user][reserveId].usingAsCollateral;
  }

  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256) {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = _previewUserInterest(
      _users[user][reserveId],
      _userData[user],
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

  function getReserveSuppliedAmount(uint256 reserveId) external view returns (uint256) {
    return
      liquidityHub.convertToAssets(
        _reserves[reserveId].assetId,
        _reserves[reserveId].suppliedShares
      );
  }

  function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256) {
    return _reserves[reserveId].suppliedShares;
  }

  function getUserSuppliedAmount(uint256 reserveId, address user) external view returns (uint256) {
    return
      liquidityHub.convertToAssets(
        _reserves[reserveId].assetId,
        _users[user][reserveId].suppliedShares
      );
  }

  function getUserSuppliedShares(uint256 reserveId, address user) external view returns (uint256) {
    return _users[user][reserveId].suppliedShares;
  }
  function getUserBaseBorrowIndex(uint256 reserveId, address user) external view returns (uint256) {
    return _users[user][reserveId].baseBorrowIndex;
  }

  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256) {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = _previewSpokeInterest(
      _reserves[reserveId],
      liquidityHub.previewNextBorrowIndex(_reserves[reserveId].assetId)
    );
    return (cumulatedBaseDebt, cumulatedOutstandingPremium);
  }

  function getReserveCumulativeDebt(uint256 reserveId) external view returns (uint256) {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = _previewSpokeInterest(
      _reserves[reserveId],
      liquidityHub.previewNextBorrowIndex(_reserves[reserveId].assetId)
    );
    return cumulatedBaseDebt + cumulatedOutstandingPremium;
  }

  // todo by default returns only stored value, consider renaming to `getLast{Used,Stored}ReserveRiskPremium`
  // to be inline with user's stored rp getter. we don't have an up to date rp concept here since that requires
  // looping over all contributing users (ie one's drawing this reserve)
  function getReserveRiskPremium(uint256 reserveId) external view returns (uint256) {
    return _reserves[reserveId].riskPremium.derayify();
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

  function getReservePrice(uint256 reserveId) public view returns (uint256) {
    return oracle.getAssetPrice(_reserves[reserveId].assetId);
  }

  function getLiquidityPremium(uint256 reserveId) public view returns (uint256) {
    return _reserves[reserveId].config.liquidityPremium;
  }

  // public
  function getReserve(uint256 reserveId) public view returns (DataTypes.Reserve memory) {
    return _reserves[reserveId];
  }

  function getUserPosition(
    uint256 reserveId,
    address user
  ) public view returns (DataTypes.UserPosition memory) {
    return _users[user][reserveId];
  }

  // internal
  function _validateSupply(DataTypes.Reserve storage reserve, uint256 amount) internal view {
    require(reserve.asset != address(0), ReserveNotListed());
  }

  function _validateWithdraw(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage user,
    uint256 amount
  ) internal view {
    uint256 suppliedAmount = liquidityHub.convertToAssetsDown(reserve.assetId, user.suppliedShares);
    require(amount <= suppliedAmount, InsufficientSupply(suppliedAmount));
  }

  function _validateBorrow(DataTypes.Reserve storage reserve, uint256 amount) internal view {
    require(reserve.config.borrowable, ReserveNotBorrowable(reserve.reserveId));
    // TODO: validation on HF to allow borrowing amount
  }

  // TODO: Place this and LH equivalent in a generic logic library
  function _validateRepay(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage user,
    uint256 amount
  ) internal view {
    uint256 userDebt = user.baseDebt + user.outstandingPremium;
    require(amount <= userDebt, RepayAmountExceedsDebt(userDebt));
  }

  function _deductFromOutstandingPremium(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage user,
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
   * @dev It's assumed interest has been accrued before for the given `reserve` and `user`Position.
   * @dev Does not update user risk premium, rather returns the updated value to be used in `_notify`
   * @return New spoke/reserve risk premium (rayified)
   * @return New user risk premium (rayified)
   */
  function _updateRiskPremiumAndBaseDebt(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage user,
    DataTypes.UserData storage userData,
    address userAddress,
    int256 baseDebtChange
  ) internal returns (uint256, uint256) {
    uint256 reserveDebt = reserve.baseDebt;
    uint256 userDebt = user.baseDebt;

    // Weighted average risk premium of all users without current user
    (uint256 reserveRiskPremiumWithoutCurrent, uint256 reserveDebtWithoutCurrent) = MathUtils
      .subtractFromWeightedAverage(
        reserve.riskPremium,
        reserveDebt, // existing
        userData.riskPremium,
        userDebt // existing
      );

    // debt added
    if (baseDebtChange > 0) {
      reserveDebt += uint256(baseDebtChange);
      userDebt += uint256(baseDebtChange);
    }
    // debt restored, force underflow: only possible when user takes repays amount more than net drawn
    else if (baseDebtChange < 0) {
      reserveDebt -= uint256(-baseDebtChange);
      userDebt -= uint256(-baseDebtChange);
    }

    reserve.baseDebt = reserveDebt;
    user.baseDebt = userDebt;

    // todo consider decoupling risk premium calc, pass in cached obj
    // @dev we need `user.baseDebt` (userPosition.baseDebt) updated before calculating new user risk premium
    (uint256 newUserRiskPremium, , ) = _calculateUserAccountData(userAddress);

    (uint256 newReserveRiskPremium, ) = MathUtils.addToWeightedAverage(
      reserveRiskPremiumWithoutCurrent,
      reserveDebtWithoutCurrent,
      newUserRiskPremium,
      userDebt // new
    );

    reserve.riskPremium = newReserveRiskPremium;

    return (newReserveRiskPremium, newUserRiskPremium);
  }

  function _validateSetUsingAsCollateral(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage user
  ) internal view {
    require(reserve.config.collateral, ReserveNotCollateral(reserve.reserveId));
  }

  function _usingAsCollateral(DataTypes.UserPosition storage user) internal view returns (bool) {
    return user.usingAsCollateral;
  }

  // todo opt: use bitmap
  function _isBorrowing(DataTypes.UserPosition storage user) internal view returns (bool) {
    return user.baseDebt + user.outstandingPremium > 0;
  }

  // todo opt: use bitmap
  function _usingAsCollateralOrBorrowing(
    DataTypes.UserPosition storage user
  ) internal view returns (bool) {
    return _usingAsCollateral(user) || _isBorrowing(user);
  }

  function _calculateUserAccountData(
    address userAddress
  ) internal view returns (uint256, uint256, uint256) {
    DataTypes.CalculateUserAccountDataVars memory vars;
    uint256 reservesListLength = reservesList.length;

    while (vars.reserveId < reservesListLength) {
      DataTypes.UserPosition storage user = _users[userAddress][vars.reserveId];
      DataTypes.UserData storage userData = _userData[userAddress];

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
      DataTypes.UserPosition storage user = _users[userAddress][vars.reserveId];
      DataTypes.Reserve storage reserve = _reserves[vars.reserveId];
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
    DataTypes.UserPosition storage user,
    DataTypes.UserData storage userData,
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
    DataTypes.UserPosition storage user,
    uint256 assetId,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    return (liquidityHub.convertToAssets(assetId, user.suppliedShares) * assetPrice) / assetUnit;
  }

  function _accrueInterest(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage user,
    DataTypes.UserData storage userData
  ) internal {
    uint256 nextBaseBorrowIndex = liquidityHub.previewNextBorrowIndex(reserve.assetId);

    // todo: lib migration
    _accrueSpokeInterest(reserve, nextBaseBorrowIndex);
    _accrueUserInterest(user, userData, nextBaseBorrowIndex);
  }

  function _previewSpokeInterest(
    DataTypes.Reserve storage reserve,
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

  function _accrueSpokeInterest(
    DataTypes.Reserve storage reserve,
    uint256 nextBaseBorrowIndex
  ) internal {
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
    DataTypes.UserPosition storage user,
    DataTypes.UserData storage userData, // todo opt: pass user rp only
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
    DataTypes.UserPosition storage user,
    DataTypes.UserData storage userData,
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
   * @dev Also commits user's new risk premium to storage.
   */
  function _notifyRiskPremiumUpdate(
    uint256 assetIdToAvoid,
    address userAddress,
    uint256 newUserRiskPremium
  ) internal {
    uint256 reserveCount_ = reserveCount;
    uint256 i;
    DataTypes.UserData storage userData = _userData[userAddress];
    // _updateRiskPremiumAndBaseDebt does not update user risk premium, opt: pass this value in cached obj
    uint256 existingUserRiskPremium = userData.riskPremium;
    while (i < reserveCount_) {
      DataTypes.UserPosition storage user = _users[userAddress][i];
      DataTypes.Reserve storage reserve = _reserves[i];
      uint256 assetId = reserve.assetId;
      // todo keep borrowed assets in transient storage/pass through?
      if (_isBorrowing(user) && assetId != assetIdToAvoid) {
        // this was accrued on the fly when calculating `newUserRiskPremium`, opt: decouple and commit before
        _accrueInterest(reserve, user, userData);
        uint256 newReserveRiskPremium = _refreshReserveRiskPremium({
          reserve: reserve,
          user: user,
          existingUserRiskPremium: existingUserRiskPremium,
          newUserRiskPremium: newUserRiskPremium
        });
        liquidityHub.accrueInterest(assetId, uint32(newReserveRiskPremium.derayify()));
      }
      unchecked {
        ++i;
      }
    }
    userData.riskPremium = newUserRiskPremium;
  }

  /**
   * @dev Refresh reserve's risk premium with the new user risk premium. Similar to _updateRiskPremiumAndBaseDebt
   * with baseDebtChange == 0, and precalculated new user risk premium.
   * @dev It is assumed debt has already been accrued on this `reserve` & `user`Position, and newUserRiskPremium
   * is calculated with all accrued reserves.
   * @dev This is currently only used on `_notifyRiskPremiumUpdate`; since no debt is added/removed on this reserve,
   * hence it doesn't change the new user risk premium.
   * TODO: Optimize later to use this method in `supply` & `withdraw` as well.
   * @return New reserve risk premium (rayified)
   */
  function _refreshReserveRiskPremium(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage user, // user position on this reserve
    uint256 existingUserRiskPremium,
    uint256 newUserRiskPremium
  ) internal returns (uint256) {
    uint256 userDebt = user.baseDebt;

    // todo: opt - implement `updateValueInWeightedAverage` in MathUtils to coalesce these two calls
    (uint256 reserveRiskPremiumWithoutCurrent, uint256 reserveDebtWithoutCurrent) = MathUtils
      .subtractFromWeightedAverage(
        reserve.riskPremium,
        reserve.baseDebt,
        existingUserRiskPremium,
        userDebt
      );
    (uint256 newReserveRiskPremium, ) = MathUtils.addToWeightedAverage(
      reserveRiskPremiumWithoutCurrent,
      reserveDebtWithoutCurrent,
      newUserRiskPremium,
      userDebt
    );

    // @dev no need to update `reserve.baseDebt` & `user.baseDebt` as there is no debt change
    reserve.riskPremium = newReserveRiskPremium;

    return newReserveRiskPremium;
  }
}
