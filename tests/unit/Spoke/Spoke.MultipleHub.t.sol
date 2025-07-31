// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeMultipleHubTest is SpokeBase {
  IHub internal hub2;
  IHub internal hub3;
  AssetInterestRateStrategy internal hub2IrStrategy;
  AssetInterestRateStrategy internal hub3IrStrategy;

  uint256 internal daiHub2ReserveId;
  uint256 internal daiHub3ReserveId;

  uint256 internal hub3DaiAssetId = 0;

  /* @dev Configures spoke1 to have 2 additional reserves:
   * dai from hub 2
   * dai from hub 3
   */
  function setUp() public virtual override {
    super.setUp();

    // Configure both hubs
    (hub2, hub2IrStrategy) = hub2Fixture();
    (hub3, hub3IrStrategy) = hub3Fixture();

    vm.startPrank(ADMIN);
    // Relist hub 2's dai on spoke1
    DataTypes.ReserveConfig memory daiHub2Config = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 20_00
    });
    DataTypes.DynamicReserveConfig memory dynDaiHub2Config = DataTypes.DynamicReserveConfig({
      collateralFactor: 78_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    daiHub2ReserveId = spoke1.addReserve(
      address(hub2),
      daiAssetId,
      _deployMockPriceFeed(spoke1, 1e8),
      daiHub2Config,
      dynDaiHub2Config
    );

    // Relist hub 3's dai on spoke 1
    DataTypes.ReserveConfig memory daiHub3Config = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 20_00
    });
    DataTypes.DynamicReserveConfig memory dynDaiHub3Config = DataTypes.DynamicReserveConfig({
      collateralFactor: 78_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    daiHub3ReserveId = spoke1.addReserve(
      address(hub3),
      hub3DaiAssetId,
      _deployMockPriceFeed(spoke1, 1e8),
      daiHub3Config,
      dynDaiHub3Config
    );

    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      active: true,
      addCap: type(uint256).max,
      drawCap: type(uint256).max
    });

    // Connect hub 2 and spoke 1 for dai
    hub2.addSpoke(daiAssetId, address(spoke1), spokeConfig);

    // Connect hub 3 and spoke 1 for dai
    hub3.addSpoke(hub3DaiAssetId, address(spoke1), spokeConfig);

    vm.stopPrank();

    // Deal dai to Alice for supplying to 2 hubs
    deal(address(tokenList.dai), alice, MAX_SUPPLY_AMOUNT * 2);

    // Approvals
    vm.startPrank(alice);
    tokenList.dai.approve(address(hub2), type(uint256).max);
    tokenList.dai.approve(address(hub3), type(uint256).max);

    vm.startPrank(bob);
    tokenList.dai.approve(address(hub2), type(uint256).max);
    tokenList.dai.approve(address(hub3), type(uint256).max);
    vm.stopPrank();
  }

  /// @dev Test showcasing dai may be borrowed from hub 2 and hub 1 via spoke 1
  function test_borrow_secondHub() public {
    uint256 hub1SupplyAmount = 100_000e18;
    uint256 hub1BorrowAmount = 10_000e18;
    uint256 hub2BorrowAmount = 30_000e18;
    uint256 hub1RepayAmount = 2_000e18;
    uint256 hub2RepayAmount = 5_000e18;

    // Bob supplies dai to spoke 1 on hub 1
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, hub1SupplyAmount, bob);
    assertEq(spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), bob), hub1SupplyAmount);
    assertEq(hub1.getAssetAddedAmount(daiAssetId), hub1SupplyAmount);

    // Bob borrows dai from spoke 1, hub 1
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, hub1BorrowAmount, bob);
    assertEq(spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob), hub1BorrowAmount);
    assertEq(hub1.getAssetTotalOwed(daiAssetId), hub1BorrowAmount);

    // Alice seeds liquidity for dai to hub 2 via spoke 1
    Utils.supply(spoke1, daiHub2ReserveId, alice, MAX_SUPPLY_AMOUNT, alice);

    // Bob can also borrow dai from hub 2 via spoke 1
    Utils.borrow(spoke1, daiHub2ReserveId, bob, hub2BorrowAmount, bob);
    assertEq(spoke1.getUserTotalDebt(daiHub2ReserveId, bob), hub2BorrowAmount);
    assertEq(hub2.getAssetTotalOwed(daiAssetId), hub2BorrowAmount);

    // Verify Dai is indeed the asset Bob is borrowing from both hubs
    DataTypes.Reserve memory daiReserve = spoke1.getReserve(_daiReserveId(spoke1));
    assertEq(daiReserve.underlying, address(tokenList.dai));
    daiReserve = spoke1.getReserve(daiHub2ReserveId);
    assertEq(daiReserve.underlying, address(tokenList.dai));

    // Bob can partially repay both debt positions on hub 1 and hub 2
    Utils.repay(spoke1, _daiReserveId(spoke1), bob, hub1RepayAmount, bob);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      hub1BorrowAmount - hub1RepayAmount
    );
    assertEq(hub1.getAssetTotalOwed(daiAssetId), hub1BorrowAmount - hub1RepayAmount);

    Utils.repay(spoke1, daiHub2ReserveId, bob, hub2RepayAmount, bob);
    assertEq(spoke1.getUserTotalDebt(daiHub2ReserveId, bob), hub2BorrowAmount - hub2RepayAmount);
    assertEq(hub2.getAssetTotalOwed(daiAssetId), hub2BorrowAmount - hub2RepayAmount);
  }

  /// @dev Test showcasing collateral on hub 3 can suffice for debt position on hub 1
  function test_borrow_thirdHub() public {
    uint256 hub1BorrowAmount = 50_000e18;
    uint256 hub3DaiBorrowAmount = 1e18;
    uint256 daiSupplyAmount = 100_000e18;

    // Bob supply to spoke 1 on hub 1
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, daiSupplyAmount, bob);
    assertEq(spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), bob), daiSupplyAmount);
    assertEq(hub1.getAssetAddedAmount(daiAssetId), daiSupplyAmount);

    // Alice seeds liquidity for dai to hub 1
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, MAX_SUPPLY_AMOUNT - daiSupplyAmount, alice);

    // Bob borrows dai from hub 1
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, hub1BorrowAmount, bob);
    assertEq(spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob), hub1BorrowAmount);
    assertEq(hub1.getAssetTotalOwed(daiAssetId), hub1BorrowAmount);

    // Alice seeds liquidity for dai to hub 3
    Utils.supply(spoke1, daiHub3ReserveId, alice, MAX_SUPPLY_AMOUNT - daiSupplyAmount, alice);

    // Bob supplies collateral to hub 3
    Utils.supplyCollateral(spoke1, daiHub3ReserveId, bob, daiSupplyAmount, bob);
    assertEq(spoke1.getUserSuppliedAmount(daiHub3ReserveId, bob), daiSupplyAmount);
    assertEq(hub3.getAssetAddedAmount(hub3DaiAssetId), MAX_SUPPLY_AMOUNT);

    // Since Bob has sufficient collateral on hub 3 to cover his debt position, he can withdraw from hub 1
    Utils.withdraw(spoke1, _daiReserveId(spoke1), bob, daiSupplyAmount, bob);
    assertEq(spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), bob), 0);
    assertEq(hub1.getAssetAddedAmount(daiAssetId), MAX_SUPPLY_AMOUNT - daiSupplyAmount);
  }
}
