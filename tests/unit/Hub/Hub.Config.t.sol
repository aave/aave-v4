// // SPDX-License-Identifier: UNLICENSED
// // Copyright (c) 2025 Aave Labs
// pragma solidity ^0.8.0;

// import 'tests/unit/Hub/HubBase.t.sol';

// contract HubConfigTest is HubBase {
//   using SharesMath for uint256;
//   using WadRayMath for uint32;
//   using SafeCast for uint256;

//   bytes public encodedIrData;

//   function setUp() public virtual override {
//     super.setUp();
//     encodedIrData = abi.encode(
//       IAssetInterestRateStrategy.InterestRateData({
//         optimalUsageRatio: 90_00, // 90.00%
//         baseVariableBorrowRate: 5_00, // 5.00%
//         variableRateSlope1: 5_00, // 5.00%
//         variableRateSlope2: 5_00 // 5.00%
//       })
//     );
//   }

//   function test_hub_deploy_revertsWith_InvalidAddress() public {
//     vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
//     new Hub(address(0));
//   }

//   function test_hub_max_riskPremium() public {
//     assertEq(Constants.MAX_RISK_PREMIUM_THRESHOLD, hub1.MAX_RISK_PREMIUM_THRESHOLD());
//   }

//   function test_addSpoke_fuzz_revertsWith_AssetNotListed(
//     address underlying,
//     IHub.SpokeConfig calldata spokeConfig
//   ) public {
//     underlying = bound(underlying, hub1.getAssetCount(), UINT256_MAX);
//     vm.expectRevert(IHub.AssetNotListed.selector, address(hub1));
//     Utils.addSpoke(hub1, ADMIN, underlying, address(spoke1), spokeConfig);
//   }

//   function test_addSpoke_fuzz_revertsWith_InvalidAddress_spoke(
//     address underlying,
//     IHub.SpokeConfig calldata spokeConfig
//   ) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);

//     vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
//     Utils.addSpoke(hub1, ADMIN, underlying, address(0), spokeConfig);
//   }

//   function test_addSpoke_revertsWith_SpokeAlreadyListed() public {
//     IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(
//       address(tokenList.dai),
//       address(spoke1)
//     );
//     vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
//     Utils.addSpoke(hub1, ADMIN, address(tokenList.dai), address(spoke1), spokeConfig);
//   }

//   function test_addSpoke_fuzz(address underlying, IHub.SpokeConfig calldata spokeConfig) public {
//     address newSpoke = makeAddr('newSpoke');
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);

//     vm.expectEmit(address(hub1));
//     emit IHub.AddSpoke(underlying, newSpoke);
//     vm.expectEmit(address(hub1));
//     emit IHub.UpdateSpokeConfig(underlying, newSpoke, spokeConfig);
//     Utils.addSpoke(hub1, ADMIN, underlying, newSpoke, spokeConfig);

//     assertEq(hub1.getSpokeConfig(underlying, newSpoke), spokeConfig);
//   }

//   function test_updateSpokeConfig_revertsWith_AssetNotListed() public {
//     address underlying = _randomInvalidUnderlying(hub1);
//     address spoke = vm.randomAddress();
//     IHub.SpokeConfig memory spokeConfig;
//     vm.expectRevert(IHub.AssetNotListed.selector);
//     Utils.updateSpokeConfig(hub1, ADMIN, underlying, spoke, spokeConfig);
//   }

//   function test_updateSpokeConfig_fuzz_revertsWith_SpokeNotListed(
//     address underlying,
//     address spoke,
//     IHub.SpokeConfig calldata spokeConfig
//   ) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 3);
//     assumeUnusedAddress(spoke);
//     vm.expectRevert(IHub.SpokeNotListed.selector, address(hub1));
//     Utils.updateSpokeConfig(hub1, ADMIN, underlying, spoke, spokeConfig);
//   }

//   function test_updateSpokeConfig_fuzz(
//     address underlying,
//     IHub.SpokeConfig calldata spokeConfig
//   ) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 3); // Exclude duplicated DAI and usdy

//     vm.expectEmit(address(hub1));
//     emit IHub.UpdateSpokeConfig(underlying, address(spoke1), spokeConfig);

