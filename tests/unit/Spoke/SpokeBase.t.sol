// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

contract SpokeBase is Base {
  struct TestData {
    DataTypes.Reserve data;
    uint256 suppliedAmount;
    uint256 cumulatedBaseInterest;
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

  // increase share conversion index on borrow asset
  // supply collateral asset, borrow asset, skip time to increase index
  /// @return supplyShares of collateral asset
  /// @return supplyShares of borrowed asset
  function _executeSupplyAndBorrow(
    Spoke spoke,
    TestReserve memory collateral,
    TestReserve memory borrow,
    uint256 rate,
    uint256 skipTime
  ) internal returns (uint256, uint256) {
    SupplyBorrowLocal memory state;

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    (state.collateralReserveAssetId, ) = _getAssetInfo(spoke, collateral.reserveId);
    (state.borrowReserveAssetId, ) = _getAssetInfo(spoke, borrow.reserveId);
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

  function _getReserveData(Spoke spoke, uint256 reserveId) internal view returns (TestData memory) {
    // only to check lastUpdateTimestamp
    DataTypes.Reserve memory reserveStorageData = spoke.getReserve(reserveId);
    TestData memory reserveData;
    (reserveData.data.baseDebt, reserveData.data.outstandingPremium) = spoke.getReserveDebt(
      reserveId
    );
    reserveData.data.suppliedShares = spoke.getReserveSuppliedShares(reserveId);
    reserveData.data.lastUpdateTimestamp = reserveStorageData.lastUpdateTimestamp;
    reserveData.data.riskPremium = spoke.getReserveRiskPremium(reserveId);
    reserveData.suppliedAmount = spoke.getReserveSuppliedAmount(reserveId);
    return reserveData;
  }

  function _getUserData(
    Spoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (TestData memory) {
    // only to check lastUpdateTimestamp
    DataTypes.UserPosition memory userStorageData = spoke.getUserPosition(reserveId, user);
    TestData memory userData;
    (userData.data.baseDebt, userData.data.outstandingPremium) = spoke.getUserDebt(reserveId, user);
    userData.data.suppliedShares = spoke.getUserSuppliedShares(reserveId, user);
    userData.data.lastUpdateTimestamp = userStorageData.lastUpdateTimestamp;
    userData.data.riskPremium = spoke.getUserRiskPremium(user);
    userData.suppliedAmount = spoke.getUserSuppliedAmount(reserveId, user);
    return userData;
  }

  function _getTokenBalances(IERC20 token, address spoke) internal view returns (TokenData memory) {
    TokenData memory tokenData;
    tokenData.spokeBalance = token.balanceOf(spoke);
    tokenData.hubBalance = token.balanceOf(address(hub));
    return tokenData;
  }
}
