// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import {KeyValueListInMemory} from 'src/libraries/helpers/KeyValueListInMemory.sol';

contract SpokeBase is Base {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using WadRayMathExtended for uint256;
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

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();
  }

  // supply MAX_SUPPLY_AMOUNT liquidity to reserve from a temporary user
  function _deployLiquidity(ISpoke spoke, uint256 reserveId, uint256 amount) public {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    uint256 initialLiq = hub.getAvailableLiquidity(assetId);

    address tempUser = makeAddr('tempUser');
    IERC20 asset = IERC20(spoke.getReserve(reserveId).asset);
    deal(address(asset), tempUser, amount);

    vm.prank(tempUser);
    asset.approve(address(hub), type(uint256).max);

    Utils.supply({
      spoke: spoke,
      reserveId: reserveId,
      user: tempUser,
      amount: amount,
      onBehalfOf: tempUser
    });

    assertEq(hub.getAvailableLiquidity(assetId), initialLiq + amount);
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
      vm.mockCall(
        address(irStrategy),
        IReserveInterestRateStrategy.calculateInterestRates.selector,
        abi.encode(rate)
      );
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
      user: collateral.supplier,
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
      user: borrow.supplier,
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
      user: borrow.borrower,
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
        deal(address(hub.assetsList(assetId)), user, debt);
        vm.prank(user);
        spoke.repay(reserveId, debt);
        assertEq(spoke.getUserTotalDebt(reserveId, user), 0, 'user debt not zero');
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
    TokenData memory tokenData;
    tokenData.spokeBalance = token.balanceOf(spoke);
    tokenData.hubBalance = token.balanceOf(address(hub));
    return tokenData;
  }

  function _calcMinimumCollAmount(
    ISpoke spoke,
    uint256 collReserveId,
    uint256 debtReserveId,
    uint256 debtAmount
  ) internal view returns (uint256) {
    DataTypes.Reserve memory collData = spoke.getReserve(collReserveId);
    uint256 collPrice = oracle.getAssetPrice(collData.assetId);
    uint256 collAssetUnits = 10 ** hub.getAsset(collData.assetId).config.decimals;

    DataTypes.Reserve memory debtData = spoke.getReserve(debtReserveId);
    uint256 debtAssetUnits = 10 ** hub.getAsset(debtData.assetId).config.decimals;
    uint256 debtPrice = oracle.getAssetPrice(debtData.assetId);

    uint256 normalizedDebtAmount = (debtAmount * debtPrice).wadify() / debtAssetUnits;
    uint256 normalizedCollPrice = collPrice.wadify() / collAssetUnits;

    return
      (normalizedDebtAmount.wadify() /
        normalizedCollPrice.wadify().percentMul(collData.config.collateralFactor)) + 1;
  }

  function _calcMaxDebtAmount(
    ISpoke spoke,
    uint256 collReserveId,
    uint256 debtReserveId,
    uint256 collAmount
  ) internal view returns (uint256) {
    DataTypes.Reserve memory collData = spoke.getReserve(collReserveId);
    uint256 collPrice = oracle.getAssetPrice(collData.assetId);
    uint256 collAssetUnits = 10 ** hub.getAsset(collData.assetId).config.decimals;

    DataTypes.Reserve memory debtData = spoke.getReserve(debtReserveId);
    uint256 debtAssetUnits = 10 ** hub.getAsset(debtData.assetId).config.decimals;
    uint256 debtPrice = oracle.getAssetPrice(debtData.assetId);

    uint256 normalizedDebtAmount = (debtPrice).wadify() / debtAssetUnits;
    uint256 normalizedCollPrice = (collAmount * collPrice).wadify() / collAssetUnits;

    uint256 maxDebt = (
      (normalizedCollPrice.wadify().percentMul(collData.config.collateralFactor) /
        normalizedDebtAmount.wadify())
    );

    return maxDebt > 1 ? maxDebt - 1 : maxDebt;
  }

  /// returns the USD value of the reserve normalized by it's decimals, in terms of WAD
  function _getValueInBaseCurrency(
    uint256 assetId,
    uint256 amount
  ) internal view returns (uint256) {
    return
      (amount * oracle.getAssetPrice(assetId).wadify()) /
      (10 ** hub.getAssetConfig(assetId).decimals);
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
    DebtData memory userDebt;
    userDebt.totalDebt = spoke.getUserTotalDebt(reserveId, user);
    (userDebt.baseDebt, userDebt.premiumDebt) = spoke.getUserDebt(reserveId, user);

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
    userPos.premiumDrawnShares = hub.convertToDrawnShares(assetId, debtAmount).percentMul(
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

  function _assertUserRpUnchanged(uint256 reserveId, ISpoke spoke, address user) internal view {
    DataTypes.UserPosition memory pos = spoke.getUserPosition(reserveId, user);
    uint256 riskPremiumStored = pos.premiumDrawnShares.percentDiv(pos.baseDrawnShares);
    (uint256 riskPremiumCurrent, , , , ) = spoke.getUserAccountData(user);
    assertEq(riskPremiumCurrent, riskPremiumStored, 'user risk premium mismatch');
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

  function assertEq(Debts memory a, Debts memory b) internal pure {
    assertEq(a.baseDebt, b.baseDebt, 'base debt');
    assertEq(a.premiumDebt, b.premiumDebt, 'premium debt');
    assertEq(a.totalDebt, b.totalDebt, 'total debt');
    assertEq(keccak256(abi.encode(a)), keccak256(abi.encode(b)), 'debt data'); // sanity
  }

  function _calculateExpectedUserRP(address user, ISpoke spoke) internal view returns (uint256) {
    uint256 assetId;
    uint256 totalDebt;
    uint256 suppliedReservesCount;
    uint256 userRP;
    DataTypes.UserPosition memory userPosition;

    // Find all reserves user has supplied, adding up total debt
    for (uint256 reserveId; reserveId < spoke.reserveCount(); ++reserveId) {
      if (spoke.getUsingAsCollateral(reserveId, user)) {
        ++suppliedReservesCount;
      }
      (assetId, ) = getAssetByReserveId(spoke, reserveId);
      totalDebt += _getValueInBaseCurrency(assetId, spoke.getUserTotalDebt(reserveId, user));
    }

    if (totalDebt == 0) {
      return 0;
    }

    // Gather up list of reserves as collateral to sort by LP
    KeyValueListInMemory.List memory reserveLP = KeyValueListInMemory.init(suppliedReservesCount);
    uint256 idx = 0;
    for (uint256 reserveId; reserveId < spoke.reserveCount(); reserveId++) {
      if (spoke.getUsingAsCollateral(reserveId, user)) {
        reserveLP.add(idx, spoke.getLiquidityPremium(reserveId), reserveId);
        ++idx;
      }
    }

    // Sort supplied reserves by LP
    reserveLP.sortByKey();

    // While user's normalized debt amount is non-zero, iterate through supplied reserves, and add up LP
    idx = 0;
    uint256 utilizedSupply = 0;
    while (totalDebt > 0 && idx < reserveLP.length()) {
      (uint256 lp, uint256 reserveId) = reserveLP.get(idx);
      userPosition = getUserInfo(spoke, user, reserveId);
      (assetId, ) = getAssetByReserveId(spoke, reserveId);
      uint256 supplyAmount = _getValueInBaseCurrency(
        assetId,
        hub.convertToSuppliedAssets(assetId, userPosition.suppliedShares)
      );

      if (supplyAmount >= totalDebt) {
        userRP += totalDebt * lp;
        utilizedSupply += totalDebt;
        totalDebt = 0;
        break;
      } else {
        userRP += supplyAmount * lp;
        utilizedSupply += supplyAmount;
        totalDebt -= supplyAmount;
      }

      ++idx;
    }

    return userRP / utilizedSupply;
  }
}