//     Utils.updateSpokeConfig(hub1, ADMIN, underlying, address(spoke1), spokeConfig);
//     assertEq(hub1.getSpokeConfig(underlying, address(spoke1)), spokeConfig);
//   }

//   function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
//     address underlying,
//     uint8 decimals,
//     address feeReceiver,
//     address interestRateStrategy
//   ) public {
//     assumeUnusedAddress(underlying);
//     assumeNotZeroAddress(feeReceiver);
//     assumeNotZeroAddress(interestRateStrategy);

//     decimals = bound(decimals, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS + 1, type(uint8).max)
//       .toUint8();

//     vm.expectRevert(IHub.InvalidAssetDecimals.selector, address(hub1));
//     Utils.addAsset(
//       hub1,
//       ADMIN,
//       underlying,
//       decimals,
//       feeReceiver,
//       interestRateStrategy,
//       encodedIrData
//     );
//   }

//   function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals_tooLow(
//     address underlying,
//     uint8 decimals,
//     address feeReceiver,
//     address interestRateStrategy
//   ) public {
//     assumeUnusedAddress(underlying);
//     assumeNotZeroAddress(feeReceiver);
//     assumeNotZeroAddress(interestRateStrategy);

//     decimals = bound(decimals, 0, Constants.MIN_ALLOWED_UNDERLYING_DECIMALS - 1).toUint8();

//     vm.expectRevert(IHub.InvalidAssetDecimals.selector, address(hub1));
//     Utils.addAsset(
//       hub1,
//       ADMIN,
//       underlying,
//       decimals,
//       feeReceiver,
//       interestRateStrategy,
//       encodedIrData
//     );
//   }

//   function test_addAsset_fuzz_revertsWith_InvalidAddress_underlying(
//     uint8 decimals,
//     address feeReceiver,
//     address interestRateStrategy
//   ) public {
//     vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
//     Utils.addAsset(
//       hub1,
//       ADMIN,
//       address(0),
//       decimals,
//       feeReceiver,
//       interestRateStrategy,
//       encodedIrData
//     );
//   }

//   function test_addAsset_fuzz_revertsWith_InvalidAddress_feeReceiver(
//     address underlying,
//     uint8 decimals,
//     address interestRateStrategy
//   ) public {
//     assumeUnusedAddress(underlying);
//     assumeNotZeroAddress(interestRateStrategy);

//     decimals = bound(decimals, 0, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS).toUint8();

//     vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
//     Utils.addAsset(
//       hub1,
//       ADMIN,
//       underlying,
//       decimals,
//       address(0), // feeReceiver
//       interestRateStrategy,
//       encodedIrData
//     );
//   }

//   function test_addAsset_fuzz_revertsWith_InvalidAddress_irStrategy(
//     address underlying,
//     uint8 decimals,
//     address feeReceiver
//   ) public {
//     assumeUnusedAddress(underlying);
//     assumeNotZeroAddress(feeReceiver);

//     decimals = bound(decimals, 0, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS).toUint8();

//     vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
//     Utils.addAsset(hub1, ADMIN, underlying, decimals, feeReceiver, address(0), encodedIrData);
//   }

//   function test_addAsset_fuzz_reverts_InvalidIrData(
//     address underlying,
//     uint8 decimals,
//     address feeReceiver,
//     address interestRateStrategy
//   ) public {
//     assumeUnusedAddress(underlying);
//     assumeNotZeroAddress(feeReceiver);
//     assumeNotZeroAddress(interestRateStrategy);
//     decimals = bound(decimals, 0, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS).toUint8();

//     vm.expectRevert();
//     Utils.addAsset(
//       hub1,
//       ADMIN,
//       underlying,
//       decimals,
//       feeReceiver,
//       interestRateStrategy,
//       abi.encode('invalid')
//     );
//   }

//   function test_addAsset_reverts_AssetAlreadyListed() public {
//     assertTrue(hub1.isUnderlyingListed(address(tokenList.dai)));

//     vm.expectRevert(IHub.AssetAlreadyListed.selector, address(hub1));
//     Utils.addAsset(
//       hub1,
//       ADMIN,
//       address(tokenList.dai),
//       18,
//       address(treasurySpoke),
//       address(irStrategy),
//       encodedIrData
//     );
//   }

