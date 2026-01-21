// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';

abstract contract TokenizationSpokeMaxGettersReturnZeroTest is TokenizationSpokeBaseTest {
  ITokenizationSpoke public vault;

  function setUp() public virtual override {
    super.setUp();
    vault = daiVault;
    updateAddCap(IHub(vault.hub()), vault.assetId(), address(vault), 0);
  }

  function _isVaultActiveOrNotPaused() internal view returns (bool) {
    IHub.SpokeConfig memory config = IHub(vault.hub()).getSpokeConfig(
      vault.assetId(),
      address(vault)
    );
    return config.active && !config.paused;
  }

  modifier setUpPreconditions() {
    if (_isVaultActiveOrNotPaused()) {
      vm.expectCall(
        vault.hub(),
        abi.encodeCall(IHub.getSpokeConfig, (vault.assetId(), address(vault))),
        1
      );
    } else {
      vm.etch(vault.hub(), new bytes(0));
      vm.expectRevert();
    }
    _;
  }

  function test_maxDeposit_returns_zero() public setUpPreconditions {
    uint256 maxDeposit = vault.maxDeposit(vm.randomAddress());
    assertEq(maxDeposit, 0);
  }

  function test_maxMint_returns_zero() public setUpPreconditions {
    uint256 maxMint = vault.maxMint(vm.randomAddress());
    assertEq(maxMint, 0);
  }

  function test_maxWithdraw_returns_zero() public setUpPreconditions {
    uint256 maxWithdraw = vault.maxWithdraw(vm.randomAddress());
    assertEq(maxWithdraw, 0);
  }

  function test_maxRedeem_returns_zero() public setUpPreconditions {
    uint256 maxRedeem = vault.maxRedeem(vm.randomAddress());
    assertEq(maxRedeem, 0);
  }
}

contract TokenizationSpokeMaxGettersTest_Active_NotPaused is
  TokenizationSpokeMaxGettersReturnZeroTest
{}

contract TokenizationSpokeMaxGettersTest_Active_Paused is
  TokenizationSpokeMaxGettersReturnZeroTest
{
  function setUp() public override {
    super.setUp();
    updateSpokePaused(IHub(vault.hub()), vault.assetId(), address(vault), true);
  }
}

contract TokenizationSpokeMaxGettersTest_NotActive_NotPaused is
  TokenizationSpokeMaxGettersReturnZeroTest
{
  function setUp() public override {
    super.setUp();
    updateSpokeActive(IHub(vault.hub()), vault.assetId(), address(vault), false);
  }
}

contract TokenizationSpokeMaxGettersTest_NotActive_Paused is
  TokenizationSpokeMaxGettersReturnZeroTest
{
  function setUp() public override {
    super.setUp();
    updateSpokeActive(IHub(vault.hub()), vault.assetId(), address(vault), false);
    updateSpokePaused(IHub(vault.hub()), vault.assetId(), address(vault), true);
  }
}

// @dev vault spoke is active & not paused from here onwards

contract TokenizationSpokeDepositMintGettersMaxCapTest is TokenizationSpokeBaseTest {
  ITokenizationSpoke public vault;

  function setUp() public virtual override {
    super.setUp();
    vault = daiVault;

    assertEq(
      IHub(vault.hub()).getSpokeConfig(vault.assetId(), address(vault)).addCap,
      IHub(vault.hub()).MAX_ALLOWED_SPOKE_CAP()
    );
  }

  function maxSuppliableAssets() public view returns (uint256) {
    IHub hub = IHub(vault.hub());
    uint256 addCap = hub.getSpokeConfig(vault.assetId(), address(vault)).addCap;
    if (addCap == hub.MAX_ALLOWED_SPOKE_CAP()) {
      return type(uint256).max;
    }
    uint256 addCapWithDecimals = addCap * MathUtils.uncheckedExp(10, vault.decimals());
    uint256 balance = hub.getSpokeAddedAssets(vault.assetId(), address(vault));
    return addCapWithDecimals > balance ? addCapWithDecimals - balance : 0;
  }

  function test_maxDeposit() public {
    uint256 maxDeposit = vault.maxDeposit(vm.randomAddress());
    assertEq(maxDeposit, maxSuppliableAssets());
  }

  function test_maxMint() public {
    uint256 maxMint = vault.maxMint(vm.randomAddress());
    uint256 maxAssets = maxSuppliableAssets();
    uint256 maxSuppliableShares = maxAssets == type(uint256).max
      ? type(uint256).max
      : IHub(vault.hub()).previewAddByAssets(vault.assetId(), maxAssets);
    assertEq(maxMint, maxSuppliableShares);
  }
}

contract TokenizationSpokeDepositMintGettersEmptyLiquidityVariableCapTest is
  TokenizationSpokeDepositMintGettersMaxCapTest
{
  using SafeCast for uint256;

  function setUp() public virtual override {
    super.setUp();
    updateAddCap(
      IHub(vault.hub()),
      vault.assetId(),
      address(vault),
      vm.randomUint(1, vault.MAX_ALLOWED_SPOKE_CAP()).toUint40()
    );
  }
}

contract TokenizationSpokeDepositMintGettersNonEmptyLiquidityVariableCapTest is
  TokenizationSpokeDepositMintGettersEmptyLiquidityVariableCapTest
{
  using MathUtils for uint256;

  function setUp() public virtual override {
    super.setUp();
    uint256 amount = vm.randomUint(1, maxSuppliableAssets().min(MAX_SUPPLY_AMOUNT));
    deal(vault.asset(), address(this), amount);
    Utils.approve(vault, address(this), amount);
    vault.deposit(amount, address(this));
  }
}

contract TokenizationSpokeDepositMintGettersNonEmptyLiquidityMaxCapTest is
  TokenizationSpokeDepositMintGettersNonEmptyLiquidityVariableCapTest
{
  function setUp() public virtual override {
    super.setUp();
    updateAddCap(IHub(vault.hub()), vault.assetId(), address(vault), vault.MAX_ALLOWED_SPOKE_CAP());
  }
}

contract TokenizationSpokeWithdrawRedeemGettersReturnMaxTest is
  TokenizationSpokeDepositMintGettersNonEmptyLiquidityMaxCapTest
{
  using MathUtils for uint256;

  function setUp() public virtual override {
    super.setUp();
    deal(vault.asset(), address(this), MAX_SUPPLY_AMOUNT);
    Utils.approve(vault, address(this), MAX_SUPPLY_AMOUNT);
  }

  function availableAssets() public view returns (uint256) {
    return IHub(vault.hub()).getAssetLiquidity(vault.assetId());
  }

  function availableShares() public view returns (uint256) {
    return IHub(vault.hub()).previewAddByAssets(vault.assetId(), availableAssets());
  }

  function test_maxWithdraw() public {
    vault.deposit(vm.randomUint(0, MAX_SUPPLY_AMOUNT), address(this));
    uint256 balanceAmount = IHub(vault.hub()).previewRemoveByShares(
      vault.assetId(),
      vault.balanceOf(address(this))
    );

    uint256 maxWithdraw = vault.maxWithdraw(address(this));
    assertEq(maxWithdraw, availableAssets().min(balanceAmount));
  }

  function test_maxRedeem() public {
    vault.deposit(vm.randomUint(0, MAX_SUPPLY_AMOUNT), address(this));
    uint256 maxRedeemableShares = IHub(vault.hub()).previewRemoveByAssets(
      vault.assetId(),
      availableAssets().min(vault.balanceOf(address(this)))
    );

    uint256 maxRedeem = vault.maxRedeem(address(this));
    assertEq(maxRedeem, maxRedeemableShares);
  }
}
