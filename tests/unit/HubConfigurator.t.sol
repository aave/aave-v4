// // SPDX-License-Identifier: UNLICENSED
// // Copyright (c) 2025 Aave Labs
// pragma solidity ^0.8.0;

// import 'tests/unit/Hub/HubBase.t.sol';

// contract HubConfiguratorTest is HubBase {
//   using SafeCast for uint256;

//   HubConfigurator public hubConfigurator;

//   address public HUB_CONFIGURATOR_ADMIN = makeAddr('HUB_CONFIGURATOR_ADMIN');
//   uint256 public underlying;
//   bytes public encodedIrData;

//   address[4] public spokeAddresses;
//   address spoke;

//   mapping(address => uint24) public riskPremiumThresholdsPerSpoke; // spoke address => risk premium threshold
//   mapping(uint256 => uint24) public riskPremiumThresholdsPerAsset; // underlying => risk premium threshold

//   function setUp() public virtual override {
//     super.setUp();
//     hubConfigurator = new HubConfigurator(HUB_CONFIGURATOR_ADMIN);
//     IAccessManager accessManager = IAccessManager(hub1.authority());
//     // Grant hubConfigurator hub admin role with 0 delay
//     vm.prank(ADMIN);
//     accessManager.grantRole(Roles.HUB_ADMIN_ROLE, address(hubConfigurator), 0);
//     underlying = address(tokenList.dai);
//     encodedIrData = abi.encode(
//       IAssetInterestRateStrategy.InterestRateData({
//         optimalUsageRatio: 90_00, // 90.00%
//         baseVariableBorrowRate: 5_00, // 5.00%
//         variableRateSlope1: 5_00, // 5.00%
//         variableRateSlope2: 5_00 // 5.00%
//       })
//     );
//     spokeAddresses = [address(spoke1), address(spoke2), address(spoke3), address(treasurySpoke)];
//     spoke = address(spoke1);
//   }

//   function test_addAsset_fuzz_revertsWith_OwnableUnauthorizedAccount(address caller) public {
//     vm.assume(caller != HUB_CONFIGURATOR_ADMIN);

//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
//     vm.prank(caller);
//     _addAsset({
//       fetchErc20Decimals: vm.randomBool(),
//       underlying: vm.randomAddress(),
//       decimals: vm
//         .randomUint(
//           Constants.MIN_ALLOWED_UNDERLYING_DECIMALS,
//           Constants.MAX_ALLOWED_UNDERLYING_DECIMALS
//         )
//         .toUint8(),
//       feeReceiver: vm.randomAddress(),
//       liquidityFee: vm.randomUint(),
//       interestRateStrategy: vm.randomAddress(),
//       encodedIrData: encodedIrData
//     });
//   }