//   function test_addAsset_revertsWith_DrawnRateDowncastOverflow() public {
//     address underlying = address(
//       new TestnetERC20('USDA', 'USDA', Constants.MIN_ALLOWED_UNDERLYING_DECIMALS)
//     );

//     uint256 drawnRateRay = uint256(type(uint96).max) + 1;
//     _mockInterestRateRay(drawnRateRay);
//     vm.expectRevert(
//       abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, 96, drawnRateRay),
//       address(hub1)
//     );
//     Utils.addAsset(
//       hub1,
//       ADMIN,
//       underlying,
//       18,
//       address(treasurySpoke),
//       address(irStrategy),
//       encodedIrData
//     );
//   }

//   function test_addAsset_revertsWith_BlockTimestampDowncastOverflow() public {
//     address underlying = address(
//       new TestnetERC20('USDA', 'USDA', Constants.MIN_ALLOWED_UNDERLYING_DECIMALS)
//     );
//     uint256 blockTimestamp = uint256(type(uint40).max) + 1;
//     vm.warp(blockTimestamp);
//     vm.expectRevert(
//       abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, 40, blockTimestamp),
//       address(hub1)
//     );
//     Utils.addAsset(
//       hub1,
//       ADMIN,
//       underlying,
//       18,
//       address(treasurySpoke),
//       address(irStrategy),
//       encodedIrData
//     );
//   }

//   function test_addAsset_fuzz(address underlying, uint8 decimals, address feeReceiver) public {
//     assumeUnusedAddress(underlying);
//     assumeNotZeroAddress(feeReceiver);

//     decimals = bound(
//       decimals,
//       Constants.MAX_ALLOWED_UNDERLYING_DECIMALS,
//       Constants.MAX_ALLOWED_UNDERLYING_DECIMALS
//     ).toUint8();

//     uint256 expectedUnderlying = hub1.getAssetCount();
//     address interestRateStrategy = address(new AssetInterestRateStrategy(address(hub1)));

//     IHub.AssetConfig memory expectedConfig = IHub.AssetConfig({
//       feeReceiver: feeReceiver,
//       liquidityFee: 0,
//       irStrategy: interestRateStrategy,
//       reinvestmentController: address(0)
//     });

//     (, uint32 baseVariableBorrowRate, , ) = abi.decode(
//       encodedIrData,
//       (uint32, uint32, uint32, uint32)
//     );

//     // feeReceiver risk premium threshold defaults to 0
//     IHub.SpokeConfig memory expectedSpokeConfig = IHub.SpokeConfig({
//       active: true,
//       paused: false,
//       addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
//       drawCap: 0,
//       riskPremiumThreshold: 0
//     });

//     vm.expectEmit(address(hub1));
//     emit IHub.AddSpoke(expectedUnderlying, feeReceiver);
//     vm.expectEmit(address(hub1));
//     emit IHub.UpdateSpokeConfig(expectedUnderlying, feeReceiver, expectedSpokeConfig);
//     vm.expectEmit(address(hub1));
//     emit IHub.AddAsset(expectedUnderlying, underlying, decimals);
//     vm.expectEmit(address(hub1));
//     emit IHub.UpdateAssetConfig(expectedUnderlying, expectedConfig);
//     vm.expectEmit(address(hub1));
//     emit IHub.UpdateAsset(expectedUnderlying, WadRayMath.RAY, baseVariableBorrowRate.bpsToRay(), 0);

//     address underlying = Utils.addAsset(
//       hub1,
//       ADMIN,
//       underlying,
//       decimals,
//       feeReceiver,
//       interestRateStrategy,
//       encodedIrData
//     );

//     assertBorrowRateSynced(hub1, underlying, 'addAsset');
//     assertEq(underlying, expectedUnderlying, 'asset id');
//     assertEq(hub1.getAssetCount(), underlying + 1, 'asset count');
//     assertEq(hub1.getAsset(underlying).decimals, decimals, 'asset decimals');
//     assertEq(hub1.getAssetConfig(underlying), expectedConfig);
//     assertEq(hub1.getAsset(underlying).reinvestmentController, address(0)); // should init to addr(0)
//     assertEq(hub1.getSpokeConfig(underlying, feeReceiver), expectedSpokeConfig);
//   }

