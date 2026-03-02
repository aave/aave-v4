// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

contract HubPayFeeTest is HubBase {
  address internal constant TREASURY = address(0xBEEF);

  ITokenizationSpoke internal tokenSpoke;

  function setUp() public virtual override {
    super.setUp();

    // Deploy and register a tokenized spoke for daiAssetId so payFeeShares works
    tokenSpoke = _deployTokenizationSpoke(hub1, daiAssetId, 'TST', 'TST', ADMIN, TREASURY);
    vm.startPrank(ADMIN);
    hub1.addSpoke(
      daiAssetId,
      address(tokenSpoke),
      IHub.SpokeConfig({
        active: true,
        halted: false,
        addCap: type(uint40).max,
        drawCap: 0,
        riskPremiumThreshold: 0
      })
    );
    IHub.AssetConfig memory config = hub1.getAssetConfig(daiAssetId);
    config.tokenizedSpoke = address(tokenSpoke);
    hub1.updateAssetConfig(daiAssetId, config, new bytes(0));
    vm.stopPrank();
  }

  function test_payFee_revertsWith_InvalidShares() public {
    vm.expectRevert(IHub.InvalidShares.selector, address(hub1));
    vm.prank(address(spoke1));
    hub1.payFeeShares(daiAssetId, 0);
  }

  function test_payFee_revertsWith_SpokeNotActive() public {
    _updateSpokeActive(hub1, daiAssetId, address(spoke1), false);
    vm.expectRevert(IHub.SpokeNotActive.selector, address(hub1));
    vm.prank(address(spoke1));
    hub1.payFeeShares(daiAssetId, 1);
  }

  function test_payFee_revertsWith_underflow_added_shares_exceeded() public {
    uint256 addAmount = 100e18;
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: alice
    });

    uint256 feeShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));

    vm.expectRevert(stdError.arithmeticError);
    vm.prank(address(spoke1));
    hub1.payFeeShares(daiAssetId, feeShares + 1);
  }

  function test_payFee_revertsWith_underflow_added_shares_exceeded_with_interest() public {
    uint256 addAmount = 100e18;
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: alice
    });

    _addLiquidity(daiAssetId, addAmount);
    _drawLiquidity(daiAssetId, addAmount, true);

    uint256 feeShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 feeAmount = hub1.getSpokeAddedAssets(daiAssetId, address(spoke1));

    // supply ex rate increases due to interest
    assertGt(feeAmount, feeShares);

    vm.expectRevert(stdError.arithmeticError);
    vm.prank(address(spoke1));
    hub1.payFeeShares(daiAssetId, feeShares + 1);
  }

  function test_payFee_fuzz(uint256 addAmount, uint256 feeShares) public {
    test_payFee_fuzz_with_interest(addAmount, feeShares, 0);
  }

  function test_payFee_fuzz_with_interest(
    uint256 addAmount,
    uint256 feeShares,
    uint256 skipTime
  ) public {
    addAmount = bound(addAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: alice
    });

    _addLiquidity(daiAssetId, 100e18);
    _drawLiquidity(daiAssetId, 100e18, true);

    uint256 spokeSharesBefore = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));

    // supply ex rate increases due to interest
    assertGe(hub1.previewRemoveByShares(daiAssetId, WadRayMath.RAY), WadRayMath.RAY);

    feeShares = bound(feeShares, 1, spokeSharesBefore);

    uint256 tokenizedSpokeSharesBefore = hub1.getSpokeAddedShares(daiAssetId, address(tokenSpoke));
    uint256 treasuryBalanceBefore = tokenSpoke.balanceOf(TREASURY);

    vm.expectEmit(address(hub1));
    emit IHubBase.TransferShares(daiAssetId, address(spoke1), address(tokenSpoke), feeShares);

    vm.prank(address(spoke1));
    hub1.payFeeShares(daiAssetId, feeShares);

    _assertBorrowRateSynced(hub1, daiAssetId, 'payFee');
    _assertHubLiquidity(hub1, daiAssetId, 'payFee');
    uint256 spokeSharesAfter = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 tokenizedSpokeSharesAfter = hub1.getSpokeAddedShares(daiAssetId, address(tokenSpoke));

    assertEq(spokeSharesAfter, spokeSharesBefore - feeShares, 'spoke supplied shares after');
    assertEq(
      tokenizedSpokeSharesAfter,
      tokenizedSpokeSharesBefore + feeShares,
      'tokenized spoke supplied shares after'
    );
    // treasury should have received ERC20 shares via mintToTreasury
    assertEq(
      tokenSpoke.balanceOf(TREASURY),
      treasuryBalanceBefore + feeShares,
      'treasury erc20 balance after'
    );
  }
}
