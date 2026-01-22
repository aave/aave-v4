// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';

// Coverage Matrix for maxDeposit/maxMint/maxWithdraw/maxRedeem:
// +---------------------------+----------------+----------------+----------------+----------------+
// | Scenario                  | maxDeposit     | maxMint        | maxWithdraw    | maxRedeem      |
// +---------------------------+----------------+----------------+----------------+----------------+
// | active=false              | 0              | 0              | 0              | 0              |
// | halted=true               | 0              | 0              | 0              | 0              |
// | active=false & halted=true| 0              | 0              | 0              | 0              |
// | addCap=0                  | 0              | 0              | n/a            | n/a            |
// | addCap=MAX                | type(uint).max | type(uint).max | n/a            | n/a            |
// | addCap=variable (empty)   | cap * units    | shares(cap)    | n/a            | n/a            |
// | addCap=variable (partial) | remaining      | shares(rem)    | n/a            | n/a            |
// | addCap exactly reached    | 0              | 0              | n/a            | n/a            |
// | addCap exceeded by yield  | 0              | 0              | n/a            | n/a            |
// | liquidity=0               | n/a            | n/a            | 0              | 0              |
// | liquidity < balance       | n/a            | n/a            | liquidity      | shares(liq)    |
// | liquidity >= balance      | n/a            | n/a            | balance        | shares(bal)    |
// | owner has 0 shares        | n/a            | n/a            | 0              | 0              |
// +---------------------------+----------------+----------------+----------------+----------------+
// n/a = scenario does not affect this getter

abstract contract TokenizationSpokeMaxGettersBaseTest is TokenizationSpokeBaseTest {
  ITokenizationSpoke public vault;
  TestnetERC20 public asset;

  function setUp() public virtual override {
    super.setUp();
    vault = daiVault;
    asset = TestnetERC20(vault.asset());
  }
}

abstract contract TokenizationSpokeMaxGettersAllZeroTest is TokenizationSpokeMaxGettersBaseTest {
  function test_maxDeposit_returnsZero() public view {
    assertEq(vault.maxDeposit(alice), 0);
  }

  function test_maxMint_returnsZero() public view {
    assertEq(vault.maxMint(alice), 0);
  }

  function test_maxWithdraw_returnsZero() public view {
    assertEq(vault.maxWithdraw(alice), 0);
  }

  function test_maxRedeem_returnsZero() public view {
    assertEq(vault.maxRedeem(alice), 0);
  }
}

contract TokenizationSpokeMaxGettersNotActiveTest is TokenizationSpokeMaxGettersAllZeroTest {
  function setUp() public override {
    super.setUp();
    _updateSpokeActive(IHub(vault.hub()), vault.assetId(), address(vault), false);
  }
}

contract TokenizationSpokeMaxGettersHaltedTest is TokenizationSpokeMaxGettersAllZeroTest {
  function setUp() public override {
    super.setUp();
    _updateSpokeHalted(IHub(vault.hub()), vault.assetId(), address(vault), true);
  }
}

contract TokenizationSpokeMaxGettersNotActiveAndHaltedTest is
  TokenizationSpokeMaxGettersAllZeroTest
{
  function setUp() public override {
    super.setUp();
    _updateSpokeActive(IHub(vault.hub()), vault.assetId(), address(vault), false);
    _updateSpokeHalted(IHub(vault.hub()), vault.assetId(), address(vault), true);
  }
}

contract TokenizationSpokeMaxGettersAddCapZeroTest is TokenizationSpokeMaxGettersBaseTest {
  function setUp() public override {
    super.setUp();
    _updateAddCap(IHub(vault.hub()), vault.assetId(), address(vault), 0);
  }

  function test_maxDeposit_returnsZero() public view {
    assertEq(vault.maxDeposit(alice), 0);
  }

  function test_maxMint_returnsZero() public view {
    assertEq(vault.maxMint(alice), 0);
  }
}

contract TokenizationSpokeMaxGettersAddCapMaxTest is TokenizationSpokeMaxGettersBaseTest {
  function setUp() public override {
    super.setUp();
    uint256 depositAmount = 10e18;
    asset.mint(alice, depositAmount);
    Utils.approve(vault, alice, depositAmount);
    vm.prank(alice);
    vault.deposit(depositAmount, alice);
  }

  function test_maxDeposit_returnsMaxUint() public view {
    assertEq(vault.maxDeposit(alice), type(uint256).max);
  }

  function test_maxMint_returnsMaxUint() public view {
    assertEq(vault.maxMint(alice), type(uint256).max);
  }
}