//   function test_updateAssetConfig_fuzz_revertsWith_InvalidLiquidityFee(
//     address underlying,
//     IHub.AssetConfig memory newConfig
//   ) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);
//     _assumeValidAssetConfig(newConfig);
//     newConfig.liquidityFee = vm
//       .randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max)
//       .toUint16();
//     vm.expectRevert(IHub.InvalidLiquidityFee.selector, address(hub1));
//     vm.prank(HUB_ADMIN);
//     hub1.updateAssetConfig(underlying, newConfig, new bytes(0));
//   }

//   // @dev can only reset reinvestment strategy if swept is zero
//   function test_updateAssetConfig_fuzz_revertsWith_InvalidReinvestmentController() public {
//     address underlying = _randomUnderlying(hub1);
//     IHub.AssetConfig memory config = hub1.getAssetConfig(underlying);

//     config.reinvestmentController = address(0);
//     assertEq(hub1.getAssetSwept(underlying), 0);

//     vm.prank(HUB_ADMIN);
//     hub1.updateAssetConfig(underlying, config, new bytes(0));
//     assertEq(hub1.getAsset(underlying).reinvestmentController, address(0));

//     address reinvestmentController = makeAddr('reinvestmentController');
//     updateAssetReinvestmentController(hub1, underlying, reinvestmentController);
//     _addLiquidity(underlying, 1000e18);
//     vm.prank(reinvestmentController);
//     hub1.sweep(underlying, 100e18);

//     assertEq(hub1.getAssetSwept(underlying), 100e18);
//     assertEq(config.reinvestmentController, address(0));
//     assertNotEq(hub1.getAsset(underlying).reinvestmentController, address(0));

//     vm.expectRevert(IHub.InvalidReinvestmentController.selector, address(hub1));
//     vm.prank(HUB_ADMIN);
//     hub1.updateAssetConfig(underlying, config, new bytes(0));
//   }

//   function test_updateAssetConfig_fuzz_revertsWith_calculateInterestRateReverts(
//     address underlying,
//     IHub.AssetConfig memory newConfig
//   ) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);
//     _assumeValidAssetConfig(newConfig);
//     assumeUnusedAddress(newConfig.irStrategy);
//     assumeUnusedAddress(newConfig.feeReceiver);

//     vm.mockCall(
//       newConfig.irStrategy,
//       abi.encodeCall(IBasicInterestRateStrategy.setInterestRateData, (underlying, encodedIrData)),
//       new bytes(0)
//     );
//     vm.mockCallRevert(
//       newConfig.irStrategy,
//       IBasicInterestRateStrategy.calculateInterestRate.selector,
//       'custom revert'
//     );

//     vm.expectRevert(newConfig.irStrategy);
//     vm.prank(HUB_ADMIN);
//     hub1.updateAssetConfig(underlying, newConfig, encodedIrData);
//   }

//   function test_updateAssetConfig_fuzz_revertsWith_setInterestRateDataReverts(
//     address underlying,
//     IHub.AssetConfig memory newConfig
//   ) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);
//     _assumeValidAssetConfig(newConfig);
//     assumeUnusedAddress(newConfig.irStrategy);

//     vm.mockCallRevert(
//       newConfig.irStrategy,
//       abi.encodeCall(IBasicInterestRateStrategy.setInterestRateData, (underlying, encodedIrData)),
//       'custom revert'
//     );

//     vm.expectRevert(address(newConfig.irStrategy));
//     vm.prank(HUB_ADMIN);
//     hub1.updateAssetConfig(underlying, newConfig, encodedIrData);
//   }

//   function test_updateAssetConfig_fuzz(
//     address underlying,
//     IHub.AssetConfig memory newConfig
//   ) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);
//     _assumeValidAssetConfig(newConfig);
//     _mockInterestRateBps(newConfig.irStrategy, 5_00);
//     vm.mockCall(
//       newConfig.irStrategy,
//       abi.encodeCall(IBasicInterestRateStrategy.setInterestRateData, (underlying, encodedIrData)),
//       new bytes(0)
//     );

//     uint256 liquidity = hub1.getAssetLiquidity(underlying);
//     (uint256 drawn, ) = hub1.getAssetOwed(underlying);

