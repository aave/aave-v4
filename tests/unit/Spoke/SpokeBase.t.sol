// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import {KeyValueListInMemory} from 'src/contracts/KeyValueListInMemory.sol';

contract SpokeBase is Base {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using KeyValueListInMemory for KeyValueListInMemory.List;

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

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();
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
    Utils.spokeSupply({
      spoke: spoke,
      reserveId: collateral.reserveId,
      user: collateral.supplier,
      amount: collateral.supplyAmount,
      onBehalfOf: collateral.supplier
    });
    setUsingAsCollateral({
      spoke: spoke,
      user: collateral.supplier,
      reserveId: collateral.reserveId,
      usingAsCollateral: true
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
    Utils.spokeSupply({
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
    Utils.spokeBorrow({
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

  /// @dev Returns the USD value of the reserve normalized by it's decimals, in terms of WAD
  function _getReserveValueInBaseCurrency(
    uint256 assetId,
    uint256 amount
  ) internal view returns (uint256) {
    return
      (amount * oracle.getAssetPrice(assetId) * WadRayMath.WAD) /
      (10 ** hub.getAssetConfig(assetId).decimals);
  }

  // TODO: DELETE THIS
  function _assertCalcDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 borrowAmount
  ) internal view {
    DataTypes.UserPosition memory calcDebt = _calcExpectedDebtAccounting(
      spoke,
      user,
      reserveId,
      borrowAmount
    );
    DataTypes.UserPosition memory userData = getUserInfo(spoke, user, reserveId);

    assertEq(userData.baseDrawnShares, calcDebt.baseDrawnShares, 'user baseDrawnShares');
    assertEq(userData.premiumDrawnShares, calcDebt.premiumDrawnShares, 'user premiumDrawnShares');
    assertEq(userData.premiumOffset, calcDebt.premiumOffset, 'user premiumOffset');
    assertEq(userData.realizedPremium, 0, 'user realized premium');

    uint256 assetId = spoke.getReserve(reserveId).assetId;
    uint256 expectedPremiumDebt = calcDebt.realizedPremium +
      (hub.convertToDrawnAssets(assetId, calcDebt.premiumDrawnShares) - calcDebt.premiumOffset);

    DebtData memory userDebt;
    userDebt.totalDebt = spoke.getUserTotalDebt(reserveId, user);
    (userDebt.baseDebt, userDebt.premiumDebt) = spoke.getUserDebt(reserveId, user);

    assertEq(
      userDebt.baseDebt,
      hub.convertToDrawnAssets(assetId, calcDebt.baseDrawnShares),
      'user base debt'
    );
    assertEq(userDebt.premiumDebt, expectedPremiumDebt, 'user premium debt');
    assertEq(userDebt.totalDebt, userDebt.baseDebt + userDebt.premiumDebt, 'user total debt');
  }

  function _assertUserDebtAndSuppliedShares(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 borrowAmount,
    uint256 suppliedAmount,
    string memory label
  ) internal view {
    DataTypes.UserPosition memory calcDebt = _calcExpectedDebtAccounting(
      spoke,
      user,
      reserveId,
      borrowAmount
    );
    DataTypes.UserPosition memory userData = getUserInfo(spoke, user, reserveId);

    assertEq(
      userData.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, suppliedAmount),
      string(abi.encodePacked('user supplied shares ', label))
    );
    assertEq(
      userData.baseDrawnShares,
      calcDebt.baseDrawnShares,
      string(abi.encodePacked('user baseDrawnShares ', label))
    );
    assertEq(
      userData.premiumDrawnShares,
      calcDebt.premiumDrawnShares,
      string(abi.encodePacked('user premiumDrawnShares ', label))
    );
    assertEq(
      userData.premiumOffset,
      calcDebt.premiumOffset,
      string(abi.encodePacked('user premiumOffset ', label))
    );
    assertEq(
      userData.realizedPremium,
      0,
      string(abi.encodePacked('user realized premium ', label))
    );

    uint256 assetId = spoke.getReserve(reserveId).assetId;
    uint256 expectedPremiumDebt = calcDebt.realizedPremium +
      (hub.convertToDrawnAssets(assetId, calcDebt.premiumDrawnShares) - calcDebt.premiumOffset);

    DebtData memory userDebt;
    userDebt.totalDebt = spoke.getUserTotalDebt(reserveId, user);
    (userDebt.baseDebt, userDebt.premiumDebt) = spoke.getUserDebt(reserveId, user);

    assertEq(
      userDebt.baseDebt,
      hub.convertToDrawnAssets(assetId, calcDebt.baseDrawnShares),
      string(abi.encodePacked('user base debt ', label))
    );
    assertEq(
      userDebt.premiumDebt,
      expectedPremiumDebt,
      string(abi.encodePacked('user premium debt ', label))
    );
    assertEq(
      userDebt.totalDebt,
      userDebt.baseDebt + userDebt.premiumDebt,
      string(abi.encodePacked('user total debt ', label))
    );
  }

  function _calcExpectedDebtAccounting(
    ISpoke spoke,
    address user,
    uint256 assetId,
    uint256 borrowAmount
  ) internal view returns (DataTypes.UserPosition memory userPos) {
    (uint256 riskPremium, , , , ) = spoke.getUserAccountData(user);

    userPos.baseDrawnShares = hub.convertToDrawnShares(assetId, borrowAmount);
    userPos.premiumDrawnShares = hub.convertToDrawnShares(assetId, borrowAmount).percentMul(
      riskPremium
    );
    userPos.premiumOffset = hub.convertToDrawnAssets(assetId, userPos.premiumDrawnShares);
  }

  /// assert that User storage debt matches Reserve storage debt
  function _assertUserAndReserveDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    string memory label
  ) internal view {
    DataTypes.UserPosition memory userData = getUserInfo(spoke, user, reserveId);

    DebtData memory reserveDebt;
    DebtData memory userDebt;
    uint256 assetId = spoke.getReserve(reserveId).assetId;

    reserveDebt.totalDebt = spoke.getReserveTotalDebt(reserveId);
    (reserveDebt.baseDebt, reserveDebt.premiumDebt) = spoke.getReserveDebt(reserveId);
    userDebt.totalDebt = spoke.getUserTotalDebt(reserveId, user);
    (userDebt.baseDebt, userDebt.premiumDebt) = spoke.getUserDebt(reserveId, user);
    assertEq(
      userDebt.baseDebt,
      hub.convertToDrawnAssets(assetId, userData.baseDrawnShares),
      string(abi.encodePacked('user base debt ', label))
    );
    assertEq(
      userDebt.premiumDebt,
      userData.realizedPremium +
        hub.convertToDrawnAssets(assetId, userData.premiumDrawnShares) -
        userData.premiumOffset,
      string(abi.encodePacked('user premium debt ', label))
    );
    assertEq(
      reserveDebt.baseDebt,
      userDebt.baseDebt,
      string(abi.encodePacked('reserve base debt ', label))
    );
    assertEq(
      reserveDebt.premiumDebt,
      userDebt.premiumDebt,
      string(abi.encodePacked('reserve premium debt ', label))
    );
    assertEq(
      reserveDebt.totalDebt,
      userDebt.totalDebt,
      string(abi.encodePacked('reservetotal debt ', label))
    );
  }

  /// assert that sum across User storage debt matches Reserve storage debt
  function _assertUsersAndReserveDebt(
    ISpoke spoke,
    uint256 reserveId,
    address[] memory users,
    string memory label
  ) internal view {
    DataTypes.UserPosition memory userData;
    //  = getUserInfo(spoke, user, reserveId);

    DebtData memory reserveDebt;
    DebtData memory userDebt;
    uint256 assetId = spoke.getReserve(reserveId).assetId;

    reserveDebt.totalDebt = spoke.getReserveTotalDebt(reserveId);
    (reserveDebt.baseDebt, reserveDebt.premiumDebt) = spoke.getReserveDebt(reserveId);

    for (uint256 i = 0; i < users.length; ++i) {
      userDebt.totalDebt += spoke.getUserTotalDebt(reserveId, users[i]);

      (uint256 baseDebt, uint256 premiumDebt) = spoke.getUserDebt(reserveId, users[i]);
      userDebt.baseDebt += baseDebt;
      userDebt.premiumDebt += premiumDebt;
    }

    assertEq(
      userDebt.baseDebt,
      hub.convertToDrawnAssets(assetId, userData.baseDrawnShares),
      string(abi.encodePacked('users base debt ', label))
    );
    assertEq(
      userDebt.premiumDebt,
      userData.realizedPremium +
        hub.convertToDrawnAssets(assetId, userData.premiumDrawnShares) -
        userData.premiumOffset,
      string(abi.encodePacked('users premium debt ', label))
    );
    assertEq(
      reserveDebt.baseDebt,
      userDebt.baseDebt,
      string(abi.encodePacked('reserve base debt ', label))
    );
    assertEq(
      reserveDebt.premiumDebt,
      userDebt.premiumDebt,
      string(abi.encodePacked('reserve premium debt ', label))
    );
    assertEq(
      reserveDebt.totalDebt,
      userDebt.totalDebt,
      string(abi.encodePacked('reservetotal debt ', label))
    );
  }

  // function _calculateExpectedUserRP(address user, ISpoke spoke) internal view returns (uint256) {
  //   uint256 assetId;
  //   uint256 totalDebt;
  //   uint256 suppliedReservesCount;
  //   uint256 userRP;
  //   DataTypes.UserPosition memory userPosition;

  //   // Find all reserves user has supplied, adding up total debt
  //   for (uint256 reserveId; reserveId < spoke.reserveCount(); ++reserveId) {
  //     if (spoke.getUsingAsCollateral(reserveId, user)) {
  //       ++suppliedReservesCount;
  //     }
  //     (assetId, ) = getAssetByReserveId(spoke, reserveId);
  //     totalDebt += _getReserveValueInBaseCurrency(
  //       assetId,
  //       spoke.getUserCumulativeDebt(reserveId, user)
  //     );
  //   }

  //   if (totalDebt == 0) {
  //     return 0;
  //   }

  //   // Gather up list of reserves as collateral to sort by LP
  //   KeyValueListInMemory.List memory reserveLP = KeyValueListInMemory.init(suppliedReservesCount);
  //   uint256 idx = 0;
  //   for (uint256 reserveId; reserveId < spoke.reserveCount(); ++reserveId) {
  //     if (spoke.getUsingAsCollateral(reserveId, user)) {
  //       reserveLP.add(idx, spoke.getLiquidityPremium(reserveId), reserveId);
  //       ++idx;
  //     }
  //   }

  //   // Sort supplied reserves by LP
  //   reserveLP.sortByKey();

  //   // While user's normalized debt amount is non-zero, iterate through supplied reserves, and add up LP
  //   idx = 0;
  //   uint256 originalTotalDebt = totalDebt;
  //   while (totalDebt > 0) {
  //     (uint256 lp, uint256 reserveId) = reserveLP.get(idx);
  //     userPosition = getUserInfo(spoke, user, reserveId);
  //     (assetId, ) = getAssetByReserveId(spoke, reserveId);
  //     uint256 supplyAmount = _getReserveValueInBaseCurrency(
  //       assetId,
  //       hub.convertToAssets(assetId, userPosition.suppliedShares)
  //     );

  //     if (supplyAmount >= totalDebt) {
  //       userRP += totalDebt * lp;
  //       break;
  //     } else {
  //       userRP += supplyAmount * lp;
  //       totalDebt -= supplyAmount;
  //     }

  //     ++idx;
  //   }

  //   return userRP / originalTotalDebt;
  // }
}
