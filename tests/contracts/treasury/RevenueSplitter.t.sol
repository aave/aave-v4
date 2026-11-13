// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract RevenueSplitterTest is Base {
  using PercentageMath for uint256;

  uint256 internal constant SPLIT_A = 30_00;
  uint256 internal constant SPLIT_B = 70_00;

  RevenueSplitter internal splitter;
  IHub internal hub2;
  address internal recipientA = makeAddr('recipientA');
  address internal recipientB = makeAddr('recipientB');

  function setUp() public virtual override {
    super.setUp();
    (hub2, ) = _hub2Fixture();

    splitter = _deploySplitter(_pair(recipientA, recipientB), _pair(SPLIT_A, SPLIT_B));
    vm.label(address(splitter), 'splitter');

    vm.prank(TREASURY_ADMIN);
    treasurySpoke.setClaimer(address(splitter));
  }

  function test_constructor() public view {
    assertEq(splitter.TREASURY_SPOKE(), address(treasurySpoke));
    (address[] memory recipients, uint256[] memory splits) = splitter.getRecipients();
    assertEq(recipients, _pair(recipientA, recipientB));
    assertEq(splits, _pair(SPLIT_A, SPLIT_B));
  }

  function test_constructor_fuzz(uint256 count) public {
    count = bound(count, 2, 50);
    (address[] memory recipients, uint256[] memory splits) = _randomRecipients(count);

    RevenueSplitter newSplitter = _deploySplitter(recipients, splits);

    (address[] memory storedRecipients, uint256[] memory storedSplits) = newSplitter
      .getRecipients();
    assertEq(storedRecipients, recipients);
    assertEq(storedSplits, splits);
  }

  function test_constructor_revertsWith_InvalidAddress_treasurySpoke() public {
    vm.expectRevert(IRevenueSplitter.InvalidAddress.selector);
    new RevenueSplitter(address(0), _pair(recipientA, recipientB), _pair(SPLIT_A, SPLIT_B));
  }

  function test_constructor_revertsWith_MismatchedLengths() public {
    vm.expectRevert(IRevenueSplitter.MismatchedLengths.selector);
    _deploySplitter(_pair(recipientA, recipientB), new uint256[](3));

    vm.expectRevert(IRevenueSplitter.MismatchedLengths.selector);
    _deploySplitter(new address[](3), _pair(SPLIT_A, SPLIT_B));
  }

  function test_constructor_revertsWith_InvalidRecipientsCount() public {
    vm.expectRevert(IRevenueSplitter.InvalidRecipientsCount.selector);
    _deploySplitter(new address[](0), new uint256[](0));

    address[] memory recipients = new address[](1);
    recipients[0] = recipientA;
    uint256[] memory splits = new uint256[](1);
    splits[0] = PercentageMath.PERCENTAGE_FACTOR;
    vm.expectRevert(IRevenueSplitter.InvalidRecipientsCount.selector);
    _deploySplitter(recipients, splits);
  }

  function test_constructor_fuzz_revertsWith_InvalidAddress_recipient(
    uint256 count,
    uint256 index
  ) public {
    count = bound(count, 2, 20);
    index = bound(index, 0, count - 1);
    (address[] memory recipients, uint256[] memory splits) = _randomRecipients(count);
    recipients[index] = address(0);

    vm.expectRevert(IRevenueSplitter.InvalidAddress.selector);
    _deploySplitter(recipients, splits);
  }

  function test_constructor_fuzz_revertsWith_DuplicateRecipient(
    uint256 count,
    uint256 index,
    uint256 duplicateIndex
  ) public {
    count = bound(count, 2, 20);
    index = bound(index, 0, count - 1);
    duplicateIndex = bound(duplicateIndex, 0, count - 1);
    vm.assume(index != duplicateIndex);
    (address[] memory recipients, uint256[] memory splits) = _randomRecipients(count);
    recipients[duplicateIndex] = recipients[index];

    vm.expectRevert(IRevenueSplitter.DuplicateRecipient.selector);
    _deploySplitter(recipients, splits);
  }

  function test_constructor_revertsWith_InvalidSplit_zero() public {
    vm.expectRevert(IRevenueSplitter.InvalidSplit.selector);
    _deploySplitter(_pair(recipientA, recipientB), _pair(0, PercentageMath.PERCENTAGE_FACTOR));

    vm.expectRevert(IRevenueSplitter.InvalidSplit.selector);
    _deploySplitter(_pair(recipientA, recipientB), _pair(PercentageMath.PERCENTAGE_FACTOR, 0));
  }

  function test_constructor_fuzz_revertsWith_InvalidSplit_aboveFactor(uint256 split) public {
    split = bound(split, PercentageMath.PERCENTAGE_FACTOR, UINT256_MAX);

    vm.expectRevert(IRevenueSplitter.InvalidSplit.selector);
    _deploySplitter(_pair(recipientA, recipientB), _pair(split, 1));

    vm.expectRevert(IRevenueSplitter.InvalidSplit.selector);
    _deploySplitter(_pair(recipientA, recipientB), _pair(1, split));
  }

  function test_constructor_fuzz_revertsWith_InvalidSplit_sum(
    uint256 splitA,
    uint256 splitB
  ) public {
    splitA = bound(splitA, 1, PercentageMath.PERCENTAGE_FACTOR - 1);
    splitB = bound(splitB, 1, PercentageMath.PERCENTAGE_FACTOR - 1);
    vm.assume(splitA + splitB != PercentageMath.PERCENTAGE_FACTOR);

    vm.expectRevert(IRevenueSplitter.InvalidSplit.selector);
    _deploySplitter(_pair(recipientA, recipientB), _pair(splitA, splitB));
  }

  function test_splitRevenue_revertsWith_MismatchedLengths() public {
    vm.expectRevert(IRevenueSplitter.MismatchedLengths.selector);
    splitter.splitRevenue(new address[](1), new address[](2));
  }

  function test_splitRevenue_emptyArrays() public {
    vm.recordLogs();
    splitter.splitRevenue(new address[](0), new address[](0));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_splitRevenue_revertsWith_OwnableUnauthorizedAccount_notClaimer() public {
    _treasurySupply(hub1, address(tokenList.dai), 100e18);
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.setClaimer(address(0));

    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(splitter))
    );
    splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));
  }

  function test_splitRevenue_revertsWith_AssetNotListed() public {
    address token = address(new MockERC20());

    vm.expectRevert(IHub.AssetNotListed.selector);
    splitter.splitRevenue(_pair(address(hub1)), _pair(token));
  }

  function test_splitRevenue_revertsWith_SpokeHalted() public {
    _treasurySupply(hub1, address(tokenList.dai), 100e18);
    _updateSpokeHalted(hub1, daiAssetId, address(treasurySpoke), true);

    vm.expectRevert(IHub.SpokeHalted.selector);
    splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));
  }

  function test_splitRevenue_revertsWith_SpokeNotActive() public {
    _treasurySupply(hub1, address(tokenList.dai), 100e18);
    _updateSpokeActive(hub1, daiAssetId, address(treasurySpoke), false);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));
  }

  function test_splitRevenue_revertsWith_ReentrancyGuardReentrantCall_hubRemove() public {
    _treasurySupply(hub1, address(tokenList.dai), 100e18);
    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(splitter),
      IRevenueSplitter.splitRevenue.selector
    );
    vm.mockFunction(
      address(hub1),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.remove.selector)
    );

    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));
  }

  function test_splitRevenue_revertsWith_ReentrancyGuardReentrantCall_tokenTransfer() public {
    deal(address(tokenList.dai), address(splitter), 100e18);
    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(splitter),
      IRevenueSplitter.splitRevenue.selector
    );
    vm.mockFunction(
      address(tokenList.dai),
      address(reentrantCaller),
      abi.encodeWithSelector(IERC20.transfer.selector)
    );

    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));
  }

  function test_splitRevenue_noRevenue() public {
    vm.expectCall(
      address(treasurySpoke),
      abi.encodeWithSelector(ITreasurySpoke.withdraw.selector),
      0
    );
    vm.recordLogs();
    splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));

    assertEq(vm.getRecordedLogs().length, 0);
    assertEq(tokenList.dai.balanceOf(recipientA), 0);
    assertEq(tokenList.dai.balanceOf(recipientB), 0);
  }

  function test_splitRevenue_fuzz_permissionless(address caller) public {
    uint256 amount = 100e18;
    _treasurySupply(hub1, address(tokenList.dai), amount);

    vm.prank(caller);
    splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));

    _assertSplit(tokenList.dai, amount);
  }

  function test_splitRevenue_fuzz_suppliedAssets(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    _treasurySupply(hub1, address(tokenList.dai), amount);

    vm.expectEmit(address(splitter));
    emit IRevenueSplitter.SplitRevenue(address(hub1), address(tokenList.dai), amount);
    splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));

    _assertSplit(tokenList.dai, amount);
    assertEq(treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)), 0);
    assertEq(tokenList.dai.balanceOf(address(splitter)), 0);
  }

  function test_splitRevenue_fuzz_fees(uint256 borrowAmount, uint256 skipTime) public {
    borrowAmount = bound(borrowAmount, 1e18, 1_000_000e18);
    skipTime = bound(skipTime, 1 days, MAX_SKIP_TIME);
    _updateLiquidityFee(hub1, daiAssetId, 50_00);

    _openDebtPosition(spoke1, _daiReserveId(spoke1), borrowAmount, true);
    skip(skipTime);
    HubActions.mintFeeShares({hub: hub1, assetId: daiAssetId, caller: ADMIN});

    uint256 fees = treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai));
    vm.assume(fees > 0);
    uint256 expectedWithdrawn = MathUtils.min(fees, hub1.getAssetLiquidity(daiAssetId));
    uint256 expectedShares = treasurySpoke.getSuppliedShares(
      address(hub1),
      address(tokenList.dai)
    ) - hub1.previewRemoveByAssets(daiAssetId, expectedWithdrawn);

    splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));

    _assertSplit(tokenList.dai, expectedWithdrawn);
    assertEq(
      treasurySpoke.getSuppliedShares(address(hub1), address(tokenList.dai)),
      expectedShares
    );
    assertEq(tokenList.dai.balanceOf(address(splitter)), 0);
  }

  function test_splitRevenue_repeated_accumulates() public {
    _updateLiquidityFee(hub1, daiAssetId, 50_00);
    _openDebtPosition(spoke1, _daiReserveId(spoke1), 100_000e18, true);

    uint256 totalFees;
    for (uint256 i; i < 3; ++i) {
      skip(90 days);
      HubActions.mintFeeShares({hub: hub1, assetId: daiAssetId, caller: ADMIN});
      uint256 fees = treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai));
      assertGt(fees, 0);

      uint256 balanceA = tokenList.dai.balanceOf(recipientA);
      uint256 balanceB = tokenList.dai.balanceOf(recipientB);
      splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));

      uint256 expectedA = fees.percentMulDown(SPLIT_A);
      assertEq(tokenList.dai.balanceOf(recipientA), balanceA + expectedA, 'recipientA');
      assertEq(tokenList.dai.balanceOf(recipientB), balanceB + fees - expectedA, 'recipientB');
      totalFees += fees;
    }

    assertEq(tokenList.dai.balanceOf(recipientA) + tokenList.dai.balanceOf(recipientB), totalFees);
  }

  function test_splitRevenue_fuzz_clampedToLiquidity(uint256 amount, uint256 drawAmount) public {
    amount = bound(amount, 2, MAX_SUPPLY_AMOUNT);
    _treasurySupply(hub1, address(tokenList.dai), amount);

    uint256 liquidity = hub1.getAssetLiquidity(daiAssetId);
    drawAmount = bound(drawAmount, 1, liquidity - 1);
    _drawLiquidityViaTempSpoke(hub1, daiAssetId, drawAmount, false, false);

    uint256 supplied = treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai));
    uint256 remainingLiquidity = hub1.getAssetLiquidity(daiAssetId);
    uint256 expectedWithdrawn = MathUtils.min(supplied, remainingLiquidity);
    uint256 expectedShares = treasurySpoke.getSuppliedShares(
      address(hub1),
      address(tokenList.dai)
    ) - hub1.previewRemoveByAssets(daiAssetId, expectedWithdrawn);

    splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));

    _assertSplit(tokenList.dai, expectedWithdrawn);
    assertEq(hub1.getAssetLiquidity(daiAssetId), remainingLiquidity - expectedWithdrawn);
    assertEq(
      treasurySpoke.getSuppliedShares(address(hub1), address(tokenList.dai)),
      expectedShares
    );
  }

  function test_splitRevenue_zeroLiquidity_distributesBalance() public {
    uint256 amount = 100e18;
    _treasurySupply(hub1, address(tokenList.dai), amount);
    _drawLiquidityViaTempSpoke(hub1, daiAssetId, hub1.getAssetLiquidity(daiAssetId), false, false);
    assertEq(hub1.getAssetLiquidity(daiAssetId), 0);

    uint256 balance = 1e18;
    deal(address(tokenList.dai), address(splitter), balance);

    vm.expectCall(
      address(treasurySpoke),
      abi.encodeWithSelector(ITreasurySpoke.withdraw.selector),
      0
    );
    splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));

    _assertSplit(tokenList.dai, balance);
    assertEq(treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)), amount);
  }

  function test_splitRevenue_fuzz_includesDirectTransfers(uint256 amount, uint256 balance) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    balance = bound(balance, 1, MAX_SUPPLY_AMOUNT);
    _treasurySupply(hub1, address(tokenList.dai), amount);
    deal(address(tokenList.dai), address(splitter), balance);

    vm.expectEmit(address(splitter));
    emit IRevenueSplitter.SplitRevenue(address(hub1), address(tokenList.dai), amount + balance);
    splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));

    _assertSplit(tokenList.dai, amount + balance);
    assertEq(tokenList.dai.balanceOf(address(splitter)), 0);
  }

  function test_splitRevenue_dust() public {
    deal(address(tokenList.dai), address(splitter), 1);

    vm.expectCall(address(tokenList.dai), abi.encodeCall(IERC20.transfer, (recipientA, 0)));
    vm.expectCall(address(tokenList.dai), abi.encodeCall(IERC20.transfer, (recipientB, 1)));
    splitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));

    assertEq(tokenList.dai.balanceOf(recipientA), 0);
    assertEq(tokenList.dai.balanceOf(recipientB), 1);
  }

  function test_splitRevenue_fuzz_rounding(uint256 count, uint256 balance) public {
    count = bound(count, 2, 20);
    balance = bound(balance, 1, MAX_SUPPLY_AMOUNT);
    (address[] memory recipients, uint256[] memory splits) = _randomRecipients(count);
    RevenueSplitter newSplitter = _deploySplitter(recipients, splits);
    deal(address(tokenList.dai), address(newSplitter), balance);

    newSplitter.splitRevenue(_pair(address(hub1)), _pair(address(tokenList.dai)));

    uint256 lastIndex = count - 1;
    uint256 distributed;
    for (uint256 i; i < lastIndex; ++i) {
      uint256 received = tokenList.dai.balanceOf(recipients[i]);
      assertEq(received, (balance * splits[i]) / PercentageMath.PERCENTAGE_FACTOR);
      distributed += received;
    }
    uint256 lastReceived = tokenList.dai.balanceOf(recipients[lastIndex]);
    uint256 lastExpected = (balance * splits[lastIndex]) / PercentageMath.PERCENTAGE_FACTOR;
    // the last recipient absorbs at most one wei of rounding per other recipient
    assertGe(lastReceived, lastExpected);
    assertLe(lastReceived - lastExpected, lastIndex);
    assertEq(distributed + lastReceived, balance);
    assertEq(tokenList.dai.balanceOf(address(newSplitter)), 0);
  }

  function test_splitRevenue_multipleHubsAndAssets() public {
    uint256 hub1DaiAmount = 100e18;
    uint256 hub2DaiAmount = 200e18;
    uint256 hub1UsdxAmount = 300e6;
    _treasurySupply(hub1, address(tokenList.dai), hub1DaiAmount);
    _treasurySupply(hub2, address(tokenList.dai), hub2DaiAmount);
    _treasurySupply(hub1, address(tokenList.usdx), hub1UsdxAmount);

    address[] memory hubs = new address[](3);
    hubs[0] = address(hub1);
    hubs[1] = address(hub2);
    hubs[2] = address(hub1);
    address[] memory underlyings = new address[](3);
    underlyings[0] = address(tokenList.dai);
    underlyings[1] = address(tokenList.dai);
    underlyings[2] = address(tokenList.usdx);

    vm.expectEmit(address(splitter));
    emit IRevenueSplitter.SplitRevenue(address(hub1), address(tokenList.dai), hub1DaiAmount);
    vm.expectEmit(address(splitter));
    emit IRevenueSplitter.SplitRevenue(address(hub2), address(tokenList.dai), hub2DaiAmount);
    vm.expectEmit(address(splitter));
    emit IRevenueSplitter.SplitRevenue(address(hub1), address(tokenList.usdx), hub1UsdxAmount);
    splitter.splitRevenue(hubs, underlyings);

    uint256 daiA = hub1DaiAmount.percentMulDown(SPLIT_A) + hub2DaiAmount.percentMulDown(SPLIT_A);
    assertEq(tokenList.dai.balanceOf(recipientA), daiA);
    assertEq(tokenList.dai.balanceOf(recipientB), hub1DaiAmount + hub2DaiAmount - daiA);
    _assertSplit(tokenList.usdx, hub1UsdxAmount);
    assertEq(treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.dai)), 0);
    assertEq(treasurySpoke.getSuppliedAssets(address(hub2), address(tokenList.dai)), 0);
    assertEq(treasurySpoke.getSuppliedAssets(address(hub1), address(tokenList.usdx)), 0);
  }

  function test_splitRevenue_duplicatePair() public {
    uint256 amount = 100e18;
    _treasurySupply(hub1, address(tokenList.dai), amount);

    address[] memory hubs = new address[](2);
    hubs[0] = address(hub1);
    hubs[1] = address(hub1);
    address[] memory underlyings = new address[](2);
    underlyings[0] = address(tokenList.dai);
    underlyings[1] = address(tokenList.dai);

    vm.expectCall(
      address(treasurySpoke),
      abi.encodeWithSelector(ITreasurySpoke.withdraw.selector),
      1
    );
    splitter.splitRevenue(hubs, underlyings);

    _assertSplit(tokenList.dai, amount);
  }

  function _treasurySupply(IHub hub, address underlying, uint256 amount) internal {
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.supply(address(hub), underlying, amount);
  }

  function _assertSplit(IERC20 token, uint256 total) internal view {
    uint256 expectedA = total.percentMulDown(SPLIT_A);
    assertEq(token.balanceOf(recipientA), expectedA, 'recipientA balance');
    assertEq(token.balanceOf(recipientB), total - expectedA, 'recipientB balance');
  }

  function _deploySplitter(
    address[] memory recipients,
    uint256[] memory splits
  ) internal returns (RevenueSplitter) {
    return new RevenueSplitter(address(treasurySpoke), recipients, splits);
  }

  /// @dev Unique non-zero recipients with non-zero splits summing to `PERCENTAGE_FACTOR`.
  function _randomRecipients(uint256 count) internal returns (address[] memory, uint256[] memory) {
    address[] memory recipients = new address[](count);
    uint256[] memory splits = new uint256[](count);
    uint256 remaining = PercentageMath.PERCENTAGE_FACTOR;
    for (uint256 i; i < count; ++i) {
      recipients[i] = makeAddr(string.concat('recipient', vm.toString(i)));
      if (i == count - 1) {
        splits[i] = remaining;
      } else {
        splits[i] = vm.randomUint(1, remaining - (count - 1 - i));
        remaining -= splits[i];
      }
    }
    return (recipients, splits);
  }

  function _pair(address a, address b) internal pure returns (address[] memory) {
    address[] memory arr = new address[](2);
    arr[0] = a;
    arr[1] = b;
    return arr;
  }

  function _pair(uint256 a, uint256 b) internal pure returns (uint256[] memory) {
    uint256[] memory arr = new uint256[](2);
    arr[0] = a;
    arr[1] = b;
    return arr;
  }

  function _pair(address a) internal pure returns (address[] memory) {
    address[] memory arr = new address[](1);
    arr[0] = a;
    return arr;
  }
}