//     address oldFeeReceiver = _getFeeReceiver(hub1, underlying);
//     IHub.SpokeConfig memory oldFeeReceiverConfig = hub1.getSpokeConfig(underlying, oldFeeReceiver);

//     // new spoke is added only if it is different from the old one and not yet listed
//     bool isNewFeeReceiver = newConfig.feeReceiver != _getFeeReceiver(hub1, underlying);
//     if (isNewFeeReceiver && !hub1.isSpokeListed(underlying, newConfig.feeReceiver)) {
//       if (_calcUnrealizedFees(hub1, underlying) > 0) {
//         uint256 accruedFees = hub1.getAssetAccruedFees(underlying);
//         vm.expectEmit(address(hub1));
//         emit IHub.MintFeeShares(
//           underlying,
//           _getFeeReceiver(hub1, underlying),
//           hub1.previewAddByAssets(underlying, accruedFees),
//           accruedFees
//         );
//       }
//       vm.expectEmit(address(hub1));
//       emit IHub.UpdateSpokeConfig(
//         underlying,
//         oldFeeReceiver,
//         IHub.SpokeConfig({
//           active: oldFeeReceiverConfig.active,
//           paused: oldFeeReceiverConfig.paused,
//           addCap: 0,
//           drawCap: 0,
//           riskPremiumThreshold: 0
//         })
//       );

//       vm.expectEmit(address(hub1));
//       emit IHub.AddSpoke(underlying, newConfig.feeReceiver);
//       vm.expectEmit(address(hub1));
//       emit IHub.UpdateSpokeConfig(
//         underlying,
//         newConfig.feeReceiver,
//         IHub.SpokeConfig({
//           active: true,
//           paused: false,
//           addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
//           drawCap: 0,
//           riskPremiumThreshold: 0
//         })
//       );
//     } else {
//       newConfig.feeReceiver = _getFeeReceiver(hub1, underlying);
//     }
//     vm.expectEmit(address(hub1));
//     emit IHub.UpdateAsset(
//       underlying,
//       hub1.getAssetDrawnIndex(underlying),
//       IBasicInterestRateStrategy(irStrategy).calculateInterestRate({
//         underlying: underlying,
//         liquidity: liquidity,
//         drawn: drawn,
//         deficit: 0,
//         swept: 0
//       }),
//       isNewFeeReceiver ? 0 : hub1.getAssetAccruedFees(underlying)
//     );
//     vm.expectEmit(address(hub1));
//     emit IHub.UpdateAssetConfig(underlying, newConfig);

//     // if ir strategy is new, expect an emit of setInterestRateData
//     bool isNewIrStrategy = newConfig.irStrategy != hub1.getAsset(underlying).irStrategy;
//     if (isNewIrStrategy) {
//       vm.expectCall(
//         newConfig.irStrategy,
//         abi.encodeCall(IBasicInterestRateStrategy.setInterestRateData, (underlying, encodedIrData))
//       );
//     }

//     Utils.updateAssetConfig(
//       hub1,
//       ADMIN,
//       underlying,
//       newConfig,
//       isNewIrStrategy ? encodedIrData : new bytes(0)
//     );

//     assertEq(hub1.getAssetConfig(underlying), newConfig);
//     assertBorrowRateSynced(hub1, underlying, 'updateAssetConfig');
//   }

//   function test_updateAssetConfig_fuzz_Scenario(address underlying) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);

//     IHub.AssetConfig memory config = hub1.getAssetConfig(underlying);
//     // set same config
//     test_updateAssetConfig_fuzz(underlying, config);
//     // set new fee receiver
//     config.feeReceiver = makeAddr('newFeeReceiver');
//     test_updateAssetConfig_fuzz(underlying, config);
//     // set zero liquidity fee
//     config.liquidityFee = 0;
//     test_updateAssetConfig_fuzz(underlying, config);
//     // set zero liquidity fee again
//     test_updateAssetConfig_fuzz(underlying, config);
//     // set non-zero fee receiver
//     config.feeReceiver = makeAddr('newFeeReceiver2');
//     test_updateAssetConfig_fuzz(underlying, config);
//     // set initial config
//     test_updateAssetConfig_fuzz(underlying, hub1.getAssetConfig(underlying));
//   }

