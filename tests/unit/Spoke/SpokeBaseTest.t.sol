// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {Spoke} from 'src/contracts/Spoke.sol';

contract SpokeBaseTest is BaseTest {
  struct TestData {
    uint256 baseDebt;
    uint256 outstandingPremium;
    uint256 suppliedShares;
    uint256 suppliedAmount;
    uint256 lastUpdateTimestamp;
    uint256 cumulatedBaseInterest;
    uint256 riskPremium;
  }

  struct TokenData {
    uint256 spokeBalance;
    uint256 hubBalance;
  }

  struct CollateralReserve {
    uint256 reserveId;
    uint256 amount;
  }

  struct BorrowReserve {
    uint256 reserveId;
    uint256 amount;
    address supplier;
  }
  function setUp() public virtual override {
    super.setUp();
    initEnvironment();
  }

  // increase share conversion index on BorrowReserve asset
  // using CollateralReserve asset collateral
  // supplies BorrowReserve asset
  // borrower borrows half of supplied amount
  /// @return supplyAmount of BorrowReserve asset (2x of borrow amount)
  function _increaseShareConversionIndex(
    CollateralReserve memory collateral,
    BorrowReserve memory borrow,
    address borrower,
    uint256 rate
  ) internal returns (uint256, uint256) {
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    uint256 supplyAmount = borrow.amount * 2; // supply amount asset to be borrowed

    // borrower supplies collateral asset
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: collateral.reserveId,
      user: borrower,
      amount: collateral.amount,
      to: borrower
    });
    Utils.setUsingAsCollateral({
      spoke: spoke1,
      user: borrower,
      reserveId: collateral.reserveId,
      usingAsCollateral: true
    });

    Spoke.Reserve memory reserve = spoke1.getReserve(collateral.reserveId);
    uint256 supplyShares = hub.convertToShares(reserve.assetId, supplyAmount);
    // other user supplies enough asset to be drawn
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: borrow.reserveId,
      user: borrow.supplier,
      amount: supplyAmount,
      to: borrow.supplier
    });

    // console.log(
    //   'bob %e',
    //   spoke1.getUserSuppliedAmount(borrow.reserveId, bob),
    //   spoke1.getUserSuppliedShares(borrow.reserveId, bob)
    // );

    // borrower borrows asset
    Utils.borrow({
      spoke: spoke1,
      reserveId: borrow.reserveId,
      user: borrower,
      amount: borrow.amount,
      onBehalfOf: borrower
    });

    // skip time to increase index
    skip(365 days);

    return (supplyAmount, supplyShares);
  }

  function _getReserveData(uint256 reserveId) internal view returns (TestData memory) {
    // only to check lastUpdateTimestamp
    Spoke.Reserve memory reserveStorageData = spoke1.getReserve(reserveId);
    TestData memory reserveData;
    (reserveData.baseDebt, reserveData.outstandingPremium) = spoke1.getReserveDebt(reserveId);
    reserveData.suppliedShares = spoke1.getReserveSuppliedShares(reserveId);
    reserveData.suppliedAmount = spoke1.getReserveSuppliedAmount(reserveId);
    reserveData.lastUpdateTimestamp = reserveStorageData.lastUpdateTimestamp;
    reserveData.riskPremium = spoke1.getReserveRiskPremium(reserveId);
    return reserveData;
  }

  function _getUserData(uint256 reserveId, address user) internal view returns (TestData memory) {
    // only to check lastUpdateTimestamp
    Spoke.UserConfig memory userStorageData = spoke1.getUser(reserveId, user);
    TestData memory userData;
    (userData.baseDebt, userData.outstandingPremium) = spoke1.getUserDebt(reserveId, user);
    userData.suppliedShares = spoke1.getUserSuppliedShares(reserveId, user);
    userData.suppliedAmount = spoke1.getUserSuppliedAmount(reserveId, user);
    userData.lastUpdateTimestamp = userStorageData.lastUpdateTimestamp;
    userData.riskPremium = spoke1.getUserRiskPremium(reserveId, user);
    return userData;
  }

  function _getTokenBalances(
    address token,
    address spoke
  ) internal view returns (TokenData memory) {
    TokenData memory tokenData;
    tokenData.spokeBalance = tokenList.dai.balanceOf(spoke);
    tokenData.hubBalance = tokenList.dai.balanceOf(address(hub));
    return tokenData;
  }
}
