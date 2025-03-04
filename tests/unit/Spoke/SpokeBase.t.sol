// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract SpokeBase is Base {
  using PercentageMath for uint256;

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
    collateral.reserveId = wethReserveId(spoke);
    collateral.supplyAmount = 1_000e18;
    collateral.supplier = alice;

    TestReserve memory borrow;
    borrow.reserveId = reserveId;
    borrow.supplier = bob;
    borrow.borrower = alice;
    borrow.supplyAmount = 100e18;
    borrow.borrowAmount = borrow.supplyAmount / 2;

    (state.borrowReserveAssetId, ) = getAssetInfo(spoke, borrow.reserveId);
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
      hub.convertToShares(state.borrowReserveAssetId, borrow.supplyAmount)
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

    (state.collateralReserveAssetId, ) = getAssetInfo(spoke, collateral.reserveId);
    (state.borrowReserveAssetId, ) = getAssetInfo(spoke, borrow.reserveId);
    state.collateralSupplyShares = hub.convertToShares(
      state.collateralReserveAssetId,
      collateral.supplyAmount
    );
    state.borrowSupplyShares = hub.convertToShares(state.borrowReserveAssetId, borrow.supplyAmount);

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

    return
      ((debtAmount * debtPrice * collAssetUnits) / (collPrice * debtAssetUnits)).percentDiv(
        collData.config.lt
      ) + 1;
  }
}