//   /// Updates to new fee receiver, with previously accrued fees not transferred to the new receiver
//   function test_updateAssetConfig_fuzz_NewFeeReceiver(address underlying) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);

//     uint256 amount = 1000e18;
//     _addLiquidity(underlying, amount);
//     _drawLiquidity(underlying, amount, true);

//     skip(365 days);

//     IHub.AssetConfig memory config = hub1.getAssetConfig(underlying);
//     address oldFeeReceiver = config.feeReceiver;
//     config.feeReceiver = makeAddr('newFeeReceiver');

//     uint256 expectedFeeReceiverAddedAssets = _getExpectedFeeReceiverAddedAssets(hub1, underlying);
//     assertTrue(expectedFeeReceiverAddedAssets > 0, 'no fees');

//     test_updateAssetConfig_fuzz(underlying, config);

//     assertApproxEqAbs(
//       hub1.getSpokeAddedAssets(underlying, oldFeeReceiver),
//       expectedFeeReceiverAddedAssets,
//       2
//     );
//     assertEq(hub1.getSpokeAddedShares(underlying, config.feeReceiver), 0);

//     IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(underlying, oldFeeReceiver);
//     assertTrue(spokeConfig.active, 'old fee receiver remains active');
//     assertEq(spokeConfig.addCap, 0, 'old fee receiver add cap');
//     assertEq(spokeConfig.drawCap, 0, 'old fee receiver draw cap');
//   }

//   /// Updates the fee receiver to a new spoke; old fee receiver active/paused flags are preserved
//   function test_updateAssetConfig_oldFeeReceiver_flags() public {
//     _test_updateAssetConfig_oldFeeReceiver_flags({active: true, paused: true});
//     _test_updateAssetConfig_oldFeeReceiver_flags({active: true, paused: false});
//     _test_updateAssetConfig_oldFeeReceiver_flags({active: false, paused: true});
//     _test_updateAssetConfig_oldFeeReceiver_flags({active: false, paused: false});
//   }

//   function _test_updateAssetConfig_oldFeeReceiver_flags(bool active, bool paused) internal {
//     address underlying = _randomUnderlying(hub1);

//     address oldFeeReceiver = _getFeeReceiver(hub1, underlying);
//     IHub.SpokeConfig memory oldFeeReceiverConfig = hub1.getSpokeConfig(underlying, oldFeeReceiver);
//     oldFeeReceiverConfig.active = active;
//     oldFeeReceiverConfig.paused = paused;

//     // update old fee receiver config flags
//     Utils.updateSpokeConfig(hub1, ADMIN, underlying, oldFeeReceiver, oldFeeReceiverConfig);
//     assertEq(hub1.getSpokeConfig(underlying, oldFeeReceiver).active, active);
//     assertEq(hub1.getSpokeConfig(underlying, oldFeeReceiver).paused, paused);

//     // update asset config to new fee receiver; old fee receiver paused/active flags should be unchanged
//     IHub.AssetConfig memory config = hub1.getAssetConfig(underlying);
//     config.feeReceiver = makeAddr('newFeeReceiver');
//     test_updateAssetConfig_fuzz(underlying, config);

//     assertEq(_getFeeReceiver(hub1, underlying), config.feeReceiver, 'new fee receiver');
//     assertEq(
//       hub1.getSpokeConfig(underlying, oldFeeReceiver).active,
//       active,
//       'old fee receiver active'
//     );
//     assertEq(
//       hub1.getSpokeConfig(underlying, oldFeeReceiver).paused,
//       paused,
//       'old fee receiver paused'
//     );
//   }

//   /// Updates the fee receiver while the current fee receiver is not active
//   function test_updateAssetConfig_NewFeeReceiver_revertsWith_SpokeNotActive_noFees() public {
//     address underlying = address(tokenList.dai);

//     uint256 amount = 1000e18;
//     _addLiquidity(underlying, amount);
//     _drawLiquidity(underlying, amount, true);
//     skip(365 days);

//     updateSpokeActive(hub1, underlying, _getFeeReceiver(hub1, underlying), false);
//     IHub.AssetConfig memory config = hub1.getAssetConfig(underlying);
//     config.feeReceiver = makeAddr('newFeeReceiver');