//   function test_addAsset_reverts_invalidIrData() public {
//     vm.expectRevert();
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     _addAsset({
//       fetchErc20Decimals: vm.randomBool(),
//       underlying: vm.randomAddress(),
//       decimals: 10,
//       feeReceiver: vm.randomAddress(),
//       liquidityFee: vm.randomUint(),
//       interestRateStrategy: vm.randomAddress(),
//       encodedIrData: abi.encode('invalid')
//     });
//   }

//   function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
//     bool fetchErc20Decimals,
//     address underlying,
//     uint8 decimals,
//     address feeReceiver,
//     uint256 liquidityFee,
//     address interestRateStrategy
//   ) public {
//     assumeUnusedAddress(underlying);
//     assumeNotZeroAddress(feeReceiver);
//     assumeNotZeroAddress(interestRateStrategy);

//     decimals = bound(decimals, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS + 1, type(uint8).max)
//       .toUint8();
//     liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);

//     vm.expectRevert(IHub.InvalidAssetDecimals.selector, address(hub1));
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     _addAsset(
//       fetchErc20Decimals,
//       underlying,
//       decimals,
//       feeReceiver,
//       liquidityFee,
//       interestRateStrategy,
//       encodedIrData
//     );
//   }

//   function test_addAsset_revertsWith_InvalidAddress_underlying() public {
//     uint8 decimals = uint8(vm.randomUint(0, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS));
//     address feeReceiver = makeAddr('newFeeReceiver');
//     address interestRateStrategy = makeAddr('newIrStrategy');
//     uint256 liquidityFee = vm.randomUint(0, PercentageMath.PERCENTAGE_FACTOR);

//     vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     _addAsset(
//       true,
//       address(0),
//       decimals,
//       feeReceiver,
//       liquidityFee,
//       interestRateStrategy,
//       encodedIrData
//     );
//   }

//   function test_addAsset_revertsWith_InvalidAddress_irStrategy() public {
//     address underlying = makeAddr('newUnderlying');
//     uint8 decimals = uint8(vm.randomUint(0, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS));
//     address feeReceiver = makeAddr('newFeeReceiver');
//     uint256 liquidityFee = vm.randomUint(0, PercentageMath.PERCENTAGE_FACTOR);

//     vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     _addAsset(true, underlying, decimals, feeReceiver, liquidityFee, address(0), encodedIrData);
//   }

//   function test_addAsset_revertsWith_InvalidLiquidityFee() public {
//     address underlying = makeAddr('newUnderlying');
//     uint8 decimals = uint8(vm.randomUint(0, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS));
//     address feeReceiver = makeAddr('newFeeReceiver');
//     address interestRateStrategy = address(new AssetInterestRateStrategy(address(hub1)));
//     uint256 liquidityFee = vm.randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max);

//     vm.expectRevert(IHub.InvalidLiquidityFee.selector, address(hub1));
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     _addAsset(
//       false,
//       underlying,
//       decimals,
//       feeReceiver,
//       liquidityFee,
//       interestRateStrategy,
//       encodedIrData
//     );
//   }

//   function test_addAsset_fuzz(
//     bool fetchErc20Decimals,
//     address underlying,
//     uint8 decimals,
//     address feeReceiver,
//     uint256 liquidityFee,
//     uint16 optimalUsageRatio,
//     uint32 baseVariableBorrowRate,
//     uint32 variableRateSlope1,
//     uint32 variableRateSlope2
//   ) public {
//     assumeUnusedAddress(underlying);
//     assumeNotZeroAddress(feeReceiver);

//     decimals = bound(
//       decimals,
//       Constants.MIN_ALLOWED_UNDERLYING_DECIMALS,
//       Constants.MAX_ALLOWED_UNDERLYING_DECIMALS
//     ).toUint8();
//     optimalUsageRatio = bound(optimalUsageRatio, MIN_OPTIMAL_RATIO, MAX_OPTIMAL_RATIO).toUint16();
//     liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);

//     baseVariableBorrowRate = bound(baseVariableBorrowRate, 0, MAX_BORROW_RATE / 3).toUint32();
//     uint32 remainingAfterBase = MAX_BORROW_RATE.toUint32() - baseVariableBorrowRate;
//     variableRateSlope1 = bound(variableRateSlope1, 0, remainingAfterBase / 2).toUint32();
//     variableRateSlope2 = bound(
//       variableRateSlope2,
//       variableRateSlope1,
//       MAX_BORROW_RATE - baseVariableBorrowRate - variableRateSlope1
//     ).toUint32();

//     uint256 expectedUnderlying = hub1.getAssetCount();
//     address interestRateStrategy = address(new AssetInterestRateStrategy(address(hub1)));

//     encodedIrData = abi.encode(
//       IAssetInterestRateStrategy.InterestRateData({
//         optimalUsageRatio: optimalUsageRatio,
//         baseVariableBorrowRate: baseVariableBorrowRate,
//         variableRateSlope1: variableRateSlope1,
//         variableRateSlope2: variableRateSlope2
//       })
//     );

//     IHub.AssetConfig memory expectedConfig = IHub.AssetConfig({
//       liquidityFee: liquidityFee.toUint16(),
//       feeReceiver: feeReceiver,
//       irStrategy: interestRateStrategy,
//       reinvestmentController: address(0)
//     });
//     IHub.SpokeConfig memory expectedSpokeConfig = IHub.SpokeConfig({
//       active: true,
//       paused: false,
//       addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
//       drawCap: 0,
//       riskPremiumThreshold: 0
//     });

//     vm.expectCall(
//       address(hub1),
//       abi.encodeCall(
//         IHub.addAsset,
//         (underlying, decimals, feeReceiver, interestRateStrategy, encodedIrData)
//       )
//     );

//     vm.expectCall(
//       address(hub1),
//       abi.encodeCall(IHub.updateAssetConfig, (hub1.getAssetCount(), expectedConfig, new bytes(0)))
//     );

//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     underlying = _addAsset(
//       fetchErc20Decimals,
//       underlying,
//       decimals,
//       feeReceiver,
//       liquidityFee,
//       interestRateStrategy,
//       encodedIrData
//     );

//     assertEq(underlying, expectedUnderlying, 'asset id');
//     assertEq(hub1.getAssetCount(), underlying + 1, 'asset count');
//     assertEq(hub1.getAsset(underlying).decimals, decimals, 'asset decimals');
//     assertEq(hub1.getAssetConfig(underlying), expectedConfig);
//     assertEq(hub1.getSpokeConfig(underlying, feeReceiver), expectedSpokeConfig);
//     assertEq(hub1.getAsset(underlying).reinvestmentController, address(0)); // should init to addr(0)
//   }

//   function test_updateLiquidityFee_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.updateLiquidityFee(address(hub1), vm.randomUint(), vm.randomUint());
//   }

//   function test_updateLiquidityFee_revertsWith_InvalidLiquidityFee() public {
//     underlying = vm.randomUint(0, hub1.getAssetCount() - 1);
//     uint16 liquidityFee = uint16(
//       vm.randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max)
//     );

//     vm.expectRevert(IHub.InvalidLiquidityFee.selector);
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateLiquidityFee(address(hub1), underlying, liquidityFee);
//   }

//   function test_updateLiquidityFee_fuzz(address underlying, uint16 liquidityFee) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);
//     liquidityFee = uint16(bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR));

//     IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(underlying);
//     expectedConfig.liquidityFee = liquidityFee;

//     vm.expectCall(
//       address(hub1),
//       abi.encodeCall(IHub.updateAssetConfig, (underlying, expectedConfig, new bytes(0)))
//     );

//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateLiquidityFee(address(hub1), underlying, expectedConfig.liquidityFee);

//     assertEq(hub1.getAssetConfig(underlying), expectedConfig);
//   }

//   function test_updateFeeReceiver_fuzz_revertsWith_OwnableUnauthorizedAccount(
//     address caller
//   ) public {
//     vm.assume(caller != HUB_CONFIGURATOR_ADMIN);
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
//     vm.prank(caller);
//     hubConfigurator.updateFeeReceiver(address(hub1), vm.randomUint(), vm.randomAddress());
//   }

//   function test_updateFeeReceiver_revertsWith_InvalidAddress_spoke() public {
//     underlying = vm.randomUint(0, hub1.getAssetCount() - 1);

//     vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateFeeReceiver(address(hub1), underlying, address(0));
//   }

//   function test_updateFeeReceiver_fuzz(address feeReceiver) public {
//     assumeNotZeroAddress(feeReceiver);
//     IHub.AssetConfig memory oldConfig = hub1.getAssetConfig(underlying);
//     IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(underlying);

//     // if new feeReceiver is different than old one, and is not listed, update the spoke config of old feeReceiver
//     if (feeReceiver != oldConfig.feeReceiver) {
//       if (!hub1.isSpokeListed(underlying, feeReceiver)) {
//         expectedConfig.feeReceiver = feeReceiver;
//         vm.expectCall(
//           address(hub1),
//           abi.encodeCall(IHub.updateAssetConfig, (underlying, expectedConfig, new bytes(0)))
//         );
//       } else {
//         // if new fee receiver is different from old one, and is already listed, revert
//         vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
//       }
//     }
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateFeeReceiver(address(hub1), underlying, feeReceiver);

//     assertEq(hub1.getAssetConfig(underlying), expectedConfig);
//   }

//   function test_updateFeeReceiver_revertsWith_SpokeAlreadyListed() public {
//     underlying = vm.randomUint(0, hub1.getAssetCount() - 1);
//     assertTrue(hub1.isSpokeListed(underlying, address(spoke1)));

//     // set feeReceiver as an existing spoke
//     address feeReceiver = address(spoke1);
//     vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateFeeReceiver(address(hub1), underlying, feeReceiver);
//   }

//   /// @dev Test update fee receiver and fees can still be withdrawn from old fee receiver
//   function test_updateFeeReceiver_WithdrawFromOldSpoke() public {
//     assertEq(
//       hub1.getAssetConfig(address(tokenList.dai)).feeReceiver,
//       address(treasurySpoke),
//       'current fee receiver matches treasury spoke'
//     );

//     // Create debt to build up fees on the existing treasury spoke
//     _addAndDrawLiquidity(
//       hub1,
//       address(tokenList.dai),
//       bob,
//       address(spoke1),
//       1000e18,
//       bob,
//       address(spoke1),
//       100e18,
//       365 days
//     );

//     assertGe(treasurySpoke.getSuppliedShares(address(tokenList.dai)), 0);

//     // Change the fee receiver
//     TreasurySpoke newTreasurySpoke = new TreasurySpoke(HUB_ADMIN, address(hub1));
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateFeeReceiver(
//       address(hub1),
//       address(tokenList.dai),
//       address(newTreasurySpoke)
//     );

//     uint256 fees = treasurySpoke.getSuppliedAmount(address(tokenList.dai));

//     assertEq(
//       hub1.getAssetConfig(address(tokenList.dai)).feeReceiver,
//       address(newTreasurySpoke),
//       'new fee receiver updated'
//     );
//     assertTrue(
//       hub1.getSpokeConfig(address(tokenList.dai), address(treasurySpoke)).active,
//       'old fee receiver is not active'
//     );

//     // Withdraw fees from the old treasury spoke
//     Utils.withdraw(
//       ISpoke(address(treasurySpoke)),
//       address(tokenList.dai),
//       TREASURY_ADMIN,
//       fees,
//       address(treasurySpoke)
//     );
//     assertEq(
//       treasurySpoke.getSuppliedAmount(address(tokenList.dai)),
//       0,
//       'old treasury spoke should be empty'
//     );

//     // Accrue more fees, this time to new fee receiver
//     skip(365 days);
//     Utils.mintFeeShares(hub1, address(tokenList.dai), ADMIN);

//     assertGt(
//       newTreasurySpoke.getSuppliedAmount(address(tokenList.dai)),
//       0,
//       'new fee receiver should have accrued fees'
//     );
//     assertEq(
//       treasurySpoke.getSuppliedAmount(address(tokenList.dai)),
//       0,
//       'old fee receiver should be empty'
//     );
//   }

//   /// @dev Test update fee receiver and old fee receiver still accrues fees
//   function test_updateFeeReceiver_correctAccruals() public {
//     // Ensure current fee receiver is the treasury spoke
//     assertEq(
//       hub1.getAssetConfig(address(tokenList.dai)).feeReceiver,
//       address(treasurySpoke),
//       'old fee receiver mismatch'
//     );

//     // Create debt to build up fees on the existing treasury spoke
//     _addAndDrawLiquidity(
//       hub1,
//       address(tokenList.dai),
//       bob,
//       address(spoke1),
//       1000e18,
//       bob,
//       address(spoke1),
//       100e18,
//       365 days
//     );
//     Utils.mintFeeShares(hub1, address(tokenList.dai), ADMIN);

//     assertGe(treasurySpoke.getSuppliedShares(address(tokenList.dai)), 0);
//     uint256 feeShares = treasurySpoke.getSuppliedShares(address(tokenList.dai));

//     // Change the fee receiver
//     TreasurySpoke newTreasurySpoke = new TreasurySpoke(HUB_ADMIN, address(hub1));
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateFeeReceiver(
//       address(hub1),
//       address(tokenList.dai),
//       address(newTreasurySpoke)
//     );

//     // Ensure fee receiver was updated
//     assertEq(
//       hub1.getAssetConfig(address(tokenList.dai)).feeReceiver,
//       address(newTreasurySpoke),
//       'new fee receiver mismatch'
//     );

//     // Ensure old fee receiver is still active
//     assertTrue(
//       hub1.getSpokeConfig(address(tokenList.dai), address(treasurySpoke)).active,
//       'old fee receiver is not active'
//     );

//     // Withdraw half the fee shares from the old treasury spoke
//     Utils.withdraw(
//       ISpoke(address(treasurySpoke)),
//       address(tokenList.dai),
//       TREASURY_ADMIN,
//       hub1.previewRemoveByShares(address(tokenList.dai), feeShares / 2),
//       address(treasurySpoke)
//     );

//     // Get the remaining fee shares
//     feeShares = treasurySpoke.getSuppliedShares(address(tokenList.dai));

//     // Accrue more fees, this time to new fee receiver
//     skip(365 days);
//     Utils.mintFeeShares(hub1, address(tokenList.dai), ADMIN);

//     // Check that new fee receiver is getting the fees, and not old treasury spoke
//     assertGt(
//       newTreasurySpoke.getSuppliedAmount(address(tokenList.dai)),
//       0,
//       'new fee receiver should have accrued fees'
//     );
//     assertEq(
//       treasurySpoke.getSuppliedShares(address(tokenList.dai)),
//       feeShares,
//       'old fee receiver should still have same share amount'
//     );

//     // Now withdraw remaining fee shares from old treasury spoke
//     Utils.withdraw(
//       ISpoke(address(treasurySpoke)),
//       address(tokenList.dai),
//       TREASURY_ADMIN,
//       UINT256_MAX,
//       address(treasurySpoke)
//     );
//     assertEq(
//       treasurySpoke.getSuppliedShares(address(tokenList.dai)),
//       0,
//       'old fee receiver should be empty'
//     );
//   }

//   function test_updateFeeReceiver_Scenario() public {
//     // set same fee receiver
//     test_updateFeeReceiver_fuzz(address(treasurySpoke));
//     // set new fee receiver
//     test_updateFeeReceiver_fuzz(makeAddr('newFeeReceiver'));
//   }

//   function test_updateFeeConfig_fuzz_revertsWith_OwnableUnauthorizedAccount(address caller) public {
//     vm.assume(caller != HUB_CONFIGURATOR_ADMIN);
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
//     vm.prank(caller);
//     hubConfigurator.updateFeeConfig({
//       hub: address(hub1),
//       underlying: vm.randomUint(),
//       liquidityFee: vm.randomUint(),
//       feeReceiver: vm.randomAddress()
//     });
//   }

//   function test_updateFeeConfig_revertsWith_InvalidAddress_spoke() public {
//     address underlying = vm.randomUint(0, hub1.getAssetCount() - 1);
//     uint256 liquidityFee = vm.randomUint(1, PercentageMath.PERCENTAGE_FACTOR);

//     vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateFeeConfig(address(hub1), underlying, liquidityFee, address(0));
//   }

//   function test_updateFeeConfig_revertsWith_InvalidLiquidityFee() public {
//     address underlying = vm.randomUint(0, hub1.getAssetCount() - 1);
//     uint16 liquidityFee = uint16(
//       vm.randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max)
//     );
//     address feeReceiver = hub1.getAssetConfig(underlying).feeReceiver;

//     vm.expectRevert(IHub.InvalidLiquidityFee.selector, address(hub1));
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateFeeConfig(address(hub1), underlying, liquidityFee, feeReceiver);
//   }

//   function test_updateFeeConfig_fuzz(
//     address underlying,
//     uint16 liquidityFee,
//     address feeReceiver
//   ) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);
//     liquidityFee = uint16(bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR));
//     assumeNotZeroAddress(feeReceiver);

//     IHub.AssetConfig memory oldConfig = hub1.getAssetConfig(underlying);
//     IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(underlying);
//     expectedConfig.liquidityFee = liquidityFee;
//     // if new fee receiver is different from old one, and is not listed, update the spoke config of old fee receiver
//     if (oldConfig.feeReceiver != feeReceiver) {
//       if (!hub1.isSpokeListed(underlying, feeReceiver)) {
//         expectedConfig.feeReceiver = feeReceiver;
//         vm.expectCall(
//           address(hub1),
//           abi.encodeCall(IHub.updateAssetConfig, (underlying, expectedConfig, new bytes(0)))
//         );
//       } else {
//         expectedConfig.liquidityFee = oldConfig.liquidityFee;
//         // if new fee receiver is different from old one, and is already listed, revert
//         vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
//       }
//     }
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateFeeConfig(address(hub1), underlying, liquidityFee, feeReceiver);
//     assertEq(hub1.getAssetConfig(underlying), expectedConfig);
//   }

//   function test_updateFeeConfig_Scenario() public {
//     // set same fee receiver and change liquidity fee
//     test_updateFeeConfig_fuzz(0, 18_00, address(treasurySpoke));
//     // set new fee receiver and liquidity fee
//     test_updateFeeConfig_fuzz(0, 4_00, makeAddr('newFeeReceiver'));
//     // set non-zero fee receiver
//     test_updateFeeConfig_fuzz(0, 0, makeAddr('newFeeReceiver2'));
//   }

//   function test_updateInterestRateStrategy_fuzz_revertsWith_OwnableUnauthorizedAccount(
//     address caller
//   ) public {
//     vm.assume(caller != HUB_CONFIGURATOR_ADMIN);
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
//     vm.prank(caller);
//     hubConfigurator.updateInterestRateStrategy(
//       address(hub1),
//       vm.randomUint(),
//       vm.randomAddress(),
//       encodedIrData
//     );
//   }

//   function test_updateInterestRateStrategy() public {
//     address interestRateStrategy = makeAddr('newInterestRateStrategy');

//     IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(underlying);
//     expectedConfig.irStrategy = interestRateStrategy;
//     _mockInterestRateBps(interestRateStrategy, 5_00);

//     vm.expectCall(
//       address(hub1),
//       abi.encodeCall(IHub.updateAssetConfig, (underlying, expectedConfig, encodedIrData))
//     );

//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateInterestRateStrategy(
//       address(hub1),
//       underlying,
//       interestRateStrategy,
//       encodedIrData
//     );

//     assertEq(hub1.getAssetConfig(underlying), expectedConfig);
//   }

//   function test_updateInterestRateStrategy_revertsWith_InvalidAddress_irStrategy() public {
//     underlying = vm.randomUint(0, hub1.getAssetCount() - 1);

//     vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateInterestRateStrategy(
//       address(hub1),
//       underlying,
//       address(0),
//       encodedIrData
//     );
//   }

//   function test_updateInterestRateStrategy_revertsWith_InterestRateStrategyReverts() public {
//     underlying = vm.randomUint(0, hub1.getAssetCount() - 1);
//     address interestRateStrategy = makeAddr('newInterestRateStrategy');

//     vm.expectRevert();
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateInterestRateStrategy(
//       address(hub1),
//       underlying,
//       interestRateStrategy,
//       encodedIrData
//     );
//   }

//   function test_updateInterestRateStrategy_revertsWith_InvalidInterestRateStrategy() public {
//     vm.expectRevert(IHub.InvalidInterestRateStrategy.selector, address(hub1));
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateInterestRateStrategy(
//       address(hub1),
//       underlying,
//       address(irStrategy),
//       encodedIrData
//     );
//   }

//   function test_updateReinvestmentController_fuzz_revertsWith_OwnableUnauthorizedAccount(
//     address caller
//   ) public {
//     vm.assume(caller != HUB_CONFIGURATOR_ADMIN);
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
//     vm.prank(caller);
//     hubConfigurator.updateReinvestmentController(
//       address(hub1),
//       vm.randomUint(),
//       vm.randomAddress()
//     );
//   }

//   function test_updateReinvestmentController() public {
//     address reinvestmentController = makeAddr('newReinvestmentController');
//     IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(underlying);
//     expectedConfig.reinvestmentController = reinvestmentController;
//     vm.expectCall(
//       address(hub1),
//       abi.encodeCall(IHub.updateAssetConfig, (underlying, expectedConfig, new bytes(0)))
//     );
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateReinvestmentController(address(hub1), underlying, reinvestmentController);

//     assertEq(hub1.getAssetConfig(underlying), expectedConfig);
//   }

//   function test_freezeAsset_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.freezeAsset(address(hub1), underlying);
//   }

//   function test_freezeAsset() public {
//     for (uint256 i; i < spokeAddresses.length; i++) {
//       IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(underlying, spokeAddresses[i]);
//       spokeConfig.addCap = 0;
//       spokeConfig.drawCap = 0;
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.updateSpokeConfig, (underlying, spokeAddresses[i], spokeConfig))
//       );

//       riskPremiumThresholdsPerSpoke[spokeAddresses[i]] = spokeConfig.riskPremiumThreshold;
//     }

//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.freezeAsset(address(hub1), underlying);

//     for (uint256 i; i < spokeAddresses.length; i++) {
//       IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(underlying, spokeAddresses[i]);
//       assertEq(spokeConfig.addCap, 0);
//       assertEq(spokeConfig.drawCap, 0);
//       assertEq(spokeConfig.riskPremiumThreshold, riskPremiumThresholdsPerSpoke[spokeAddresses[i]]);
//     }
//   }

//   function test_deactivateAsset_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.deactivateAsset(address(hub1), underlying);
//   }

//   function test_deactivateAsset() public {
//     for (uint256 i; i < spokeAddresses.length; i++) {
//       IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(underlying, spokeAddresses[i]);
//       spokeConfig.active = false;
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.updateSpokeConfig, (underlying, spokeAddresses[i], spokeConfig))
//       );
//     }

//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.deactivateAsset(address(hub1), underlying);

//     for (uint256 i; i < spokeAddresses.length; i++) {
//       IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(underlying, spokeAddresses[i]);
//       assertEq(spokeConfig.active, false);
//     }
//   }

//   function test_pauseAsset_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.pauseAsset(address(hub1), underlying);
//   }

//   function test_pauseAsset() public {
//     for (uint256 i; i < spokeAddresses.length; i++) {
//       IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(underlying, spokeAddresses[i]);
//       spokeConfig.paused = true;
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.updateSpokeConfig, (underlying, spokeAddresses[i], spokeConfig))
//       );
//     }

//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.pauseAsset(address(hub1), underlying);

//     for (uint256 i; i < spokeAddresses.length; i++) {
//       IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(underlying, spokeAddresses[i]);
//       assertEq(spokeConfig.paused, true);
//     }
//   }

//   function test_addSpoke_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     IHub.SpokeConfig memory spokeConfig;
//     hubConfigurator.addSpoke(address(hub1), vm.randomAddress(), 0, spokeConfig);
//   }

//   function test_addSpoke() public {
//     address newSpoke = makeAddr('newSpoke');

//     IHub.SpokeConfig memory daiSpokeConfig = IHub.SpokeConfig({
//       active: true,
//       paused: false,
//       addCap: 1,
//       drawCap: 2,
//       riskPremiumThreshold: 22
//     });

//     vm.expectEmit(address(hub1));
//     emit IHub.AddSpoke(address(tokenList.dai), newSpoke);
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.addSpoke(address(hub1), newSpoke, address(tokenList.dai), daiSpokeConfig);

//     assertEq(hub1.getSpokeConfig(address(tokenList.dai), newSpoke), daiSpokeConfig);
//   }

//   function test_addSpokeToAssets_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.addSpokeToAssets(
//       address(hub1),
//       vm.randomAddress(),
//       new uint256[](0),
//       new IHub.SpokeConfig[](0)
//     );
//   }

//   function test_addSpokeToAssets_revertsWith_MismatchedConfigs() public {
//     uint256[] memory underlyings = new uint256[](2);
//     underlyings[0] = address(tokenList.dai);
//     underlyings[1] = address(tokenList.weth);

//     IHub.SpokeConfig[] memory spokeConfigs = new IHub.SpokeConfig[](3);
//     spokeConfigs[0] = IHub.SpokeConfig({
//       addCap: 1,
//       drawCap: 2,
//       active: true,
//       paused: false,
//       riskPremiumThreshold: 0
//     });
//     spokeConfigs[1] = IHub.SpokeConfig({
//       addCap: 3,
//       drawCap: 4,
//       active: true,
//       paused: false,
//       riskPremiumThreshold: 0
//     });
//     spokeConfigs[2] = IHub.SpokeConfig({
//       addCap: 5,
//       drawCap: 6,
//       active: true,
//       paused: false,
//       riskPremiumThreshold: 0
//     });

//     vm.expectRevert(IHubConfigurator.MismatchedConfigs.selector);
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.addSpokeToAssets(address(hub1), spoke, underlyings, spokeConfigs);
//   }

//   function test_addSpokeToAssets() public {
//     address newSpoke = makeAddr('newSpoke');

//     uint256[] memory underlyings = new uint256[](2);
//     underlyings[0] = address(tokenList.dai);
//     underlyings[1] = address(tokenList.weth);

//     IHub.SpokeConfig memory daiSpokeConfig = IHub.SpokeConfig({
//       active: true,
//       paused: false,
//       addCap: 1,
//       drawCap: 2,
//       riskPremiumThreshold: 0
//     });
//     IHub.SpokeConfig memory wethSpokeConfig = IHub.SpokeConfig({
//       active: true,
//       paused: false,
//       addCap: 3,
//       drawCap: 4,
//       riskPremiumThreshold: 0
//     });

//     IHub.SpokeConfig[] memory spokeConfigs = new IHub.SpokeConfig[](2);
//     spokeConfigs[0] = daiSpokeConfig;
//     spokeConfigs[1] = wethSpokeConfig;

//     vm.expectEmit(address(hub1));
//     emit IHub.AddSpoke(address(tokenList.dai), newSpoke);
//     vm.expectEmit(address(hub1));
//     emit IHub.AddSpoke(address(tokenList.weth), newSpoke);
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.addSpokeToAssets(address(hub1), newSpoke, underlyings, spokeConfigs);

//     IHub.SpokeConfig memory daiSpokeData = hub1.getSpokeConfig(address(tokenList.dai), newSpoke);
//     IHub.SpokeConfig memory wethSpokeData = hub1.getSpokeConfig(address(tokenList.weth), newSpoke);

//     assertEq(daiSpokeData, daiSpokeConfig);
//     assertEq(wethSpokeData, wethSpokeConfig);
//   }

//   function test_updateSpokePaused_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.updateSpokePaused(address(hub1), underlying, spokeAddresses[0], false);
//   }

//   function test_updateSpokePaused() public {
//     IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(underlying, spoke);
//     for (uint256 i = 0; i < 2; ++i) {
//       bool paused = (i == 0) ? false : true;
//       expectedSpokeConfig.paused = paused;
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.updateSpokeConfig, (underlying, spoke, expectedSpokeConfig))
//       );
//       vm.prank(HUB_CONFIGURATOR_ADMIN);
//       hubConfigurator.updateSpokePaused(address(hub1), underlying, spoke, paused);
//       assertEq(hub1.getSpokeConfig(underlying, spoke), expectedSpokeConfig);
//     }
//   }

//   function test_updateSpokeActive_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.updateSpokeActive(address(hub1), underlying, spokeAddresses[0], true);
//   }

//   function test_updateSpokeActive() public {
//     IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(underlying, spoke);
//     for (uint256 i = 0; i < 2; ++i) {
//       bool active = (i == 0) ? false : true;
//       expectedSpokeConfig.active = active;
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.updateSpokeConfig, (underlying, spoke, expectedSpokeConfig))
//       );
//       vm.prank(HUB_CONFIGURATOR_ADMIN);
//       hubConfigurator.updateSpokeActive(address(hub1), underlying, spoke, active);
//       assertEq(hub1.getSpokeConfig(underlying, spoke), expectedSpokeConfig);
//     }
//   }

//   function test_updateSpokeSupplyCap_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.updateSpokeSupplyCap(address(hub1), underlying, spokeAddresses[0], 100);
//   }

//   function test_updateSpokeSupplyCap() public {
//     uint40 newSupplyCap = 100;
//     IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(underlying, spoke);
//     expectedSpokeConfig.addCap = newSupplyCap;
//     vm.expectCall(
//       address(hub1),
//       abi.encodeCall(IHub.updateSpokeConfig, (underlying, spoke, expectedSpokeConfig))
//     );
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateSpokeSupplyCap(address(hub1), underlying, spoke, newSupplyCap);
//     assertEq(hub1.getSpokeConfig(underlying, spoke), expectedSpokeConfig);
//   }

//   function test_updateSpokeDrawCap_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.updateSpokeDrawCap(address(hub1), underlying, spokeAddresses[0], 100);
//   }

//   function test_updateSpokeDrawCap() public {
//     uint40 newDrawCap = 100;
//     IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(underlying, spoke);
//     expectedSpokeConfig.drawCap = newDrawCap;
//     vm.expectCall(
//       address(hub1),
//       abi.encodeCall(IHub.updateSpokeConfig, (underlying, spoke, expectedSpokeConfig))
//     );
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateSpokeDrawCap(address(hub1), underlying, spoke, newDrawCap);
//     assertEq(hub1.getSpokeConfig(underlying, spoke), expectedSpokeConfig);
//   }

//   function test_updateSpokeRiskPremiumThreshold_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.updateSpokeRiskPremiumThreshold(
//       address(hub1),
//       underlying,
//       spokeAddresses[0],
//       100
//     );
//   }

//   function test_updateSpokeRiskPremiumThreshold() public {
//     uint24 newRiskPremiumThreshold = 100;
//     IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(underlying, spoke);
//     expectedSpokeConfig.riskPremiumThreshold = newRiskPremiumThreshold;
//     vm.expectCall(
//       address(hub1),
//       abi.encodeCall(IHub.updateSpokeConfig, (underlying, spoke, expectedSpokeConfig))
//     );
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateSpokeRiskPremiumThreshold(
//       address(hub1),
//       underlying,
//       spoke,
//       newRiskPremiumThreshold
//     );
//     assertEq(hub1.getSpokeConfig(underlying, spoke), expectedSpokeConfig);
//   }

//   function test_updateSpokeCaps_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.updateSpokeCaps(address(hub1), underlying, spokeAddresses[0], 100, 100);
//   }

//   function test_updateSpokeCaps() public {
//     uint40 newSupplyCap = 100;
//     uint40 newDrawCap = 200;
//     IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(underlying, spoke);
//     expectedSpokeConfig.addCap = newSupplyCap;
//     expectedSpokeConfig.drawCap = newDrawCap;
//     vm.expectCall(
//       address(hub1),
//       abi.encodeCall(IHub.updateSpokeConfig, (underlying, spoke, expectedSpokeConfig))
//     );
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateSpokeCaps(address(hub1), underlying, spoke, newSupplyCap, newDrawCap);
//     assertEq(hub1.getSpokeConfig(underlying, spoke), expectedSpokeConfig);
//   }

//   function test_deactivateSpoke_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.deactivateSpoke(address(hub1), address(spoke3));
//   }

//   function test_deactivateSpoke() public {
//     /// @dev Spoke3 is listed on hub1 on 4 assets: dai, weth, wbtc, usdx
//     assertGt(hub1.getAssetCount(), 4, 'hub1 has less than 4 assets listed');

//     for (address underlying = 0; underlying < 4; ++underlying) {
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.isSpokeListed, (underlying, address(spoke3)))
//       );

//       IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(
//         underlying,
//         address(spoke3)
//       );
//       expectedSpokeConfig.active = false;
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.updateSpokeConfig, (underlying, address(spoke3), expectedSpokeConfig))
//       );
//     }

//     for (address underlying = 4; underlying < hub1.getAssetCount(); ++underlying) {
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.isSpokeListed, (underlying, address(spoke3)))
//       );
//     }

//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.deactivateSpoke(address(hub1), address(spoke3));

//     for (address underlying = 0; underlying < 4; ++underlying) {
//       IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(underlying, address(spoke3));
//       assertEq(spokeConfig.active, false);
//     }
//   }

//   function test_pauseSpoke_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.pauseSpoke(address(hub1), address(spoke3));
//   }

//   function test_pauseSpoke() public {
//     /// @dev Spoke3 is listed on hub1 on 4 assets: dai, weth, wbtc, usdx
//     assertGt(hub1.getAssetCount(), 4, 'hub1 has less than 4 assets listed');

//     for (address underlying = 0; underlying < 4; ++underlying) {
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.isSpokeListed, (underlying, address(spoke3)))
//       );

