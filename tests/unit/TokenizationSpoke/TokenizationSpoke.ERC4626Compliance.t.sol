// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';
import {ERC4626Test} from 'lib/erc4626-tests/ERC4626.test.sol';

contract TokenizationSpokeERC4626ComplianceTest is TokenizationSpokeBaseTest, ERC4626Test {
  function setUp() public override(TokenizationSpokeBaseTest, ERC4626Test) {
    TokenizationSpokeBaseTest.setUp();
    updateLiquidityFee(IHub(daiVault.hub()), daiVault.assetId(), 0);

    _underlying_ = daiVault.asset();
    _vault_ = address(daiVault);

    _delta_ = 0; // maximum approximation error size to be passed to assertApproxEqAbs, 0 implies the vault follows the preferred rounding directions as per spec security considerations
    _vaultMayBeEmpty = false; // fuzz inputs that empties the vault are considered; inflation protection is through virtual shares on hub
    _unlimitedAmount = false; // fuzz inputs are restricted to the currently available amount from the caller
  }

  function setUpYield(Init memory init) public override {
    if (init.yield > 0) {
      init.yield = bound(init.yield, 1, int256(MAX_SUPPLY_AMOUNT));
      _simulateYield(ITokenizationSpoke(_vault_), uint256(init.yield));
    }
  }

  // @dev The following tests are relaxed to consider only smaller values,
  // since they fail with large values (due to overflow).
  function test_asset(Init memory init) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    super.test_asset(init);
  }

  function test_totalAssets(Init memory init) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    super.test_totalAssets(init);
  }

  function test_convertToShares(Init memory init, uint assets) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    assets = assets % MAX_SUPPLY_AMOUNT;
    super.test_convertToShares(init, assets);
  }

  function test_convertToAssets(Init memory init, uint shares) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    shares = shares % MAX_SUPPLY_AMOUNT;
    super.test_convertToAssets(init, shares);
  }

  function test_maxDeposit(Init memory init) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    super.test_maxDeposit(init);
  }

  function test_previewDeposit(Init memory init, uint assets) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    assets = assets % MAX_SUPPLY_AMOUNT;
    super.test_previewDeposit(init, assets);
  }

  function test_deposit(Init memory init, uint assets, uint allowance) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    assets = assets % MAX_SUPPLY_AMOUNT;
    allowance = allowance % MAX_SUPPLY_AMOUNT;
    super.test_deposit(init, assets, allowance);
  }

  function test_maxMint(Init memory init) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    super.test_maxMint(init);
  }

  function test_previewMint(Init memory init, uint shares) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    shares = shares % MAX_SUPPLY_AMOUNT;
    super.test_previewMint(init, shares);
  }

  function test_mint(Init memory init, uint shares, uint allowance) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    shares = shares % MAX_SUPPLY_AMOUNT;
    allowance = allowance % MAX_SUPPLY_AMOUNT;
    super.test_mint(init, shares, allowance);
  }

  function test_maxWithdraw(Init memory init) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    super.test_maxWithdraw(init);
  }

  function test_previewWithdraw(Init memory init, uint assets) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    assets = assets % MAX_SUPPLY_AMOUNT;
    super.test_previewWithdraw(init, assets);
  }

  function test_maxRedeem(Init memory init) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    super.test_maxRedeem(init);
  }

  function test_previewRedeem(Init memory init, uint shares) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    shares = shares % MAX_SUPPLY_AMOUNT;
    super.test_previewRedeem(init, shares);
  }

  function test_RT_redeem_deposit(Init memory init, uint shares) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    shares = shares % MAX_SUPPLY_AMOUNT;
    super.test_RT_redeem_deposit(init, shares);
  }

  function test_RT_redeem_mint(Init memory init, uint shares) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    shares = shares % MAX_SUPPLY_AMOUNT;
    super.test_RT_redeem_mint(init, shares);
  }

  function test_RT_mint_withdraw(Init memory init, uint shares) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    shares = shares % MAX_SUPPLY_AMOUNT;
    super.test_RT_mint_withdraw(init, shares);
  }

  function test_RT_mint_redeem(Init memory init, uint shares) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    shares = shares % MAX_SUPPLY_AMOUNT;
    super.test_RT_mint_redeem(init, shares);
  }

  function test_RT_withdraw_mint(Init memory init, uint assets) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    assets = assets % MAX_SUPPLY_AMOUNT;
    super.test_RT_withdraw_mint(init, assets);
  }

  function test_RT_withdraw_deposit(Init memory init, uint assets) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    assets = assets % MAX_SUPPLY_AMOUNT;
    super.test_RT_withdraw_deposit(init, assets);
  }

  function test_RT_deposit_redeem(Init memory init, uint assets) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    assets = assets % MAX_SUPPLY_AMOUNT;
    super.test_RT_deposit_redeem(init, assets);
  }

  function test_RT_deposit_withdraw(Init memory init, uint assets) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    assets = assets % MAX_SUPPLY_AMOUNT;
    super.test_RT_deposit_withdraw(init, assets);
  }

  function test_withdraw(Init memory init, uint assets, uint allowance) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    assets = assets % MAX_SUPPLY_AMOUNT;
    allowance = allowance % MAX_SUPPLY_AMOUNT;
    super.test_withdraw(init, assets, allowance);
  }

  function test_withdraw_zero_allowance(Init memory init, uint assets) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    assets = assets % MAX_SUPPLY_AMOUNT;
    super.test_withdraw_zero_allowance(init, assets);
  }

  function test_redeem(Init memory init, uint shares, uint allowance) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    shares = shares % MAX_SUPPLY_AMOUNT;
    allowance = allowance % MAX_SUPPLY_AMOUNT;
    super.test_redeem(init, shares, allowance);
  }

  function test_redeem_zero_allowance(Init memory init, uint shares) public override {
    init = clamp(init, MAX_SUPPLY_AMOUNT);
    shares = shares % MAX_SUPPLY_AMOUNT;
    super.test_redeem_zero_allowance(init, shares);
  }

  function clamp(Init memory init, uint256 max) internal pure returns (Init memory) {
    for (uint256 i = 0; i < N; i++) {
      init.share[i] = init.share[i] % max;
      init.asset[i] = init.asset[i] % max;
    }
    init.yield = init.yield % int256(max);
    return init;
  }
}