contract TokenizationSpokeMaxGettersAddCapVariableEmptyTest is TokenizationSpokeMaxGettersBaseTest {
  using SafeCast for uint256;

  uint40 public addCap;

  function setUp() public override {
    super.setUp();
    addCap = vm.randomUint(1, 1000).toUint40();
    _updateAddCap(IHub(vault.hub()), vault.assetId(), address(vault), addCap);
  }

  function test_maxDeposit_returnsCapTimesUnits() public view {
    uint256 expected = uint256(addCap) * MathUtils.uncheckedExp(10, vault.decimals());
    assertEq(vault.maxDeposit(alice), expected);
  }

  function test_maxMint_returnsSharesOfCap() public view {
    uint256 capAssets = uint256(addCap) * MathUtils.uncheckedExp(10, vault.decimals());
    uint256 expected = IHub(vault.hub()).previewAddByAssets(vault.assetId(), capAssets);
    assertEq(vault.maxMint(alice), expected);
  }
}

contract TokenizationSpokeMaxGettersAddCapVariablePartialTest is
  TokenizationSpokeMaxGettersBaseTest
{
  using SafeCast for uint256;

  uint40 public addCap;
  uint256 public depositAmount;

  function setUp() public override {
    super.setUp();
    addCap = vm.randomUint(100, 1000).toUint40();
    _updateAddCap(IHub(vault.hub()), vault.assetId(), address(vault), addCap);

    uint256 capWithDecimals = uint256(addCap) * MathUtils.uncheckedExp(10, vault.decimals());
    depositAmount = capWithDecimals / 2;
    asset.mint(alice, depositAmount);
    Utils.approve(vault, alice, depositAmount);
    vm.prank(alice);
    vault.deposit(depositAmount, alice);
  }

  function test_maxDeposit_returnsRemaining() public view {
    uint256 capWithDecimals = uint256(addCap) * MathUtils.uncheckedExp(10, vault.decimals());
    uint256 expected = capWithDecimals - vault.totalAssets();
    assertEq(vault.maxDeposit(alice), expected);
  }

  function test_maxMint_returnsSharesOfRemaining() public view {
    uint256 capWithDecimals = uint256(addCap) * MathUtils.uncheckedExp(10, vault.decimals());
    uint256 remaining = capWithDecimals - vault.totalAssets();
    uint256 expected = IHub(vault.hub()).previewAddByAssets(vault.assetId(), remaining);
    assertEq(vault.maxMint(alice), expected);
  }
}

contract TokenizationSpokeMaxGettersAddCapExactlyReachedTest is
  TokenizationSpokeMaxGettersBaseTest
{
  using SafeCast for uint256;

  uint40 public addCap;

  function setUp() public override {
    super.setUp();
    addCap = vm.randomUint(1, 1000).toUint40();
    _updateAddCap(IHub(vault.hub()), vault.assetId(), address(vault), addCap);

    uint256 capWithDecimals = uint256(addCap) * MathUtils.uncheckedExp(10, vault.decimals());
    asset.mint(alice, capWithDecimals);
    Utils.approve(vault, alice, capWithDecimals);
    vm.prank(alice);
    vault.deposit(capWithDecimals, alice);
  }

  function test_maxDeposit_returnsZero() public view {
    assertEq(vault.maxDeposit(alice), 0);
  }

  function test_maxMint_returnsZero() public view {
    assertEq(vault.maxMint(alice), 0);
  }
}

contract TokenizationSpokeMaxGettersCapExceededByYieldTest is TokenizationSpokeMaxGettersBaseTest {
  using SafeCast for uint256;

  uint40 public addCap;

  function setUp() public override {
    super.setUp();
    addCap = 10;
    _updateAddCap(IHub(vault.hub()), vault.assetId(), address(vault), addCap);

    uint256 capWithDecimals = uint256(addCap) * MathUtils.uncheckedExp(10, vault.decimals());
    asset.mint(alice, capWithDecimals);
    Utils.approve(vault, alice, capWithDecimals);
    vm.prank(alice);
    vault.deposit(capWithDecimals, alice);

    _simulateYield(vault, capWithDecimals);

    assertGt(vault.totalAssets(), capWithDecimals);
  }

  function test_maxDeposit_returnsZero() public view {
    assertEq(vault.maxDeposit(alice), 0);
  }

  function test_maxMint_returnsZero() public view {
    assertEq(vault.maxMint(alice), 0);
  }
}

