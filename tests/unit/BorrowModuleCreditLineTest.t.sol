// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract BorrowModuleCreditLineTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function setUp() public override {
    super.setUp();

    // Add dai
    hub.addReserve(
      LiquidityHub.ReserveConfig({
        borrowModule: address(bm),
        decimals: 18,
        active: true,
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max,
        liquidityPremium: 10_00
      }),
      address(dai)
    );
    bm.addReserve(
      0,
      BorrowModule.ReserveConfig({lt: 0, lb: 0, rf: 0, borrowable: true}),
      address(dai)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(0, 1e8);

    // Add eth
    hub.addReserve(
      LiquidityHub.ReserveConfig({
        borrowModule: address(bm),
        decimals: 18,
        active: true,
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max,
        liquidityPremium: 0
      }),
      address(eth)
    );
    bm.addReserve(
      1,
      BorrowModule.ReserveConfig({lt: 0, lb: 0, rf: 0, borrowable: true}),
      address(eth)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(1, 2000e8);

    // Add dai again but with basic credit line borrow module
    uint256 daiCreditLineAssetId = 2;
    // flat 5% interest rate
    creditLineIRStrategy.setInterestRateParams(
      daiCreditLineAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 5000, // 50.00%
        baseVariableBorrowRate: 500, // 5.00%
        variableRateSlope1: 500, // 5.00%
        variableRateSlope2: 500 // 5.00%
      })
    );
    bmcl = new MockBorrowModuleCreditLine(address(hub), address(creditLineIRStrategy));
    hub.addReserve(
      LiquidityHub.ReserveConfig({
        borrowModule: address(bmcl),
        decimals: 18,
        active: true,
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max,
        liquidityPremium: 10_00
      }),
      address(dai)
    );
    bmcl.addReserve(
      daiCreditLineAssetId,
      MockBorrowModuleCreditLine.ReserveConfig({lt: 0, lb: 0, rf: 0, borrowable: true}),
      address(dai)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(daiCreditLineAssetId, 1e8);

    vm.warp(block.timestamp + 20);
  }

  function test_credit_line_config() public {
    uint256 daiId = 2;
    assertEq(bmcl.getInterestRate(daiId), 0.05e27);

    MockBorrowModuleCreditLine.UserConfig memory user = bmcl.getUser(daiId, USER1);

    assertEq(user.balance, 0);
    assertEq(user.lastUpdateIndex, 0);
    assertEq(user.lastUpdateTimestamp, 0);

    assertEq(bmcl.getUserDebt(daiId, USER1), 0);
    assertEq(bmcl.getReserveDebt(daiId), 0);
  }

  // test with basic borrow module
  // credit line with fixed interest rate
  function test_first_borrow_credit_line() public {
    // DAI with basic credit line borrow module
    uint256 daiId = 2;
    uint256 daiAmount = 100e18;

    uint256[] memory drawnAmounts = new uint256[](2);

    // User2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.supply(vm, hub, daiId, USER2, daiAmount, USER2);

    LiquidityHub.Reserve memory daiData0 = hub.getReserve(daiId);

    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(bmcl)), 0);

    drawnAmounts[0] = daiAmount / 2; // 50%
    drawnAmounts[1] = daiAmount / 4; // 25%

    // User1 draw half of dai reserve liquidity for borrow module
    vm.prank(USER1);
    vm.expectEmit(true, false, false, true, address(bmcl));
    emit Borrowed(daiId, USER1, drawnAmounts[0]);
    IBorrowModule(address(bmcl)).borrow(daiId, drawnAmounts[0]);

    LiquidityHub.Reserve memory daiData1 = hub.getReserve(daiId);

    assertEq(daiData1.totalShares, daiAmount, '1) wrong total shares');
    assertEq(daiData1.totalAssets, daiData0.totalAssets, '1) wrong total assets');
    assertEq(daiData1.totalDrawn, drawnAmounts[0], '1) wrong total drawn');
    assertEq(dai.balanceOf(USER1), drawnAmounts[0], '1) wrong dai balance');

    assertEq(bmcl.getReserveDebt(daiId), drawnAmounts[0], '1) wrong reserve debt');
    assertEq(bmcl.getUserDebt(daiId, USER1), drawnAmounts[0], '1) wrong user debt');
    assertEq(bmcl.getInterestRate(daiId), 0.05e27, '1) wrong IR'); // should be flat and constant

    MockBorrowModuleCreditLine.UserConfig memory user = bmcl.getUser(daiId, USER1);

    assertEq(user.balance, drawnAmounts[0], '1) wrong user balance');
    assertEq(user.lastUpdateIndex, 0, '1) wrong last update index');
    assertEq(user.lastUpdateTimestamp, block.timestamp, '1) wrong last update timestamp');

    // accumulate interest over the year
    skip(365 days);
    uint256 cumulated = MathUtils
      .calculateLinearInterest(
        IBorrowModule(address(bmcl)).getInterestRate(daiId),
        uint40(daiData1.lastUpdateTimestamp)
      )
      .rayMul(daiData1.totalDrawn);

    // User1 draw quarter of dai reserve liquidity for borrow module
    // to trigger interest accrual
    vm.prank(USER1);
    vm.expectEmit(true, false, false, true, address(bmcl));
    emit Borrowed(daiId, USER1, drawnAmounts[1]);
    IBorrowModule(address(bmcl)).borrow(daiId, drawnAmounts[1]);
    user = bmcl.getUser(daiId, USER1);

    // hub assertions
    LiquidityHub.Reserve memory daiData2 = hub.getReserve(daiId);

    assertEq(daiData2.totalShares, daiAmount, '2) wrong total shares');
    assertEq(
      daiData2.totalAssets,
      daiData0.totalAssets + (cumulated - daiData1.totalDrawn),
      '2) wrong total assets'
    );
    assertEq(daiData2.totalDrawn, cumulated + drawnAmounts[1], '2) wrong total drawn');
    assertEq(
      dai.balanceOf(USER1),
      drawnAmounts[0] + drawnAmounts[1],
      '2) wrong final user1 dai balance'
    );

    // borrow module assertions
    assertEq(bmcl.getReserveDebt(daiId), cumulated + drawnAmounts[1], '2) wrong reserve debt');
    assertEq(bmcl.getUserDebt(daiId, USER1), cumulated + drawnAmounts[1], '2) wrong user1 debt');
    assertEq(bmcl.getInterestRate(daiId), 0.05e27, '2) wrong IR'); // should be flat and constant

    // skip another year just for testing getUserDebt
    skip(365 days);

    uint256 userBalance = MathUtils
      .calculateLinearInterest(
        IBorrowModule(address(bmcl)).getInterestRate(daiId),
        uint40(user.lastUpdateTimestamp)
      )
      .rayMul(user.balance);
    assertEq(userBalance, bmcl.getUserDebt(daiId, USER1), '3) wrong final user1 debt');
  }

  function test_revert_borrow_reserve_not_borrowable() public {
    uint256 daiId = 2;
    uint256 drawnAmount = 1;
    _updateBorrowable(daiId, false);

    vm.prank(USER1);
    vm.expectRevert(TestErrors.RESERVE_NOT_BORROWABLE);
    IBorrowModule(address(bmcl)).borrow(daiId, drawnAmount);
  }

  function test_multi_borrow_credit_line() public {
    // DAI with basic credit line borrow module
    uint256 daiId = 2;
    uint256 daiAmount = 100e18;

    uint256[] memory drawnAmounts = new uint256[](3);

    // User2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.supply(vm, hub, daiId, USER2, daiAmount, USER2);

    LiquidityHub.Reserve memory daiData0 = hub.getReserve(daiId);

    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(daiData0.config.borrowModule), 0);

    drawnAmounts[0] = daiAmount / 2; // 50%
    drawnAmounts[1] = daiAmount / 4; // 25%
    drawnAmounts[2] = daiAmount / 5; // 20%

    // User1 draw half of dai reserve liquidity for borrow module
    vm.prank(USER1);
    IBorrowModule(daiData0.config.borrowModule).borrow(daiId, drawnAmounts[0]);

    LiquidityHub.Reserve memory daiData1 = hub.getReserve(daiId);

    MockBorrowModuleCreditLine.UserConfig memory user1 = bmcl.getUser(daiId, USER1);

    // accumulate interest over the year
    skip(365 days);
    uint256 cumulated = MathUtils
      .calculateLinearInterest(
        IBorrowModule(address(bmcl)).getInterestRate(daiId),
        uint40(daiData1.lastUpdateTimestamp)
      )
      .rayMul(daiData1.totalDrawn);

    // User1 draw 25% of dai reserve liquidity for borrow module
    vm.prank(USER1);
    IBorrowModule(address(bmcl)).borrow(daiId, drawnAmounts[1]);
    // User2 draw 20% of dai reserve liquidity for borrow module
    vm.prank(USER2);
    IBorrowModule(address(bmcl)).borrow(daiId, drawnAmounts[2]);

    user1 = bmcl.getUser(daiId, USER1);
    MockBorrowModuleCreditLine.UserConfig memory user2 = bmcl.getUser(daiId, USER2);

    // hub assertions
    LiquidityHub.Reserve memory daiData2 = hub.getReserve(daiId);

    assertEq(bmcl.getInterestRate(daiId), 0.05e27, '2) wrong IR'); // should be flat and constant
    assertEq(daiData2.totalShares, daiAmount, '2) wrong total shares');
    assertEq(
      daiData2.totalAssets,
      daiData0.totalAssets + (cumulated - daiData1.totalDrawn),
      '2) wrong total assets'
    );
    assertEq(
      daiData2.totalDrawn,
      cumulated + drawnAmounts[1] + drawnAmounts[2],
      '2) wrong total drawn'
    );
    assertEq(
      dai.balanceOf(USER1),
      drawnAmounts[0] + drawnAmounts[1],
      '2) wrong final user1 dai balance'
    );

    // borrow module assertions
    assertEq(
      bmcl.getReserveDebt(daiId),
      cumulated + drawnAmounts[1] + drawnAmounts[2],
      '2) wrong reserve debt'
    );
    assertEq(bmcl.getUserDebt(daiId, USER1), cumulated + drawnAmounts[1], '2) wrong user1 debt'); // only debt1 has accumulated interest
    assertEq(bmcl.getUserDebt(daiId, USER2), drawnAmounts[2], '2) wrong user2 debt'); // user2 debt1 has no interest yet

    skip(365 days);

    uint256 user1Balance = MathUtils
      .calculateLinearInterest(
        IBorrowModule(address(bmcl)).getInterestRate(daiId),
        uint40(user1.lastUpdateTimestamp)
      )
      .rayMul(user1.balance);
    assertEq(user1Balance, bmcl.getUserDebt(daiId, USER1), '3) wrong final user1 debt');

    uint256 user2Balance = MathUtils
      .calculateLinearInterest(
        IBorrowModule(address(bmcl)).getInterestRate(daiId),
        uint40(user2.lastUpdateTimestamp)
      )
      .rayMul(user2.balance);
    assertEq(user2Balance, bmcl.getUserDebt(daiId, USER2), '3) wrong final user2 debt');
    assertEq(
      bmcl.getReserveDebt(daiId),
      user1Balance + user2Balance,
      '3) wrong final reserve debt'
    );
  }

  function test_fuzz_multiple_draws_credit_line(uint256 numDrawings, uint256 entropy) public {
    numDrawings = bound(numDrawings, 1, 10);

    // DAI with basic credit line borrow module
    uint256 daiId = 2;
    uint256 daiAmount = 100e18;

    uint256[] memory drawnAmounts = new uint256[](numDrawings);
    LiquidityHub.Reserve[] memory daiData = new LiquidityHub.Reserve[](numDrawings);

    // User2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.supply(vm, hub, daiId, USER2, daiAmount, USER2);

    vm.startPrank(USER1);
    uint256 totalDrawn;
    for (uint256 i = 0; i < numDrawings; i++) {
      drawnAmounts[i] = daiAmount / _pseudoRandomNumber(entropy, numDrawings, numDrawings + 5); // divide by some amount > number of drawings, ensuring total drawn < total supplied assets
      totalDrawn += drawnAmounts[i];

      vm.mockCall(
        address(bmcl),
        abi.encodeWithSelector(IBorrowModule.getInterestRate.selector),
        abi.encode(_pseudoRandomNumber(entropy, 0, 100) * .01e27) // random interest rate 0-100%
      );

      // User1 draws some of dai reserve liquidity for borrow module
      IBorrowModule(address(bmcl)).borrow(daiId, drawnAmounts[i]);

      daiData[i] = hub.getReserve(daiId);
      (uint256 totalCumulated, uint256 cumulatedInterest) = _calculateLinearInterest(
        i == 0 ? daiData[0] : daiData[i - 1]
      );

      assertEq(
        daiData[i].totalShares,
        daiAmount,
        string(abi.encodePacked('wrong total shares: i=', vm.toString(i)))
      );
      assertEq(
        daiData[i].totalAssets,
        i == 0
          ? daiData[0].totalAssets + cumulatedInterest
          : daiData[i - 1].totalAssets + cumulatedInterest,
        string(abi.encodePacked('wrong total assets: i=', vm.toString(i)))
      );
      assertEq(
        daiData[i].totalDrawn,
        i == 0 ? totalCumulated : totalCumulated + drawnAmounts[i],
        string(abi.encodePacked('wrong total drawn: i=', vm.toString(i)))
      );
      assertEq(
        dai.balanceOf(USER1),
        totalDrawn,
        string(abi.encodePacked('wrong final dai balance: i=', vm.toString(i)))
      );

      skip(_pseudoRandomNumber(entropy, numDrawings, 500) * 1 days); // skip forward randomly some amount of days to let interest accrue
    }
    vm.stopPrank();
  }

  function test_revert_update_reserve() public {
    uint256 invalidReserveId = 3;

    MockBorrowModuleCreditLine.ReserveConfig memory reserveConfig;
    vm.expectRevert(TestErrors.INVALID_RESERVE);
    bmcl.updateReserve(invalidReserveId, reserveConfig);
  }

  function test_update_reserve() public {
    uint256 daiId = 2;

    MockBorrowModuleCreditLine.ReserveConfig memory reserveConfig;
    bmcl.updateReserve(daiId, reserveConfig);
  }

  // TODO: move to a helper
  function _calculateLinearInterest(
    LiquidityHub.Reserve memory reserveData
  ) internal view returns (uint256 totalCumulated, uint256 cumulatedInterest) {
    // accumulate interest over the year
    totalCumulated = MathUtils
      .calculateLinearInterest(
        IBorrowModule(reserveData.config.borrowModule).getInterestRate(reserveData.id),
        uint40(reserveData.lastUpdateTimestamp)
      )
      .rayMul(reserveData.totalDrawn);

    cumulatedInterest = totalCumulated - reserveData.totalDrawn;

    return (totalCumulated, cumulatedInterest);
  }

  // TODO: move to a general helper
  function _pseudoRandomNumber(
    uint256 entropy,
    uint256 min,
    uint256 max
  ) internal view returns (uint256) {
    return
      bound(
        uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, entropy))),
        min,
        max
      );
  }

  function _updateBorrowable(uint256 assetId, bool newBorrowable) internal {
    MockBorrowModuleCreditLine.ReserveConfig memory reserveConfig = bmcl.getReserve(assetId).config;
    reserveConfig.borrowable = newBorrowable;
    bmcl.updateReserve(assetId, reserveConfig);
  }
}