//     vm.expectRevert(IHub.SpokeNotActive.selector, address(hub1));
//     Utils.updateAssetConfig(hub1, ADMIN, underlying, config, new bytes(0));
//   }

//   /// Updates the fee receiver while the current fee receiver is not active and no fees are accrued
//   function test_updateAssetConfig_NewFeeReceiver_noFees() public {
//     address underlying = address(tokenList.dai);

//     uint256 amount = 1000e18;
//     _addLiquidity(underlying, amount);
//     _drawLiquidity(underlying, amount, true);
//     skip(365 days);

//     Utils.mintFeeShares(hub1, underlying, ADMIN);

//     updateSpokeActive(hub1, underlying, _getFeeReceiver(hub1, underlying), false);
//     IHub.AssetConfig memory config = hub1.getAssetConfig(underlying);
//     config.feeReceiver = makeAddr('newFeeReceiver');

//     Utils.updateAssetConfig(hub1, ADMIN, underlying, config, new bytes(0));
//   }

//   /// Updates the fee receiver by reusing a previously assigned spoke, with no impact on accrued fees
//   function test_updateAssetConfig_fuzz_ReuseFeeReceiver_revertsWith_SpokeAlreadyListed(
//     address underlying
//   ) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);
//     test_updateAssetConfig_fuzz_NewFeeReceiver(underlying);

//     address oldFeeReceiver = address(treasurySpoke);
//     uint256 oldFees = hub1.getSpokeAddedShares(underlying, oldFeeReceiver);

//     skip(365 days);
//     Utils.mintFeeShares(hub1, underlying, ADMIN);

//     IHub.AssetConfig memory config = hub1.getAssetConfig(underlying);
//     address newFeeReceiver = config.feeReceiver;

//     uint256 newFees = hub1.getSpokeAddedShares(underlying, newFeeReceiver);
//     assertTrue(newFees > 0);

//     config.feeReceiver = address(treasurySpoke);

//     vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
//     Utils.updateAssetConfig(hub1, ADMIN, underlying, config, new bytes(0));

//     assertEq(hub1.getSpokeAddedShares(underlying, config.feeReceiver), oldFees);
//     assertEq(hub1.getSpokeAddedShares(underlying, newFeeReceiver), newFees);
//   }

//   /// Updates the fee receiver to an existing spoke of the hub1, so ends up with existing supplied shares plus accrued fees
//   function test_updateAssetConfig_fuzz_UseExistingSpokeAsFeeReceiver_revertsWith_SpokeAlreadyListed(
//     address underlying
//   ) public {
//     underlying = vm.randomUint(0, hub1.getAssetCount() - 1);
//     address newFeeReceiver = address(spoke1);

//     IHub.AssetConfig memory config = hub1.getAssetConfig(underlying);
//     config.feeReceiver = newFeeReceiver;

//     vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
//     vm.prank(HUB_ADMIN);
//     hub1.updateAssetConfig(underlying, config, new bytes(0));
//   }

//   /// Updates the fee receiver to an existing spoke of the hub1 which is already listed on the asset
//   function test_updateAssetConfig_UseExistingSpokeAndListedAsFeeReceiver_revertsWith_SpokeAlreadyListed()
//     public
//   {
//     address underlying = 3;

//     IHub.AssetConfig memory config = hub1.getAssetConfig(underlying);

//     config.feeReceiver = address(spoke1);

//     // spoke1 is already listed on this asset, therefore is not allowed
//     assertTrue(hub1.isSpokeListed(underlying, address(spoke1)));

//     vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
//     vm.prank(HUB_ADMIN);
//     hub1.updateAssetConfig(underlying, config, new bytes(0));
//   }

//   function test_updateAssetConfig_fuzz_revertsWith_InvalidInterestRateStrategy(
//     address underlying
//   ) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);
//     IHub.AssetConfig memory config = hub1.getAssetConfig(underlying);
//     vm.expectRevert(IHub.InvalidInterestRateStrategy.selector, address(hub1));
//     Utils.updateAssetConfig(hub1, ADMIN, underlying, config, encodedIrData);
//   }