//       IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(
//         underlying,
//         address(spoke3)
//       );
//       expectedSpokeConfig.paused = true;
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.updateSpokeConfig, (underlying, address(spoke3), expectedSpokeConfig))
//       );
//     }

//     for (address underlying = 4; underlying < hub1.getAssetCount(); ++underlying) {
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.isSpokeListed, (underlying, address(spoke3)))
//       );
//     }

//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.pauseSpoke(address(hub1), address(spoke3));

//     for (address underlying = 0; underlying < 4; ++underlying) {
//       IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(underlying, address(spoke3));
//       assertEq(spokeConfig.paused, true);
//     }
//   }

//   function test_freezeSpoke_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.freezeSpoke(address(hub1), address(spoke3));
//   }

//   function test_freezeSpoke() public {
//     /// @dev Spoke3 is listed on hub1 on 4 assets: dai, weth, wbtc, usdx
//     assertGt(hub1.getAssetCount(), 4, 'hub1 has less than 4 assets listed');

//     for (address underlying = 0; underlying < 4; ++underlying) {
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.isSpokeListed, (underlying, address(spoke3)))
//       );

//       IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(
//         underlying,
//         address(spoke3)
//       );
//       expectedSpokeConfig.addCap = 0;
//       expectedSpokeConfig.drawCap = 0;
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.updateSpokeConfig, (underlying, address(spoke3), expectedSpokeConfig))
//       );

