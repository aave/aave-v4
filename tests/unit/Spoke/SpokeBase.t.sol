// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import {KeyValueListInMemory} from 'src/libraries/helpers/KeyValueListInMemory.sol';

contract SpokeBase is Base {
  using SafeCast for *;
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using KeyValueListInMemory for KeyValueListInMemory.List;

  struct Debts {
    uint256 baseDebt;
    uint256 premiumDebt;
    uint256 totalDebt;
  }

  struct TestData {
    DataTypes.Reserve data;
    uint256 suppliedAmount;
  }

  struct TestUserData {
    DataTypes.UserPosition data;
    uint256 suppliedAmount;
  }

  struct TokenData {
    uint256 spokeBalance;
    uint256 hubBalance;
  }

  struct TestReserve {
    uint256 reserveId;
    uint256 supplyAmount;
    uint256 borrowAmount;
    address supplier;
    address borrower;
  }

  struct DebtData {
    uint256 totalDebt;
    uint256 baseDebt;
    uint256 premiumDebt;
  }

  struct UserActionData {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 repayAmount;
    uint256 userBalanceBefore;
    uint256 userBalanceAfter;
    DataTypes.UserPosition userPosBefore;
  }

  struct BorrowTestData {
    uint256 daiReserveId;
    uint256 wethReserveId;
    uint256 usdxReserveId;
    uint256 wbtcReserveId;
    UserActionData daiAlice;
    UserActionData wethAlice;
    UserActionData usdxAlice;
    UserActionData wbtcAlice;
    UserActionData daiBob;
    UserActionData wethBob;
    UserActionData usdxBob;
    UserActionData wbtcBob;
  }

  struct SupplyBorrowLocal {
    uint256 collateralReserveAssetId;
    uint256 borrowReserveAssetId;
    uint256 collateralSupplyShares;
    uint256 borrowSupplyShares;
    uint256 reserveSharesBefore;
    uint256 userSharesBefore;
    uint256 borrowerBaseDebtBefore;
    uint256 reserveBaseDebtBefore;
    uint256 borrowerBaseDebtAfter;
    uint256 reserveBaseDebtAfter;
  }

  struct RepayMultipleLocal {
    uint256 borrowAmount;
    uint256 repayAmount;
    DataTypes.UserPosition posBefore; // positionBefore
    DataTypes.UserPosition posAfter; // positionAfter
    uint256 baseRestored;
    uint256 premiumRestored;
  }

  struct Action {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 repayAmount;
    uint40 skipTime;
  }

  struct AssetInfo {
    uint256 borrowAmount;
    uint256 repayAmount;
    uint256 baseRestored;
    uint256 premiumRestored;
    uint256 suppliedShares;
  }

  struct UserAction {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 suppliedShares;
    uint256 repayAmount;
    uint256 baseRestored;
    uint256 premiumRestored;
    address user;
  }

  struct UserBorrowAction {
    uint256 supplyAmount;
    uint256 borrowAmount;
  }

  struct UserAssetInfo {
    AssetInfo daiInfo;
    AssetInfo wethInfo;
    AssetInfo usdxInfo;
    AssetInfo wbtcInfo;
    address user;
  }

  struct ReserveIds {
    uint256 dai;
    uint256 weth;
    uint256 usdx;
    uint256 wbtc;
  }

  struct DynamicConfig {
    uint16 key;
    bool enabled;
  }

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();
  }

  /// @dev Opens a supply position for a random user
  function _openSupplyPosition(ISpoke spoke, uint256 reserveId, uint256 amount) public {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    uint256 initialLiq = hub.getAvailableLiquidity(assetId);

    address tempUser = vm.randomAddress();
    IERC20 underlying = IERC20(spoke.getReserve(reserveId).underlying);
    deal(address(underlying), tempUser, amount);

    vm.prank(tempUser);
    underlying.approve(address(hub), type(uint256).max);

    Utils.supply({
      spoke: spoke,
      reserveId: reserveId,
      caller: tempUser,
      amount: amount,
      onBehalfOf: tempUser
    });

    assertEq(hub.getAvailableLiquidity(assetId), initialLiq + amount);
  }

  /// @dev Opens a debt position for a random user, using same asset as collateral and borrow
  function _openDebtPosition(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount,
    bool withPremium
  ) internal returns (uint256) {
    address tempUser = vm.randomAddress();

    // add collateral
    uint256 supplyAmount = _calcMinimumCollAmount({
      spoke: spoke,
      collReserveId: reserveId,
      debtReserveId: reserveId,
      debtAmount: amount
    });

    IERC20 underlying = IERC20(spoke.getReserve(reserveId).underlying);
    deal(address(underlying), tempUser, supplyAmount);
    vm.prank(tempUser);
    underlying.approve(address(hub), type(uint256).max);

    Utils.supplyCollateral({
      spoke: spoke,
      reserveId: reserveId,
      caller: tempUser,
      amount: supplyAmount,
      onBehalfOf: tempUser
    });

    // debt
    uint256 cachedCollateralRisk;
    if (withPremium) {
      cachedCollateralRisk = _getCollateralRisk(spoke, reserveId);
      updateCollateralRisk(spoke, reserveId, 50_00);
    }

    Utils.borrow({
      spoke: spoke,
      reserveId: reserveId,
      caller: tempUser,
      amount: amount,
      onBehalfOf: tempUser
    });
    skip(365 days);

    (uint256 baseDebt, uint256 premiumDebt) = spoke.getReserveDebt(reserveId);
    assertGt(baseDebt, 0); // non-zero premium debt

    if (withPremium) {
      assertGt(premiumDebt, 0);
      // restore cached collateral risk
      updateCollateralRisk(spoke, reserveId, cachedCollateralRisk);
    }
  }

  // increase share conversion index on given reserve
  // bob supplies borrow asset
  // alice supply (weth) collateral asset, borrow asset, skip 1 year to increase index
  /// @return supply amount of collateral asset
  /// @return supply shares of collateral asset
  /// @return borrow amount of borrowed asset
  /// @return supply shares of borrowed asset
  /// @return supply amount of borrowed asset
  function _increaseReserveIndex(
    ISpoke spoke,
    uint256 reserveId
  ) internal returns (uint256, uint256, uint256, uint256, uint256) {
    SupplyBorrowLocal memory state;

    TestReserve memory collateral;
    collateral.reserveId = _wethReserveId(spoke);
    collateral.supplyAmount = 1_000e18;
    collateral.supplier = alice;

    TestReserve memory borrow;
    borrow.reserveId = reserveId;
    borrow.supplier = bob;
    borrow.borrower = alice;
    borrow.supplyAmount = 100e18;
    borrow.borrowAmount = borrow.supplyAmount / 2;

    (state.borrowReserveAssetId, ) = getAssetByReserveId(spoke, borrow.reserveId);
    (state.collateralSupplyShares, state.borrowSupplyShares) = _executeSpokeSupplyAndBorrow({
      spoke: spoke,
      collateral: collateral,
      borrow: borrow,
      rate: 0,
      isMockRate: false,
      skipTime: 365 days
    });

    // index has increased, ie now the shares are less than the amount
    assertGt(
      borrow.supplyAmount,
      hub.convertToSuppliedShares(state.borrowReserveAssetId, borrow.supplyAmount)
    );

    return (
      collateral.supplyAmount,
      state.collateralSupplyShares,
      borrow.borrowAmount,
      state.borrowSupplyShares,
      borrow.supplyAmount
    );
  }

  // supply collateral asset, borrow asset, skip time to increase index on borrow asset
  /// @return supplyShares of collateral asset
  /// @return supplyShares of borrowed asset
  function _executeSpokeSupplyAndBorrow(
    ISpoke spoke,
    TestReserve memory collateral,
    TestReserve memory borrow,
    uint256 rate,
    bool isMockRate,
    uint256 skipTime
  ) internal returns (uint256, uint256) {
    SupplyBorrowLocal memory state;
    if (isMockRate) {
      _mockInterestRateBps(rate);
    }
    (state.collateralReserveAssetId, ) = getAssetByReserveId(spoke, collateral.reserveId);
    (state.borrowReserveAssetId, ) = getAssetByReserveId(spoke, borrow.reserveId);
    state.collateralSupplyShares = hub.convertToSuppliedShares(
      state.collateralReserveAssetId,
      collateral.supplyAmount
    );
    state.borrowSupplyShares = hub.convertToSuppliedShares(
      state.borrowReserveAssetId,
      borrow.supplyAmount
    );
    state.reserveSharesBefore = spoke.getReserveSuppliedShares(collateral.reserveId);
    state.userSharesBefore = spoke.getUserSuppliedShares(collateral.reserveId, collateral.supplier);
    // supply collateral asset
    Utils.supplyCollateral({
      spoke: spoke,
      reserveId: collateral.reserveId,
      caller: collateral.supplier,
      amount: collateral.supplyAmount,
      onBehalfOf: collateral.supplier
    });
    assertEq(
      state.reserveSharesBefore + state.collateralSupplyShares,
      spoke.getReserveSuppliedShares(collateral.reserveId)
    );
    assertEq(
      state.userSharesBefore + state.collateralSupplyShares,
      spoke.getUserSuppliedShares(collateral.reserveId, collateral.supplier)
    );
    state.reserveSharesBefore = spoke.getReserveSuppliedShares(borrow.reserveId);
    state.userSharesBefore = spoke.getUserSuppliedShares(borrow.reserveId, borrow.supplier);
    // other user supplies enough asset to be drawn
    Utils.supply({
      spoke: spoke,
      reserveId: borrow.reserveId,
      caller: borrow.supplier,
      amount: borrow.supplyAmount,
      onBehalfOf: borrow.supplier
    });
    assertEq(
      state.reserveSharesBefore + state.borrowSupplyShares,
      spoke.getReserveSuppliedShares(borrow.reserveId)
    );
    assertEq(
      state.userSharesBefore + state.borrowSupplyShares,
      spoke.getUserSuppliedShares(borrow.reserveId, borrow.supplier)
    );
    (state.borrowerBaseDebtBefore, ) = spoke.getUserDebt(borrow.reserveId, borrow.borrower);
    (state.reserveBaseDebtBefore, ) = spoke.getReserveDebt(borrow.reserveId);
    // borrower borrows asset
    Utils.borrow({
      spoke: spoke,
      reserveId: borrow.reserveId,
      caller: borrow.borrower,
      amount: borrow.borrowAmount,
      onBehalfOf: borrow.borrower
    });
    (state.borrowerBaseDebtAfter, ) = spoke.getUserDebt(borrow.reserveId, borrow.borrower);
    (state.reserveBaseDebtAfter, ) = spoke.getReserveDebt(borrow.reserveId);
    assertEq(state.borrowerBaseDebtBefore + borrow.borrowAmount, state.borrowerBaseDebtAfter);
    assertEq(state.reserveBaseDebtBefore + borrow.borrowAmount, state.reserveBaseDebtAfter);
    // skip time to increase index
    skip(skipTime);
    return (state.collateralSupplyShares, state.borrowSupplyShares);
  }

  function _repayAll(
    ISpoke spoke,
    function(ISpoke) view returns (uint256) _assetReserveId
  ) internal {
    uint256 reserveId = _assetReserveId(spoke);
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    uint256 assetDebtWithoutSpoke = hub.getAssetTotalDebt(assetId) -
      hub.getSpokeTotalDebt(assetId, address(spoke));

    address[4] memory users = [alice, bob, carol, derl];
    for (uint256 i; i < users.length; ++i) {
      address user = users[i];
      uint256 debt = spoke.getUserTotalDebt(reserveId, user);
      if (debt > 0) {
        deal(hub.getAsset(assetId).underlying, user, debt);
        vm.prank(user);
        spoke.repay(reserveId, debt, user);
        assertEq(spoke.getUserTotalDebt(reserveId, user), 0, 'user debt not zero');
        assertFalse(spoke.isBorrowing(reserveId, user));
        // If the user has no debt in any asset (hf will be max), user risk premium should be zero
        if (spoke.getHealthFactor(user) == type(uint256).max) {
          assertEq(spoke.getUserRiskPremium(user), 0, 'user risk premium not zero');
        }
      }
    }

    assertEq(spoke.getReserveTotalDebt(reserveId), 0, 'reserve total debt not zero');
    assertEq(hub.getSpokeTotalDebt(assetId, address(spoke)), 0, 'hub spoke total debt not zero');
    assertEq(
      hub.getAssetTotalDebt(assetId),
      assetDebtWithoutSpoke,
      'hub asset total debt not settled'
    );
  }

  function loadReserveInfo(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (TestData memory) {
    TestData memory reserveInfo;
    reserveInfo.data = getReserveInfo(spoke, reserveId);
    reserveInfo.suppliedAmount = spoke.getReserveSuppliedAmount(reserveId);
    return reserveInfo;
  }

  function loadUserInfo(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (TestUserData memory) {
    TestUserData memory userInfo;
    userInfo.data = getUserInfo(spoke, user, reserveId);
    userInfo.suppliedAmount = spoke.getUserSuppliedAmount(reserveId, user);
    return userInfo;
  }

  function getTokenBalances(IERC20 token, address spoke) internal view returns (TokenData memory) {
    return
      TokenData({spokeBalance: token.balanceOf(spoke), hubBalance: token.balanceOf(address(hub))});
  }

  function _calcMinimumCollAmount(
    ISpoke spoke,
    uint256 collReserveId,
    uint256 debtReserveId,
    uint256 debtAmount
  ) internal view returns (uint256) {
    if (debtAmount == 0) return 1;

    IPriceOracle oracle = spoke.oracle();
    DataTypes.Reserve memory collData = spoke.getReserve(collReserveId);
    DataTypes.DynamicReserveConfig memory colDynConf = spoke.getDynamicReserveConfig(collReserveId);
    uint256 collPrice = oracle.getReservePrice(collReserveId);
    uint256 collAssetUnits = 10 ** hub.getAsset(collData.assetId).decimals;

    DataTypes.Reserve memory debtData = spoke.getReserve(debtReserveId);
    uint256 debtAssetUnits = 10 ** hub.getAsset(debtData.assetId).decimals;
    uint256 debtPrice = oracle.getReservePrice(debtReserveId);

    uint256 normalizedDebtAmount = (debtAmount * debtPrice).wadDivDown(debtAssetUnits);
    uint256 normalizedCollPrice = collPrice.wadDivDown(collAssetUnits);

    return
      normalizedDebtAmount.wadDivUp(
        normalizedCollPrice.toWad().percentMulDown(colDynConf.collateralFactor)
      );
  }

  function _calcMaxDebtAmount(
    ISpoke spoke,
    uint256 collReserveId,
    uint256 debtReserveId,
    uint256 collAmount
  ) internal view returns (uint256) {
    IPriceOracle oracle = spoke.oracle();
    DataTypes.Reserve memory collData = spoke.getReserve(collReserveId);
    DataTypes.DynamicReserveConfig memory colDynConf = spoke.getDynamicReserveConfig(collReserveId);
    uint256 collPrice = oracle.getReservePrice(collReserveId);
    uint256 collAssetUnits = 10 ** hub.getAsset(collData.assetId).decimals;

    DataTypes.Reserve memory debtData = spoke.getReserve(debtReserveId);
    uint256 debtAssetUnits = 10 ** hub.getAsset(debtData.assetId).decimals;
    uint256 debtPrice = oracle.getReservePrice(debtReserveId);

    uint256 normalizedDebtAmount = (debtPrice).wadDivDown(debtAssetUnits);
    uint256 normalizedCollPrice = (collAmount * collPrice).wadDivDown(collAssetUnits);

    uint256 maxDebt = (
      (normalizedCollPrice.toWad().percentMulDown(colDynConf.collateralFactor) /
        normalizedDebtAmount.toWad())
    );

    return maxDebt > 1 ? maxDebt - 1 : maxDebt;
  }

  // assert that user's position and debt accounting matches expected
  function _assertUserPositionAndDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 debtAmount,
    uint256 suppliedAmount,
    uint256 expectedRealizedPremium,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;

    // user position
    DataTypes.UserPosition memory userPos = getUserInfo(spoke, user, reserveId);
    DataTypes.UserPosition memory expectedUserPos = _calcUserPositionBySuppliedAndDebtAmount(
      spoke,
      user,
      expectedRealizedPremium,
      assetId,
      debtAmount,
      suppliedAmount
    );

    // user debt
    DebtData memory expectedUserDebt = _calcExpectedUserDebt(assetId, expectedUserPos);
    DebtData memory userDebt = _getUserDebt(spoke, reserveId, user);
    assertEq(spoke.isBorrowing(reserveId, user), userDebt.totalDebt > 0);

    // assertions
    _assertUserPosition(userPos, expectedUserPos, label);
    _assertUserDebt(userDebt, expectedUserDebt, label);
  }

  function _calcExpectedUserDebt(
    uint256 assetId,
    DataTypes.UserPosition memory userPos
  ) internal view returns (DebtData memory userDebt) {
    uint256 accruedPremium = hub.convertToDrawnAssets(assetId, userPos.premiumDrawnShares) -
      userPos.premiumOffset;
    userDebt.premiumDebt = userPos.realizedPremium + accruedPremium;
    userDebt.baseDebt = hub.convertToDrawnAssets(assetId, userPos.baseDrawnShares);
    userDebt.totalDebt = userDebt.baseDebt + userDebt.premiumDebt;
  }

  function _getUserDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (DebtData memory) {
    DebtData memory userDebt;
    userDebt.totalDebt = spoke.getUserTotalDebt(reserveId, user);
    (userDebt.baseDebt, userDebt.premiumDebt) = spoke.getUserDebt(reserveId, user);
    assertEq(userDebt.totalDebt, userDebt.baseDebt + userDebt.premiumDebt);
    return userDebt;
  }

  // assert that user position matches expected
  function _assertUserPosition(
    DataTypes.UserPosition memory userPos,
    DataTypes.UserPosition memory expectedUserPos,
    string memory label
  ) internal pure {
    assertEq(
      userPos.suppliedShares,
      expectedUserPos.suppliedShares,
      string.concat('user supplied shares ', label)
    );
    assertEq(
      userPos.baseDrawnShares,
      expectedUserPos.baseDrawnShares,
      string.concat('user baseDrawnShares ', label)
    );
    assertEq(
      userPos.premiumDrawnShares,
      expectedUserPos.premiumDrawnShares,
      string.concat('user premiumDrawnShares ', label)
    );
    assertApproxEqAbs(
      userPos.premiumOffset,
      expectedUserPos.premiumOffset,
      1,
      string.concat('user premiumOffset ', label)
    );
    assertEq(
      userPos.realizedPremium,
      expectedUserPos.realizedPremium,
      string.concat('user realized premium ', label)
    );
  }

  function _assertUserDebt(
    DebtData memory userDebt,
    DebtData memory expectedUserDebt,
    string memory label
  ) internal pure {
    assertEq(userDebt.baseDebt, expectedUserDebt.baseDebt, string.concat('user base debt ', label));
    assertApproxEqAbs(
      userDebt.premiumDebt,
      expectedUserDebt.premiumDebt,
      1,
      string.concat('user premium debt ', label)
    );
    assertApproxEqAbs(
      userDebt.totalDebt,
      expectedUserDebt.totalDebt,
      1,
      string.concat('user total debt ', label)
    );
  }

  // calculate expected user position using latest risk premium
  function _calcUserPositionBySuppliedAndDebtAmount(
    ISpoke spoke,
    address user,
    uint256 expectedRealizedPremium,
    uint256 assetId,
    uint256 debtAmount,
    uint256 suppliedAmount
  ) internal view returns (DataTypes.UserPosition memory userPos) {
    (uint256 riskPremium, , , , ) = spoke.getUserAccountData(user);

    userPos.baseDrawnShares = hub.convertToDrawnShares(assetId, debtAmount);
    userPos.premiumDrawnShares = hub.convertToDrawnShares(assetId, debtAmount).percentMulUp(
      riskPremium
    );
    userPos.premiumOffset = hub.convertToDrawnAssets(assetId, userPos.premiumDrawnShares);
    userPos.realizedPremium = expectedRealizedPremium;
    userPos.suppliedShares = hub.convertToSuppliedShares(assetId, suppliedAmount);
  }

  /// calculated expected realized premium
  /// MUST be called prior to user action to utilize prior exch rate
  function _calculateExpectedRealizedPremium(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    DataTypes.UserPosition memory userPos = getUserInfo(spoke, user, assetId);
    return hub.convertToDrawnAssets(assetId, userPos.premiumDrawnShares) - userPos.premiumOffset;
  }

  /// assert that realized premium matches naively calculated value
  function _assertRealizedPremiumCalcMatchesNaive(
    ISpoke spoke,
    uint256 reserveId,
    uint256 prevBaseDebt,
    DataTypes.UserPosition memory userPos,
    uint40 lastTimestamp
  ) internal view returns (uint256) {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    uint256 accruedBase = MathUtils
      .calculateLinearInterest(hub.getAsset(assetId).baseBorrowRate, lastTimestamp)
      .rayMulUp(prevBaseDebt);

    // equivalent to multiplying by risk premium (RP = premium drawn shares / base drawn shares)
    assertApproxEqAbs(
      userPos.realizedPremium,
      ((accruedBase - prevBaseDebt) * (userPos.premiumDrawnShares)) / (userPos.baseDrawnShares),
      3, // precision loss due to calcs in asset amount and conversion to
      'realized premium naive calc'
    );
  }

  /// assert that sum across User storage debt matches Reserve storage debt
  function _assertUsersAndReserveDebt(
    ISpoke spoke,
    uint256 reserveId,
    address[] memory users,
    string memory label
  ) internal view {
    DebtData memory reserveDebt;
    DebtData memory usersDebt;
    uint256 assetId = spoke.getReserve(reserveId).assetId;

    reserveDebt.totalDebt = spoke.getReserveTotalDebt(reserveId);
    (reserveDebt.baseDebt, reserveDebt.premiumDebt) = spoke.getReserveDebt(reserveId);

    for (uint256 i = 0; i < users.length; ++i) {
      DataTypes.UserPosition memory userData = getUserInfo(spoke, users[i], reserveId);
      (uint256 baseDebt, uint256 premiumDebt) = spoke.getUserDebt(reserveId, users[i]);

      usersDebt.baseDebt += baseDebt;
      usersDebt.premiumDebt += premiumDebt;
      usersDebt.totalDebt += baseDebt + premiumDebt;

      assertEq(
        baseDebt,
        hub.convertToDrawnAssets(assetId, userData.baseDrawnShares),
        string.concat('user ', vm.toString(i), ' base debt ', label)
      );
      assertEq(
        premiumDebt,
        userData.realizedPremium +
          hub.convertToDrawnAssets(assetId, userData.premiumDrawnShares) -
          userData.premiumOffset,
        string.concat('user ', vm.toString(i), ' premium debt ', label)
      );
    }

    assertEq(
      reserveDebt.baseDebt,
      usersDebt.baseDebt,
      string.concat('reserve vs sum users base debt ', label)
    );
    assertEq(
      reserveDebt.premiumDebt,
      usersDebt.premiumDebt,
      string.concat('reserve vs sum users premium debt ', label)
    );
    assertEq(
      reserveDebt.totalDebt,
      usersDebt.totalDebt,
      string.concat('reserve vs sum users total debt ', label)
    );
  }

  function assertEq(DataTypes.Reserve memory a, DataTypes.Reserve memory b) internal pure {
    assertEq(a.reserveId, b.reserveId, 'reserve Id');
    assertEq(a.assetId, b.assetId, 'asset Id');
    assertEq(a.underlying, b.underlying, 'Asset addresses mismatch');
    assertEq(a.config, b.config);
    assertEq(abi.encode(a), abi.encode(b)); // sanity check
  }

  function assertEq(
    DataTypes.UserPosition memory a,
    DataTypes.UserPosition memory b
  ) internal pure {
    assertEq(a.suppliedShares, b.suppliedShares, 'suppliedShares');
    assertEq(a.baseDrawnShares, b.baseDrawnShares, 'baseDrawnShares');
    assertEq(a.premiumDrawnShares, b.premiumDrawnShares, 'premiumDrawnShares');
    assertEq(a.premiumOffset, b.premiumOffset, 'premiumOffset');
    assertEq(a.realizedPremium, b.baseDrawnShares, 'realizedPremium');
    assertEq(a.configKey, b.configKey, 'configKey');
    assertEq(abi.encode(a), abi.encode(b)); // sanity check
  }

  function _assertUserRpUnchanged(uint256 reserveId, ISpoke spoke, address user) internal view {
    DataTypes.UserPosition memory pos = spoke.getUserPosition(reserveId, user);
    uint256 riskPremiumStored = pos.premiumDrawnShares.percentDivDown(pos.baseDrawnShares);
    (uint256 riskPremiumCurrent, , , , ) = spoke.getUserAccountData(user);
    assertEq(riskPremiumCurrent, riskPremiumStored, 'user risk premium mismatch');
  }

  function _getUserRpStored(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    DataTypes.UserPosition memory pos = spoke.getUserPosition(reserveId, user);
    // sanity check
    assertTrue(
      pos.baseDrawnShares > 0 || pos.premiumDrawnShares == 0,
      'if base is zero, premium must be zero'
    );
    if (pos.baseDrawnShares == 0) return 0;
    return pos.premiumDrawnShares.percentDivDown(pos.baseDrawnShares);
  }

  function _boundUserAction(UserAction memory action) internal pure returns (UserAction memory) {
    action.borrowAmount = bound(action.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 8);
    action.repayAmount = bound(action.repayAmount, 1, type(uint256).max);

    return action;
  }

  function _bound(UserAssetInfo memory info) internal pure returns (UserAssetInfo memory) {
    // Bound borrow amounts
    info.daiInfo.borrowAmount = bound(info.daiInfo.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 8);
    info.wethInfo.borrowAmount = bound(info.wethInfo.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 8);
    info.usdxInfo.borrowAmount = bound(info.usdxInfo.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 8);
    info.wbtcInfo.borrowAmount = bound(info.wbtcInfo.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 8);

    // Bound repay amounts
    info.daiInfo.repayAmount = bound(info.daiInfo.repayAmount, 1, type(uint256).max);
    info.wethInfo.repayAmount = bound(info.wethInfo.repayAmount, 1, type(uint256).max);
    info.usdxInfo.repayAmount = bound(info.usdxInfo.repayAmount, 1, type(uint256).max);
    info.wbtcInfo.repayAmount = bound(info.wbtcInfo.repayAmount, 1, type(uint256).max);

    return info;
  }

  function getUserDebt(
    ISpoke spoke,
    address user,
    uint256 reserveId
  ) internal view returns (Debts memory data) {
    (data.baseDebt, data.premiumDebt) = spoke.getUserDebt(reserveId, user);
    data.totalDebt = data.baseDebt + data.premiumDebt;
  }

  // todo: merge with _assertUserDebt
  function assertEq(Debts memory a, Debts memory b) internal pure {
    assertEq(a.baseDebt, b.baseDebt, 'base debt');
    assertEq(a.premiumDebt, b.premiumDebt, 'premium debt');
    assertEq(a.totalDebt, b.totalDebt, 'total debt');
    assertEq(keccak256(abi.encode(a)), keccak256(abi.encode(b)), 'debt data'); // sanity
  }

  function assertEq(DynamicConfig memory a, DynamicConfig memory b) internal pure {
    assertEq(a.key, b.key, 'key');
    assertEq(a.enabled, b.enabled, 'enabled');
    assertEq(abi.encode(a), abi.encode(b)); // sanity
  }

  function _calculateExpectedUserRP(address user, ISpoke spoke) internal view returns (uint256) {
    uint256 assetId;
    uint256 totalDebt;
    uint256 suppliedReservesCount;
    uint256 userRP;
    DataTypes.UserPosition memory userPosition;

    // Find all reserves user has supplied, adding up total debt
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); ++reserveId) {
      if (spoke.isUsingAsCollateral(reserveId, user)) {
        ++suppliedReservesCount;
      }
      uint256 userDebt = spoke.getUserTotalDebt(reserveId, user);
      totalDebt += _getValueInBaseCurrency(spoke, reserveId, userDebt);
    }

    if (totalDebt == 0) {
      return 0;
    }

    // Gather up list of reserves as collateral to sort by collateral risk
    KeyValueListInMemory.List memory reserveCollateralRisk = KeyValueListInMemory.init(
      suppliedReservesCount
    );
    uint256 idx = 0;
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); reserveId++) {
      if (spoke.isUsingAsCollateral(reserveId, user)) {
        reserveCollateralRisk.add(idx, _getCollateralRisk(spoke, reserveId), reserveId);
        ++idx;
      }
    }

    // Sort supplied reserves by collateral risk
    reserveCollateralRisk.sortByKey();

    // While user's normalized debt amount is non-zero, iterate through supplied reserves, and add up collateral risk
    idx = 0;
    uint256 utilizedSupply = 0;
    while (totalDebt > 0 && idx < reserveCollateralRisk.length()) {
      (uint256 collateralRisk, uint256 reserveId) = reserveCollateralRisk.get(idx);
      userPosition = getUserInfo(spoke, user, reserveId);
      (assetId, ) = getAssetByReserveId(spoke, reserveId);
      uint256 suppliedAssets = hub.convertToSuppliedAssets(assetId, userPosition.suppliedShares);
      uint256 supplyAmount = _getValueInBaseCurrency(spoke, reserveId, suppliedAssets);

      if (supplyAmount >= totalDebt) {
        userRP += totalDebt * collateralRisk;
        utilizedSupply += totalDebt;
        totalDebt = 0;
        break;
      } else {
        userRP += supplyAmount * collateralRisk;
        utilizedSupply += supplyAmount;
        totalDebt -= supplyAmount;
      }

      ++idx;
    }

    return userRP / utilizedSupply;
  }

  function _getSpokeDynConfigKeys(ISpoke spoke) internal view returns (DynamicConfig[] memory) {
    uint256 reserveCount = spoke.getReserveCount();
    DynamicConfig[] memory configs = new DynamicConfig[](reserveCount);
    for (uint256 reserveId; reserveId < reserveCount; ++reserveId) {
      configs[reserveId] = DynamicConfig(spoke.getReserve(reserveId).dynamicConfigKey, true);
    }
    return configs;
  }

  // returns reserveId => User(DynamicConfigKey, usingAsCollateral) map.
  function _getUserDynConfigKeys(
    ISpoke spoke,
    address user
  ) internal view returns (DynamicConfig[] memory) {
    uint256 reserveCount = spoke.getReserveCount();
    DynamicConfig[] memory configs = new DynamicConfig[](reserveCount);
    for (uint256 reserveId; reserveId < reserveCount; ++reserveId) {
      configs[reserveId] = _getUserDynConfigKeys(spoke, user, reserveId);
    }
    return configs;
  }

  function _getUserDynConfig(
    ISpoke spoke,
    address user,
    uint256 reserveId
  ) internal view returns (DataTypes.DynamicReserveConfig memory) {
    return
      spoke.getDynamicReserveConfig(reserveId, spoke.getUserPosition(reserveId, user).configKey);
  }

  // deref and return current UserDynamicReserveConfig for a specific reserveId on user position.
  function _getUserDynConfigKeys(
    ISpoke spoke,
    address user,
    uint256 reserveId
  ) internal view returns (DynamicConfig memory) {
    DataTypes.UserPosition memory pos = spoke.getUserPosition(reserveId, user);
    return DynamicConfig(pos.configKey, spoke.isUsingAsCollateral(reserveId, user));
  }

  function assertEq(DynamicConfig[] memory a, DynamicConfig[] memory b) internal pure {
    require(a.length == b.length);
    for (uint256 i; i < a.length; ++i) {
      if (a[i].enabled && b[i].enabled) {
        assertEq(a[i].key, b[i].key, string.concat('reserve ', vm.toString(i)));
      }
    }
  }

  function assertNotEq(DynamicConfig[] memory a, DynamicConfig[] memory b) internal pure {
    require(a.length == b.length);
    for (uint256 i; i < a.length; ++i) {
      if (a[i].enabled && b[i].enabled) {
        assertNotEq(a[i].key, b[i].key, string.concat('reserve ', vm.toString(i)));
      }
    }
  }

  function _randomReserveId(ISpoke spoke) internal returns (uint256) {
    return vm.randomUint(0, spoke.getReserveCount() - 1);
  }

  function _randomConfigKey() internal returns (uint16) {
    return vm.randomUint(0, type(uint16).max).toUint16();
  }

  function _nextDynamicConfigKey(ISpoke spoke, uint256 reserveId) internal view returns (uint16) {
    uint16 dynamicConfigKey = spoke.getReserve(reserveId).dynamicConfigKey;
    return uint16(uint256(dynamicConfigKey + 1) % type(uint16).max);
  }

  function _randomUninitializedConfigKey(
    ISpoke spoke,
    uint256 reserveId
  ) internal returns (uint16) {
    uint16 configKey = _nextDynamicConfigKey(spoke, reserveId);
    if (spoke.getDynamicReserveConfig(reserveId, configKey).liquidationBonus != 0) {
      revert('no uninitialized config keys');
    }
    return vm.randomUint(configKey, type(uint16).max).toUint16();
  }

  function _randomInitializedConfigKey(ISpoke spoke, uint256 reserveId) internal returns (uint16) {
    uint16 configKey = _nextDynamicConfigKey(spoke, reserveId);
    if (spoke.getDynamicReserveConfig(reserveId, configKey).liquidationBonus != 0) {
      // all config keys are initialized
      return vm.randomUint(0, uint256(type(uint16).max)).toUint16();
    }
    return vm.randomUint(0, spoke.getReserve(reserveId).dynamicConfigKey).toUint16();
  }

  /// @dev Returns the id of the reserve corresponding to the given Liquidity Hub asset id
  function getReserveIdByAssetId(ISpoke spoke, uint256 assetId) internal view returns (uint256) {
    for (uint256 i; i < spoke.getReserveCount(); ++i) {
      if (assetId == spoke.getReserve(i).assetId) {
        return i;
      }
    }
    revert('not found');
  }
}