//   /// Triggers accrual when liquidity fee update, based on old liquidity fee
//   function test_updateAssetConfig_fuzz_LiquidityFee(
//     address underlying,
//     uint16 liquidityFee
//   ) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);
//     liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR).toUint16();

//     uint256 amount = 1000e18;
//     _addLiquidity(underlying, amount);
//     _drawLiquidity(underlying, amount, true);

//     IHub.AssetConfig memory config = hub1.getAssetConfig(underlying);
//     uint256 expectedFeeReceiverAddedAssets = _getExpectedFeeReceiverAddedAssets(hub1, underlying);
//     assertTrue(expectedFeeReceiverAddedAssets > 0, 'no fees');

//     config.liquidityFee = liquidityFee;
//     test_updateAssetConfig_fuzz(underlying, config);

//     assertEq(_calcUnrealizedFees(hub1, underlying), 0);
//     assertEq(_getExpectedFeeReceiverAddedAssets(hub1, underlying), expectedFeeReceiverAddedAssets);
//   }

//   /// No fees accrued whe updating liquidity fee from zero to non-zero
//   function test_updateAssetConfig_fuzz_FromZeroLiquidityFee(
//     address underlying,
//     uint16 liquidityFee
//   ) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);
//     liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR).toUint16();

//     IHub.AssetConfig memory config = hub1.getAssetConfig(underlying);
//     config.liquidityFee = 0;
//     test_updateAssetConfig_fuzz(underlying, config);

//     uint256 amount = 1000e18;
//     _addLiquidity(underlying, amount);
//     _drawLiquidity(underlying, amount, true);

//     config.liquidityFee = liquidityFee;
//     config.feeReceiver = makeAddr('feeReceiver');
//     test_updateAssetConfig_fuzz(underlying, config);

//     assertEq(hub1.getSpokeAddedShares(underlying, address(0)), 0);
//     assertEq(hub1.getSpokeAddedShares(underlying, config.feeReceiver), 0);
//   }

//   /// Triggers accrual when interest rate strategy is updated, based on old strategy
//   /// Also makes sure that the base borrow rate is updated after accrual
//   function test_updateAssetConfig_fuzz_NewInterestRateStrategy(address underlying) public {
//     underlying = bound(underlying, 0, hub1.getAssetCount() - 1);

//     uint256 amount = 1000e18;
//     _addLiquidity(underlying, amount);
//     _drawLiquidity(underlying, amount, true);

//     uint256 expectedFeeReceiverAddedAssets = _getExpectedFeeReceiverAddedAssets(hub1, underlying);
//     assertTrue(expectedFeeReceiverAddedAssets > 0, 'no fees');

//     skip(365 days);
//     uint256 futureFees = _getExpectedFeeReceiverAddedAssets(hub1, underlying);
//     rewind(365 days);

//     AssetInterestRateStrategy newIrStrategy = new AssetInterestRateStrategy(address(hub1));
//     _mockInterestRateRay(address(newIrStrategy), hub1.getAssetDrawnRate(underlying) * 10);
//     IHub.AssetConfig memory config = hub1.getAssetConfig(underlying);
//     config.irStrategy = address(newIrStrategy);

//     vm.expectCall(
//       address(newIrStrategy),
//       abi.encodeCall(IBasicInterestRateStrategy.setInterestRateData, (underlying, encodedIrData)),
//       1
//     );
//     Utils.updateAssetConfig(hub1, ADMIN, underlying, config, encodedIrData);

//     skip(365 days);
//     assertNotEq(hub1.getSpokeAddedShares(underlying, config.feeReceiver), futureFees);
//   }

//   function _assumeValidAssetConfig(IHub.AssetConfig memory newConfig) internal pure {
//     newConfig.liquidityFee = bound(newConfig.liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR)
//       .toUint16();
//     vm.assume(address(newConfig.feeReceiver) != address(0) || newConfig.liquidityFee == 0);
//     assumeNotPrecompile(newConfig.feeReceiver);
//     assumeNotForgeAddress(newConfig.feeReceiver);
//     assumeNotZeroAddress(newConfig.irStrategy);
//     assumeNotPrecompile(newConfig.irStrategy);
//     assumeNotForgeAddress(newConfig.irStrategy);
//   }
// }