//       riskPremiumThresholdsPerAsset[underlying] = expectedSpokeConfig.riskPremiumThreshold;
//     }

//     for (address underlying = 4; underlying < hub1.getAssetCount(); ++underlying) {
//       vm.expectCall(
//         address(hub1),
//         abi.encodeCall(IHub.isSpokeListed, (underlying, address(spoke3)))
//       );
//     }

//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.freezeSpoke(address(hub1), address(spoke3));

//     for (address underlying = 0; underlying < 4; ++underlying) {
//       IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(underlying, address(spoke3));
//       assertEq(spokeConfig.addCap, 0);
//       assertEq(spokeConfig.drawCap, 0);
//       assertEq(spokeConfig.riskPremiumThreshold, riskPremiumThresholdsPerAsset[underlying]);
//     }
//   }

//   function test_updateInterestRateData_revertsWith_OwnableUnauthorizedAccount() public {
//     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
//     vm.prank(alice);
//     hubConfigurator.updateInterestRateData(address(hub1), underlying, vm.randomBytes(32));
//   }

//   function test_updateInterestRateData() public {
//     IAssetInterestRateStrategy.InterestRateData memory newIrData = IAssetInterestRateStrategy
//       .InterestRateData({
//         optimalUsageRatio: 90_00, // 90.00%
//         baseVariableBorrowRate: 5_00, // 5.00%
//         variableRateSlope1: 5_00, // 5.00%
//         variableRateSlope2: 5_00 // 5.00%
//       });

//     vm.expectCall(
//       address(hub1),
//       abi.encodeCall(IHub.setInterestRateData, (underlying, abi.encode(newIrData)))
//     );
//     vm.prank(HUB_CONFIGURATOR_ADMIN);
//     hubConfigurator.updateInterestRateData(address(hub1), underlying, abi.encode(newIrData));

//     assertEq(irStrategy.getInterestRateData(underlying), newIrData);
//   }

//   function _addAsset(
//     bool fetchErc20Decimals,
//     address underlying,
//     uint8 decimals,
//     address feeReceiver,
//     uint256 liquidityFee,
//     address interestRateStrategy,
//     bytes memory encodedIrData
//   ) internal returns (uint256) {
//     if (fetchErc20Decimals) {
//       _mockDecimals(underlying, decimals);
//       return
//         hubConfigurator.addAsset(
//           address(hub1),
//           underlying,
//           feeReceiver,
//           liquidityFee,
//           interestRateStrategy,
//           encodedIrData
//         );
//     } else {
//       return
//         hubConfigurator.addAsset(
//           address(hub1),
//           underlying,
//           decimals,
//           feeReceiver,
//           liquidityFee,
//           interestRateStrategy,
//           encodedIrData
//         );
//     }
//   }
// }