contract TokenizationSpokeMaxGettersZeroLiquidityTest is TokenizationSpokeMaxGettersBaseTest {
  uint256 public depositAmount;

  function setUp() public override {
    super.setUp();
    depositAmount = 10e18;
    asset.mint(alice, depositAmount);
    Utils.approve(vault, alice, depositAmount);
    vm.prank(alice);
    vault.deposit(depositAmount, alice);

    // spoke2 needs to first add, then can draw
    asset.mint(address(IHub(vault.hub())), depositAmount);
    vm.startPrank(address(spoke2));
    IHub(vault.hub()).add(vault.assetId(), depositAmount);
    IHub(vault.hub()).draw(vault.assetId(), depositAmount * 2, address(spoke2));
    vm.stopPrank();

    assertEq(IHub(vault.hub()).getAssetLiquidity(vault.assetId()), 0);
  }

  function test_maxWithdraw_returnsZero() public view {
    assertEq(vault.maxWithdraw(alice), 0);
  }

  function test_maxRedeem_returnsZero() public view {
    assertEq(vault.maxRedeem(alice), 0);
  }
}

contract TokenizationSpokeMaxGettersLiquidityLessThanBalanceTest is
  TokenizationSpokeMaxGettersBaseTest
{
  using MathUtils for uint256;

  uint256 public depositAmount;

  function setUp() public override {
    super.setUp();
    depositAmount = 10e18;
    asset.mint(alice, depositAmount);
    Utils.approve(vault, alice, depositAmount);
    vm.prank(alice);
    vault.deposit(depositAmount, alice);

    _simulateYield(vault, depositAmount);

    uint256 drawnAmount = depositAmount / 2;
    asset.mint(address(IHub(vault.hub())), drawnAmount);
    vm.startPrank(address(spoke2));
    IHub(vault.hub()).add(vault.assetId(), drawnAmount);
    IHub(vault.hub()).draw(vault.assetId(), drawnAmount + depositAmount, address(spoke2));
    vm.stopPrank();
  }

  function test_maxWithdraw_returnsLiquidity() public view {
    uint256 liquidity = IHub(vault.hub()).getAssetLiquidity(vault.assetId());
    uint256 aliceBalance = vault.convertToAssets(vault.balanceOf(alice));
    assertLt(liquidity, aliceBalance);

    assertEq(vault.maxWithdraw(alice), liquidity);
  }

  function test_maxRedeem_returnsSharesOfLiquidity() public view {
    uint256 liquidity = IHub(vault.hub()).getAssetLiquidity(vault.assetId());
    uint256 liquidityShares = vault.convertToShares(liquidity);
    uint256 aliceShares = vault.balanceOf(alice);
    assertLt(liquidityShares, aliceShares);

    assertEq(vault.maxRedeem(alice), liquidityShares);
  }
}

contract TokenizationSpokeMaxGettersLiquidityGreaterThanBalanceTest is
  TokenizationSpokeMaxGettersBaseTest
{
  uint256 public depositAmount;

  function setUp() public override {
    super.setUp();
    depositAmount = 10e18;
    asset.mint(alice, depositAmount);
    Utils.approve(vault, alice, depositAmount);
    vm.prank(alice);
    vault.deposit(depositAmount, alice);

    uint256 extraLiquidity = 5e18;
    asset.mint(bob, extraLiquidity);
    Utils.approve(vault, bob, extraLiquidity);
    vm.prank(bob);
    vault.deposit(extraLiquidity, bob);
  }

  function test_maxWithdraw_returnsBalance() public view {
    uint256 liquidity = IHub(vault.hub()).getAssetLiquidity(vault.assetId());
    uint256 aliceBalance = vault.convertToAssets(vault.balanceOf(alice));
    assertGt(liquidity, aliceBalance);

    assertEq(vault.maxWithdraw(alice), aliceBalance);
  }

  function test_maxRedeem_returnsSharesOfBalance() public view {
    uint256 liquidity = IHub(vault.hub()).getAssetLiquidity(vault.assetId());
    uint256 aliceShares = vault.balanceOf(alice);
    uint256 liquidityShares = vault.convertToShares(liquidity);
    assertGt(liquidityShares, aliceShares);

    assertEq(vault.maxRedeem(alice), aliceShares);
  }
}

contract TokenizationSpokeMaxGettersOwnerZeroSharesTest is TokenizationSpokeMaxGettersBaseTest {
  function setUp() public override {
    super.setUp();
    uint256 depositAmount = 10e18;
    asset.mint(bob, depositAmount);
    Utils.approve(vault, bob, depositAmount);
    vm.prank(bob);
    vault.deposit(depositAmount, bob);

    assertEq(vault.balanceOf(alice), 0);
    assertGt(IHub(vault.hub()).getAssetLiquidity(vault.assetId()), 0);
  }

  function test_maxWithdraw_returnsZero() public view {
    assertEq(vault.maxWithdraw(alice), 0);
  }

  function test_maxRedeem_returnsZero() public view {
    assertEq(vault.maxRedeem(alice), 0);
  }
}
