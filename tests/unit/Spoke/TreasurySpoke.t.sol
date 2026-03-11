// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract TreasurySpokeTest is SpokeBase {
  MockERC20 internal _testToken;
  IHub internal hub2;
  uint256 internal hub2DaiReserveId;

  function setUp() public virtual override {
    super.setUp();
    _testToken = new MockERC20();
    (hub2, ) = hub2Fixture();

    // Add a reserve on spoke1 for hub2
    vm.startPrank(ADMIN);
    ISpoke.ReserveConfig memory daiHub2Config = _getDefaultReserveConfig(20_00);
    ISpoke.DynamicReserveConfig memory dynDaiHub2Config = ISpoke.DynamicReserveConfig({
      collateralFactor: 78_00,
      maxLiquidationBonus: 100_00,
      liquidationFee: 0
    });

    hub2DaiReserveId = spoke1.addReserve(
      address(hub2),
      daiAssetId,
      _deployMockPriceFeed(spoke1, 1e8),
      daiHub2Config,
      dynDaiHub2Config
    );

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
    });

    hub2.addSpoke(daiAssetId, address(spoke1), spokeConfig);
    vm.stopPrank();

    // Approve dai for hub2
    vm.startPrank(alice);
    tokenList.dai.approve(address(hub2), type(uint256).max);
    vm.stopPrank();
  }

  function test_deploy_reverts_on_invalid_params() public {
    TreasurySpokeInstance impl = new TreasurySpokeInstance();
    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0))
    );
    DeployUtils.proxify(
      address(impl),
      ADMIN,
      abi.encodeCall(TreasurySpokeInstance.initialize, (address(0)))
    );
  }

  function test_initial_state() public view {
    for (uint256 i; i < hub1.getAssetCount(); ++i) {
      (address underlying, ) = hub1.getAssetUnderlyingAndDecimals(i);
      assertEq(treasurySpoke.getSuppliedAssets(address(hub1), underlying), 0);
      assertEq(treasurySpoke.getSuppliedShares(address(hub1), underlying), 0);
    }
    for (uint256 i; i < hub2.getAssetCount(); ++i) {
      (address underlying, ) = hub2.getAssetUnderlyingAndDecimals(i);
      assertEq(treasurySpoke.getSuppliedAssets(address(hub2), underlying), 0);
      assertEq(treasurySpoke.getSuppliedShares(address(hub2), underlying), 0);
    }
    assertEq(Ownable2Step(address(treasurySpoke)).owner(), TREASURY_ADMIN);
    assertEq(Ownable2Step(address(treasurySpoke)).pendingOwner(), address(0));
  }

  function test_supply_revertsWith_OwnableUnauthorizedAccount() public {
    address caller = vm.randomAddress();
    while (caller == TREASURY_ADMIN || caller == ADMIN) caller = vm.randomAddress();

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    treasurySpoke.supply(address(hub1), address(tokenList.dai), 1);
  }

  function test_supplySkimmed_revertsWith_OwnableUnauthorizedAccount() public {
    address caller = vm.randomAddress();
    while (caller == TREASURY_ADMIN || caller == ADMIN) caller = vm.randomAddress();

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    treasurySpoke.supplySkimmed(address(hub1), address(tokenList.dai), 1);
  }

  function test_supplySkimmed_revertsWith_InsufficientTransferred(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    uint256 transferAmount = vm.randomUint(0, amount - 1);

    vm.startPrank(TREASURY_ADMIN);
    if (transferAmount > 0) tokenList.dai.transfer(address(hub1), transferAmount);
    vm.expectRevert(
      abi.encodeWithSelector(IHub.InsufficientTransferred.selector, amount - transferAmount)
    );
    treasurySpoke.supplySkimmed(address(hub1), address(tokenList.dai), amount);
    vm.stopPrank();
  }

  function test_withdraw_revertsWith_OwnableUnauthorizedAccount() public {
    address caller = vm.randomAddress();
    while (caller == TREASURY_ADMIN || caller == ADMIN) caller = vm.randomAddress();

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    treasurySpoke.withdraw(address(hub1), address(tokenList.dai), 1);
  }

  function test_supply(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.supply(address(hub1), address(tokenList.dai), amount);

    assertEq(treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)), amount);
  }

  function test_supplySkimmed(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    vm.startPrank(TREASURY_ADMIN);
    tokenList.dai.transfer(address(hub1), amount);
    treasurySpoke.supplySkimmed(address(hub1), address(tokenList.dai), amount);
    vm.stopPrank();

    assertEq(treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)), amount);
  }

  /// treasury supplies to earn interest
  function test_withdraw_fuzz_amount_interestOnly(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateLiquidityFee(hub1, daiAssetId, 0);

    vm.prank(TREASURY_ADMIN);
    treasurySpoke.supply(address(hub1), address(tokenList.dai), amount);
    assertEq(treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)), amount);

    uint256 suppliedSharesBefore = treasurySpoke.getSuppliedShares(
      address(hub1),
      address(tokenList.dai)
    );
    uint256 suppliedAssetsBefore = treasurySpoke.getSuppliedAssets(
      address(hub1),
      address(tokenList.dai)
    );

    // create debt
    _openDebtPosition(spoke1, getReserveIdByAssetId(spoke1, hub1, daiAssetId), 100e18, true);

    skip(365 days);

    assertEq(
      suppliedSharesBefore,
      treasurySpoke.getSuppliedShares(address(hub1), address(tokenList.dai))
    );
    uint256 interest = treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)) -
      suppliedAssetsBefore;
    vm.assume(interest > 0); // assume only cases where the initial amount generates interest

    vm.prank(TREASURY_ADMIN);
    treasurySpoke.withdraw(address(hub1), address(tokenList.dai), amount + interest);
  }

  /// treasury does not supply but earn fees
  function test_withdraw_fuzz_amount_feesOnly(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    assertEq(treasurySpoke.getSuppliedShares(address(hub1), address(tokenList.dai)), 0);

    // create debt
    _openDebtPosition(spoke1, getReserveIdByAssetId(spoke1, hub1, daiAssetId), 100e18, true);

    skip(365 days);
    assertEq(hub1.getAsset(daiAssetId).realizedFees, 0, 'fees'); // fees not yet accrued

    uint256 expectedFeeAmount = _calcUnrealizedFees(hub1, daiAssetId);
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    assertEq(hub1.getAsset(daiAssetId).realizedFees, 0, 'realized fees after minting');
    assertGe(
      treasurySpoke.getSuppliedShares(address(hub1), address(tokenList.dai)),
      hub1.previewAddByAssets(daiAssetId, expectedFeeAmount)
    );

    vm.prank(TREASURY_ADMIN);
    treasurySpoke.withdraw(address(hub1), address(tokenList.dai), UINT256_MAX);
  }

  /// treasury supplies to earn interest and fees
  function test_withdraw_fuzz_amount_interestAndFees(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.prank(TREASURY_ADMIN);
    treasurySpoke.supply(address(hub1), address(tokenList.dai), amount);
    assertEq(treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)), amount);

    uint256 suppliedSharesBefore = treasurySpoke.getSuppliedShares(
      address(hub1),
      address(tokenList.dai)
    );
    uint256 suppliedAssetsBefore = treasurySpoke.getSuppliedAssets(
      address(hub1),
      address(tokenList.dai)
    );

    // create debt
    _openDebtPosition(spoke1, getReserveIdByAssetId(spoke1, hub1, daiAssetId), 100e18, true);

    skip(365 days);

    assertGe(
      treasurySpoke.getSuppliedShares(address(hub1), address(tokenList.dai)),
      suppliedSharesBefore
    );
    uint256 interestAndFees = treasurySpoke.getSuppliedAssets(
      address(hub1),
      address(tokenList.dai)
    ) - suppliedAssetsBefore;

    vm.prank(TREASURY_ADMIN);
    treasurySpoke.withdraw(address(hub1), address(tokenList.dai), amount + interestAndFees);
  }

  function test_transfer_revertsWith_OwnableUnauthorizedAccount() public {
    address caller = vm.randomAddress();
    while (caller == TREASURY_ADMIN || caller == ADMIN) caller = vm.randomAddress();

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    treasurySpoke.transfer(vm.randomAddress(), vm.randomAddress(), 1);
  }

  function test_transfer_revertsWith_ERC20InsufficientBalance(uint256 amount) public {
    vm.assume(amount > 0);
    address token = address(new MockERC20());

    vm.prank(TREASURY_ADMIN);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector,
        address(treasurySpoke),
        0,
        amount
      )
    );
    treasurySpoke.transfer(token, vm.randomAddress(), amount);
  }

  function test_transfer_fuzz(address recipient, uint256 amount, uint256 transferAmount) public {
    vm.assume(recipient != address(0));
    vm.assume(recipient != address(treasurySpoke));
    amount = bound(amount, 1, type(uint120).max);
    transferAmount = bound(transferAmount, 1, amount);

    _testToken.mint(address(treasurySpoke), amount);

    vm.expectEmit(address(_testToken));
    emit IERC20.Transfer(address(treasurySpoke), recipient, transferAmount);
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.transfer(address(_testToken), recipient, transferAmount);

    assertEq(_testToken.balanceOf(address(treasurySpoke)), amount - transferAmount);
    assertEq(_testToken.balanceOf(recipient), transferAmount);
  }

  function test_supply_multiHub_sameAsset(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / 2);

    // Supply to Hub 1 (DAI)
    vm.startPrank(TREASURY_ADMIN);
    treasurySpoke.supply(address(hub1), address(tokenList.dai), amount);

    // Supply to Hub 2 (DAI)
    treasurySpoke.supply(address(hub2), address(tokenList.dai), amount);
    vm.stopPrank();

    assertEq(treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)), amount);
    assertEq(treasurySpoke.getSuppliedAssets(address(hub2), address(tokenList.dai)), amount);
  }

  function test_supplySkimmed_multiHub_sameAsset(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / 2);

    // Supply to Hub 1 (DAI)
    vm.startPrank(TREASURY_ADMIN);
    tokenList.dai.transfer(address(hub1), amount);
    treasurySpoke.supplySkimmed(address(hub1), address(tokenList.dai), amount);

    // Supply to Hub 2 (DAI)
    tokenList.dai.transfer(address(hub2), amount);
    treasurySpoke.supplySkimmed(address(hub2), address(tokenList.dai), amount);
    vm.stopPrank();

    assertEq(treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)), amount);
    assertEq(treasurySpoke.getSuppliedAssets(address(hub2), address(tokenList.dai)), amount);
  }

  function test_withdraw_multiHub_sameAsset(uint256 amount) public {
    amount = bound(amount, 2, MAX_SUPPLY_AMOUNT / 2);

    // Supply first
    vm.startPrank(TREASURY_ADMIN);
    treasurySpoke.supply(address(hub1), address(tokenList.dai), amount);
    treasurySpoke.supply(address(hub2), address(tokenList.dai), amount);
    vm.stopPrank();

    // Withdraw from Hub 1
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.withdraw(address(hub1), address(tokenList.dai), amount / 2);

    assertEq(
      treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)),
      amount - amount / 2
    );
    assertEq(treasurySpoke.getSuppliedAssets(address(hub2), address(tokenList.dai)), amount);

    // Withdraw from Hub 2
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.withdraw(address(hub2), address(tokenList.dai), amount);

    assertEq(
      treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)),
      amount - amount / 2
    );
    assertEq(treasurySpoke.getSuppliedAssets(address(hub2), address(tokenList.dai)), 0);
  }

  function test_supply_multiHub_differentAsset(uint256 amount, uint256 amount2) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT);

    // Supply DAI to Hub 1
    vm.startPrank(TREASURY_ADMIN);
    treasurySpoke.supply(address(hub1), address(tokenList.dai), amount);

    // Supply USDX to Hub 2
    treasurySpoke.supply(address(hub2), address(tokenList.usdx), amount2);
    vm.stopPrank();

    assertEq(treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)), amount);
    assertEq(treasurySpoke.getSuppliedAssets(address(hub2), address(tokenList.usdx)), amount2);
  }

  function test_supplySkimmed_multiHub_differentAsset(uint256 amount, uint256 amount2) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT);

    // Supply DAI to Hub 1
    vm.startPrank(TREASURY_ADMIN);
    tokenList.dai.transfer(address(hub1), amount);
    treasurySpoke.supplySkimmed(address(hub1), address(tokenList.dai), amount);

    // Supply USDX to Hub 2
    tokenList.usdx.transfer(address(hub2), amount2);
    treasurySpoke.supplySkimmed(address(hub2), address(tokenList.usdx), amount2);
    vm.stopPrank();

    assertEq(treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)), amount);
    assertEq(treasurySpoke.getSuppliedAssets(address(hub2), address(tokenList.usdx)), amount2);
  }

  function test_withdraw_multiHub_differentAsset(uint256 amount, uint256 amount2) public {
    amount = bound(amount, 2, MAX_SUPPLY_AMOUNT);
    amount2 = bound(amount2, 2, MAX_SUPPLY_AMOUNT);

    // Supply first
    vm.startPrank(TREASURY_ADMIN);
    treasurySpoke.supply(address(hub1), address(tokenList.dai), amount);
    treasurySpoke.supply(address(hub2), address(tokenList.usdx), amount2);
    vm.stopPrank();

    // Withdraw DAI from Hub 1
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.withdraw(address(hub1), address(tokenList.dai), amount / 2);

    assertEq(
      treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)),
      amount - amount / 2
    );
    assertEq(treasurySpoke.getSuppliedAssets(address(hub2), address(tokenList.usdx)), amount2);

    // Withdraw USDX from Hub 2
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.withdraw(address(hub2), address(tokenList.usdx), amount2);

    assertEq(
      treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)),
      amount - amount / 2
    );
    assertEq(treasurySpoke.getSuppliedAssets(address(hub2), address(tokenList.usdx)), 0);
  }

  function test_withdraw_maxLiquidityFee() public {
    test_withdraw_fuzz_maxLiquidityFee(_daiReserveId(spoke1), 1000e18, 340 days);
  }

  function test_withdraw_fuzz_maxLiquidityFee(
    uint256 reserveId,
    uint256 amount,
    uint256 skipTime
  ) public {
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    // One of the reserves on spoke1 belongs to hub2, so get correct hub
    IHub hub = IHub(address(spoke1.getReserve(reserveId).hub));

    amount = bound(amount, 1, _calculateMaxSupplyAmount(spoke1, reserveId));
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    (address underlying, ) = hub.getAssetUnderlyingAndDecimals(assetId);
    updateLiquidityFee(hub, spoke1.getReserve(reserveId).assetId, 100_00);

    assertEq(treasurySpoke.getSuppliedShares(address(hub), underlying), 0);

    // create debt
    address tempUser = _openDebtPosition(spoke1, reserveId, amount, true);

    skip(skipTime);
    assertEq(hub.getAsset(assetId).realizedFees, 0, 'fees'); // fees not yet accrued

    uint256 expectedFeeAmount = _calcUnrealizedFees(hub, assetId);
    Utils.mintFeeShares(hub, assetId, ADMIN);
    uint256 fees = treasurySpoke.getSuppliedAssets(address(hub), underlying);

    assertEq(fees, expectedFeeAmount, 'supplied amount of fees');
    assertEq(hub.getAsset(assetId).realizedFees, 0, 'realized fees after minting');
    assertApproxEqAbs(
      hub.getSpokeAddedAssets(assetId, address(treasurySpoke)),
      hub.getAssetTotalOwed(assetId) - amount,
      3,
      'treasury spoke supplied amount on hub'
    );
    assertApproxEqAbs(
      fees,
      hub.getSpokeAddedAssets(assetId, address(treasurySpoke)),
      3,
      'treasury spoke supplied amount on spoke'
    );

    if (fees > 0) {
      IERC20 asset = getAssetUnderlyingByReserveId(spoke1, reserveId);
      uint256 balanceBefore = asset.balanceOf(TREASURY_ADMIN);

      deal(address(asset), tempUser, UINT256_MAX);
      Utils.repay(spoke1, reserveId, tempUser, UINT256_MAX, tempUser);
      vm.prank(TREASURY_ADMIN);
      treasurySpoke.withdraw(address(hub), underlying, fees);

      assertEq(balanceBefore + fees, asset.balanceOf(TREASURY_ADMIN), 'Treasury admin balance');
      assertEq(
        0,
        hub.getSpokeAddedAssets(assetId, address(treasurySpoke)),
        'treasury spoke remaining supplied amount'
      );
    }
  }

  function test_getters() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 assetId = daiAssetId;
    uint256 amount = 10_000e18;
    uint256 skipTime = 322 days;

    updateLiquidityFee(hub1, assetId, 100_00);
    updateLiquidityFee(hub2, assetId, 100_00);

    // create debt on both hubs via spoke1
    _openDebtPosition(spoke1, reserveId, amount, true);
    _openDebtPosition(spoke1, hub2DaiReserveId, amount, true);

    skip(skipTime);

    uint256 fees = treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai));
    uint256 hub2Fees = treasurySpoke.getSuppliedAssets(address(hub2), address(tokenList.dai));

    assertApproxEqAbs(
      treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)),
      fees,
      1,
      'reserve supplied assets'
    );
    assertApproxEqAbs(
      treasurySpoke.getSuppliedShares(address(hub1), address(tokenList.dai)),
      hub1.previewAddByAssets(assetId, fees),
      1,
      'reserve supplied shares'
    );

    assertApproxEqAbs(
      treasurySpoke.getSuppliedAssets(address(hub2), address(tokenList.dai)),
      hub2Fees,
      1,
      'hub2 reserve supplied assets'
    );
    assertApproxEqAbs(
      treasurySpoke.getSuppliedShares(address(hub2), address(tokenList.dai)),
      hub2.previewAddByAssets(assetId, hub2Fees),
      1,
      'hub2 reserve supplied shares'
    );
  }

  function _treasurySpoke() internal view returns (ISpoke) {
    return ISpoke(address(treasurySpoke));
  }
}
