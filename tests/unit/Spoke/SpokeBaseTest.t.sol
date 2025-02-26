// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {Spoke} from 'src/contracts/Spoke.sol';

contract SpokeBaseTest is BaseTest {
  struct TestData {
    Spoke.Reserve data;
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

  // increase share conversion index on borrowed asset
  /// @return supplyAmount of borrowed asset
  /// @return supplyShares of collateral asset
  function _increaseShareConversionIndex(
    TestReserve memory collateral,
    TestReserve memory borrow,
    uint256 rate
  ) internal returns (uint256, uint256) {
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    Spoke.Reserve memory collateralReserve = spoke1.getReserve(collateral.reserveId);
    Spoke.Reserve memory borrowReserve = spoke1.getReserve(borrow.reserveId);
    uint256 collateralSupplyShares = hub.convertToShares(
      collateralReserve.assetId,
      collateral.supplyAmount
    );
    uint256 borrowSupplyShares = hub.convertToShares(borrowReserve.assetId, borrow.supplyAmount);

    // supply collateral asset
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: collateral.reserveId,
      user: collateral.supplier,
      amount: collateral.supplyAmount,
      to: collateral.supplier
    });
    Utils.setUsingAsCollateral({
      spoke: spoke1,
      user: collateral.supplier,
      reserveId: collateral.reserveId,
      usingAsCollateral: true
    });

    // other user supplies enough asset to be drawn
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: borrow.reserveId,
      user: borrow.supplier,
      amount: borrow.supplyAmount,
      to: borrow.supplier
    });

    // borrower borrows asset
    Utils.borrow({
      spoke: spoke1,
      reserveId: borrow.reserveId,
      user: borrow.borrower,
      amount: borrow.borrowAmount,
      onBehalfOf: borrow.borrower
    });

    // skip time to increase index
    skip(365 days);

    return (collateralSupplyShares, borrowSupplyShares);
  }

  function _getReserveData(uint256 reserveId) internal view returns (TestData memory) {
    // only to check lastUpdateTimestamp
    Spoke.Reserve memory reserveStorageData = spoke1.getReserve(reserveId);
    TestData memory reserveData;
    (reserveData.data.baseDebt, reserveData.data.outstandingPremium) = spoke1.getReserveDebt(
      reserveId
    );
    reserveData.data.suppliedShares = spoke1.getReserveSuppliedShares(reserveId);
    reserveData.data.lastUpdateTimestamp = reserveStorageData.lastUpdateTimestamp;
    reserveData.data.riskPremium = spoke1.getReserveRiskPremium(reserveId);
    reserveData.suppliedAmount = spoke1.getReserveSuppliedAmount(reserveId);
    return reserveData;
  }

  function _getUserData(uint256 reserveId, address user) internal view returns (TestData memory) {
    // only to check lastUpdateTimestamp
    Spoke.UserConfig memory userStorageData = spoke1.getUser(reserveId, user);
    TestData memory userData;
    (userData.data.baseDebt, userData.data.outstandingPremium) = spoke1.getUserDebt(
      reserveId,
      user
    );
    userData.data.suppliedShares = spoke1.getUserSuppliedShares(reserveId, user);
    userData.data.lastUpdateTimestamp = userStorageData.lastUpdateTimestamp;
    userData.data.riskPremium = spoke1.getUserRiskPremium(user);
    userData.suppliedAmount = spoke1.getUserSuppliedAmount(reserveId, user);
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
