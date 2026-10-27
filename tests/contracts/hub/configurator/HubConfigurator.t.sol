// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract HubConfiguratorTest is Base {
  using SafeCast for uint256;

  uint256 internal _assetId;
  address internal _assetUnderlying;
  bytes internal _encodedIrData;

  address[4] public spokeAddresses;
  address public spoke;

  mapping(address spoke => uint24 riskPremiumThreshold) public riskPremiumThresholdsPerSpoke;
  mapping(uint256 assetId => uint24 riskPremiumThreshold) public riskPremiumThresholdsPerAsset;

  function setUp() public virtual override {
    super.setUp();
    _grantHubConfiguratorRole(hub1, address(hubConfigurator));
    _assetId = daiAssetId;
    _assetUnderlying = address(tokenList.dai);
    _encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseDrawnRate: 5_00, // 5.00%
        rateGrowthBeforeOptimal: 5_00, // 5.00%
        rateGrowthAfterOptimal: 5_00 // 5.00%
      })
    );
    spokeAddresses = [address(spoke1), address(spoke2), address(spoke3), address(treasurySpoke)];
    spoke = address(spoke1);
  }

  function test_addAsset_fuzz_revertsWith_AccessManagedUnauthorized(address caller) public {
    _assumeNonHubConfiguratorAdmin(caller);

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    _addAsset({
      fetchErc20Decimals: vm.randomBool(),
      underlying: vm.randomAddress(),
      decimals: vm
        .randomUint(MIN_ALLOWED_UNDERLYING_DECIMALS, MAX_ALLOWED_UNDERLYING_DECIMALS)
        .toUint8(),
      feeReceiver: vm.randomAddress(),
      liquidityFee: vm.randomUint(),
      irStrategy: vm.randomAddress(),
      encodedIrData: _encodedIrData
    });
  }

  function test_addAsset_reverts_invalidIrData() public {
    vm.expectRevert();
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    _addAsset({
      fetchErc20Decimals: vm.randomBool(),
      underlying: vm.randomAddress(),
      decimals: 10,
      feeReceiver: vm.randomAddress(),
      liquidityFee: vm.randomUint(),
      irStrategy: vm.randomAddress(),
      encodedIrData: abi.encode('invalid')
    });
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    uint256 liquidityFee,
    address irStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);
    assumeNotZeroAddress(irStrategy);

    decimals = bound(decimals, MAX_ALLOWED_UNDERLYING_DECIMALS + 1, type(uint8).max).toUint8();
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);

    vm.expectRevert(IHub.InvalidAssetDecimals.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    _addAsset(
      fetchErc20Decimals,
      underlying,
      decimals,
      feeReceiver,
      liquidityFee,
      irStrategy,
      _encodedIrData
    );
  }

  function test_addAsset_revertsWith_InvalidAddress_underlying() public {
    uint8 decimals = uint8(
      vm.randomUint(MIN_ALLOWED_UNDERLYING_DECIMALS, MAX_ALLOWED_UNDERLYING_DECIMALS)
    );
    address feeReceiver = makeAddr('newFeeReceiver');
    address irStrategy = makeAddr('newIrStrategy');
    uint256 liquidityFee = vm.randomUint(0, PercentageMath.PERCENTAGE_FACTOR);

    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    _addAsset(true, address(0), decimals, feeReceiver, liquidityFee, irStrategy, _encodedIrData);
  }

  function test_addAsset_revertsWith_InvalidAddress_irStrategy() public {
    address underlying = makeAddr('newUnderlying');
    uint8 decimals = uint8(
      vm.randomUint(MIN_ALLOWED_UNDERLYING_DECIMALS, MAX_ALLOWED_UNDERLYING_DECIMALS)
    );
    address feeReceiver = makeAddr('newFeeReceiver');
    uint256 liquidityFee = vm.randomUint(0, PercentageMath.PERCENTAGE_FACTOR);

    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    _addAsset(true, underlying, decimals, feeReceiver, liquidityFee, address(0), _encodedIrData);
  }

  function test_addAsset_revertsWith_InvalidLiquidityFee() public {
    address underlying = makeAddr('newUnderlying');
    uint8 decimals = uint8(
      vm.randomUint(MIN_ALLOWED_UNDERLYING_DECIMALS, MAX_ALLOWED_UNDERLYING_DECIMALS)
    );
    address feeReceiver = makeAddr('newFeeReceiver');
    address irStrategy = address(new AssetInterestRateStrategy(address(hub1)));
    uint256 liquidityFee = vm.randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max);

    vm.expectRevert(IHub.InvalidLiquidityFee.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    _addAsset(false, underlying, decimals, feeReceiver, liquidityFee, irStrategy, _encodedIrData);
  }

  function test_addAsset_fuzz(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    uint256 liquidityFee,
    uint16 optimalUsageRatio,
    uint32 baseDrawnRate,
    uint32 rateGrowthBeforeOptimal,
    uint32 rateGrowthAfterOptimal
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);

    decimals = bound(decimals, MIN_ALLOWED_UNDERLYING_DECIMALS, MAX_ALLOWED_UNDERLYING_DECIMALS)
      .toUint8();
    optimalUsageRatio = bound(optimalUsageRatio, MIN_OPTIMAL_RATIO, MAX_OPTIMAL_RATIO).toUint16();
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);

    baseDrawnRate = bound(baseDrawnRate, 0, MAX_ALLOWED_DRAWN_RATE / 3).toUint32();
    uint32 remainingAfterBase = MAX_ALLOWED_DRAWN_RATE.toUint32() - baseDrawnRate;
    rateGrowthBeforeOptimal = bound(rateGrowthBeforeOptimal, 0, remainingAfterBase / 2).toUint32();
    rateGrowthAfterOptimal = bound(
      rateGrowthAfterOptimal,
      rateGrowthBeforeOptimal,
      MAX_ALLOWED_DRAWN_RATE - baseDrawnRate - rateGrowthBeforeOptimal
    ).toUint32();

    uint256 expectedAssetId = hub1.getAssetCount();
    address irStrategy = address(new AssetInterestRateStrategy(address(hub1)));

    _encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: optimalUsageRatio,
        baseDrawnRate: baseDrawnRate,
        rateGrowthBeforeOptimal: rateGrowthBeforeOptimal,
        rateGrowthAfterOptimal: rateGrowthAfterOptimal
      })
    );

    IHub.AssetConfig memory expectedConfig = IHub.AssetConfig({
      liquidityFee: liquidityFee.toUint16(),
      feeReceiver: feeReceiver,
      irStrategy: irStrategy,
      reinvestmentController: address(0)
    });
    IHub.SpokeConfig memory expectedSpokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: MAX_ALLOWED_SPOKE_CAP,
      drawCap: 0,
      riskPremiumThreshold: 0
    });

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.addAsset, (underlying, decimals, feeReceiver, irStrategy, _encodedIrData))
    );

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateAssetConfig, (hub1.getAssetCount(), expectedConfig, new bytes(0)))
    );

    _expectAddAssetEvents(
      underlying,
      expectedAssetId,
      feeReceiver,
      liquidityFee,
      irStrategy,
      abi.decode(_encodedIrData, (IAssetInterestRateStrategy.InterestRateData))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    _assetId = _addAsset(
      fetchErc20Decimals,
      underlying,
      decimals,
      feeReceiver,
      liquidityFee,
      irStrategy,
      _encodedIrData
    );

    assertEq(_assetId, expectedAssetId, 'asset id');
    assertEq(hub1.getAssetCount(), _assetId + 1, 'asset count');
    assertEq(hub1.getAsset(_assetId).decimals, decimals, 'asset decimals');
    assertEq(hub1.getAssetConfig(_assetId), expectedConfig);
    assertEq(hub1.getSpokeConfig(_assetId, feeReceiver), expectedSpokeConfig);
    assertEq(hub1.getAsset(_assetId).reinvestmentController, address(0)); // should init to addr(0)
  }

  function test_updateLiquidityFee_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.updateLiquidityFee(address(hub1), vm.randomAddress(), vm.randomUint());
  }

  function test_updateLiquidityFee_revertsWith_InvalidLiquidityFee() public {
    _assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    _assetUnderlying = _hub1Underlying(_assetId);
    uint16 liquidityFee = uint16(
      vm.randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max)
    );

    vm.expectRevert(IHub.InvalidLiquidityFee.selector);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateLiquidityFee(address(hub1), _assetUnderlying, liquidityFee);
  }

  function test_updateLiquidityFee_fuzz(uint256 assetId, uint16 liquidityFee) public {
    _assetId = bound(assetId, 0, hub1.getAssetCount() - 1);
    _assetUnderlying = _hub1Underlying(_assetId);
    liquidityFee = uint16(bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR));

    IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(_assetId);
    uint256 oldLiquidityFee = expectedConfig.liquidityFee;
    expectedConfig.liquidityFee = liquidityFee;

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateAssetConfig, (_assetId, expectedConfig, new bytes(0)))
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.LiquidityFeeUpdated(
      address(hub1),
      _assetUnderlying,
      _assetId,
      oldLiquidityFee,
      liquidityFee
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateLiquidityFee(
      address(hub1),
      _assetUnderlying,
      expectedConfig.liquidityFee
    );

    assertEq(hub1.getAssetConfig(_assetId), expectedConfig);
  }

  function test_updateFeeReceiver_fuzz_revertsWith_AccessManagedUnauthorized(
    address caller
  ) public {
    _assumeNonHubConfiguratorAdmin(caller);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    hubConfigurator.updateFeeReceiver(address(hub1), vm.randomAddress(), vm.randomAddress());
  }

  function test_updateFeeReceiver_revertsWith_InvalidAddress_spoke() public {
    _assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    _assetUnderlying = _hub1Underlying(_assetId);

    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeReceiver(address(hub1), _assetUnderlying, address(0));
  }

  function test_updateFeeReceiver_fuzz(address feeReceiver) public {
    assumeNotZeroAddress(feeReceiver);
    IHub.AssetConfig memory oldConfig = hub1.getAssetConfig(_assetId);
    IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(_assetId);

    // if new feeReceiver is different than old one, and is not listed, update the spoke config of old feeReceiver
    if (feeReceiver != oldConfig.feeReceiver) {
      if (!hub1.isSpokeListed(_assetId, feeReceiver)) {
        expectedConfig.feeReceiver = feeReceiver;
        vm.expectCall(
          address(hub1),
          abi.encodeCall(IHub.updateAssetConfig, (_assetId, expectedConfig, new bytes(0)))
        );
      } else {
        // if new fee receiver is different from old one, and is already listed, revert
        vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
      }
    }
    if (expectedConfig.feeReceiver == feeReceiver) {
      vm.expectEmit(address(hubConfigurator));
      emit IHubConfigurator.FeeReceiverUpdated(
        address(hub1),
        _assetUnderlying,
        _assetId,
        oldConfig.feeReceiver,
        feeReceiver
      );
    }
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeReceiver(address(hub1), _assetUnderlying, feeReceiver);

    assertEq(hub1.getAssetConfig(_assetId), expectedConfig);
  }

  function test_updateFeeReceiver_revertsWith_SpokeAlreadyListed() public {
    assertTrue(hub1.isSpokeListed(_assetId, address(spoke1)));

    // set feeReceiver as an existing spoke
    address feeReceiver = address(spoke1);
    vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeReceiver(address(hub1), _assetUnderlying, feeReceiver);
  }

  /// @dev Test update fee receiver and fees can still be withdrawn from old fee receiver
  function test_updateFeeReceiver_WithdrawFromOldSpoke() public {
    assertEq(
      hub1.getAssetConfig(daiAssetId).feeReceiver,
      address(treasurySpoke),
      'current fee receiver matches treasury spoke'
    );

    // Create debt to build up fees on the existing treasury spoke
    _addAndDrawLiquidity(
      hub1,
      daiAssetId,
      bob,
      address(spoke1),
      1000e18,
      bob,
      address(spoke1),
      100e18,
      365 days
    );

    assertGe(hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke)), 0);

    // Change the fee receiver
    address newTreasurySpoke = AaveV4TestOrchestration.deployTestTreasurySpoke({
      owner: HUB_ADMIN,
      salt: bytes32('newTreasurySpoke1')
    });
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeReceiver(address(hub1), address(tokenList.dai), newTreasurySpoke);

    assertEq(
      hub1.getAssetConfig(daiAssetId).feeReceiver,
      newTreasurySpoke,
      'new fee receiver updated'
    );
    assertTrue(
      hub1.getSpokeConfig(daiAssetId, address(treasurySpoke)).active,
      'old fee receiver is not active'
    );

    // Withdraw fees from the old treasury spoke
    uint256 fees = hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke));
    vm.prank(address(treasurySpoke));
    hub1.remove(daiAssetId, fees, TREASURY_ADMIN);

    assertEq(
      hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke)),
      0,
      'old treasury spoke should be empty'
    );

    // Accrue more fees, this time to new fee receiver
    skip(365 days);
    HubActions.mintFeeShares({hub: hub1, assetId: daiAssetId, caller: ADMIN});

    assertGt(
      hub1.getSpokeAddedAssets(daiAssetId, newTreasurySpoke),
      0,
      'new fee receiver should have accrued fees'
    );
    assertEq(
      hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke)),
      0,
      'old fee receiver should be empty'
    );
  }

  /// @dev Test update fee receiver and old fee receiver still accrues fees
  function test_updateFeeReceiver_correctAccruals() public {
    // Ensure current fee receiver is the treasury spoke
    assertEq(
      hub1.getAssetConfig(daiAssetId).feeReceiver,
      address(treasurySpoke),
      'old fee receiver mismatch'
    );

    // Create debt to build up fees on the existing treasury spoke
    _addAndDrawLiquidity(
      hub1,
      daiAssetId,
      bob,
      address(spoke1),
      1000e18,
      bob,
      address(spoke1),
      100e18,
      365 days
    );
    HubActions.mintFeeShares({hub: hub1, assetId: daiAssetId, caller: ADMIN});

    assertGe(hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke)), 0);
    uint256 feeShares = hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke));

    // Change the fee receiver
    address newTreasurySpoke = AaveV4TestOrchestration.deployTestTreasurySpoke({
      owner: HUB_ADMIN,
      salt: bytes32('newTreasurySpoke2')
    });
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeReceiver(address(hub1), address(tokenList.dai), newTreasurySpoke);

    // Ensure fee receiver was updated
    assertEq(
      hub1.getAssetConfig(daiAssetId).feeReceiver,
      newTreasurySpoke,
      'new fee receiver mismatch'
    );

    // Ensure old fee receiver is still active
    assertTrue(
      hub1.getSpokeConfig(daiAssetId, address(treasurySpoke)).active,
      'old fee receiver is not active'
    );

    // Withdraw half the fee shares from the old treasury spoke
    vm.startPrank(address(treasurySpoke));
    hub1.remove(daiAssetId, hub1.previewRemoveByShares(daiAssetId, feeShares / 2), TREASURY_ADMIN);
    vm.stopPrank();

    // Get the remaining fee shares
    feeShares = hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke));

    // Accrue more fees, this time to new fee receiver
    skip(365 days);
    HubActions.mintFeeShares({hub: hub1, assetId: daiAssetId, caller: ADMIN});

    // Check that new fee receiver is getting the fees, and not old treasury spoke
    assertGt(
      hub1.getSpokeAddedAssets(daiAssetId, newTreasurySpoke),
      0,
      'new fee receiver should have accrued fees'
    );
    assertEq(
      hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke)),
      feeShares,
      'old fee receiver should still have same share amount'
    );

    // Now withdraw remaining fee shares from old treasury spoke
    vm.startPrank(address(treasurySpoke));
    hub1.remove(
      daiAssetId,
      hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke)),
      TREASURY_ADMIN
    );
    vm.stopPrank();
    assertEq(
      hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke)),
      0,
      'old fee receiver should be empty'
    );
  }

  function test_updateFeeReceiver_Scenario() public {
    // set same fee receiver
    test_updateFeeReceiver_fuzz(address(treasurySpoke));
    // set new fee receiver
    test_updateFeeReceiver_fuzz(makeAddr('newFeeReceiver'));
  }

  function test_updateFeeConfig_fuzz_revertsWith_AccessManagedUnauthorized(address caller) public {
    _assumeNonHubConfiguratorAdmin(caller);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    hubConfigurator.updateFeeConfig({
      hub: address(hub1),
      underlying: vm.randomAddress(),
      liquidityFee: vm.randomUint(),
      feeReceiver: vm.randomAddress()
    });
  }

  function test_updateFeeConfig_revertsWith_InvalidAddress_spoke() public {
    uint256 assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    address underlying = _hub1Underlying(assetId);
    uint256 liquidityFee = vm.randomUint(1, PercentageMath.PERCENTAGE_FACTOR);

    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeConfig(address(hub1), underlying, liquidityFee, address(0));
  }

  function test_updateFeeConfig_revertsWith_InvalidLiquidityFee() public {
    uint256 assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    address underlying = _hub1Underlying(assetId);
    uint16 liquidityFee = uint16(
      vm.randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max)
    );
    address feeReceiver = hub1.getAssetConfig(assetId).feeReceiver;

    vm.expectRevert(IHub.InvalidLiquidityFee.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeConfig(address(hub1), underlying, liquidityFee, feeReceiver);
  }

  function test_updateFeeConfig_fuzz(
    uint256 assetId_,
    uint16 liquidityFee,
    address feeReceiver
  ) public {
    assetId_ = bound(assetId_, 0, hub1.getAssetCount() - 1);
    liquidityFee = uint16(bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR));
    assumeNotZeroAddress(feeReceiver);
    address underlying = _hub1Underlying(assetId_);

    IHub.AssetConfig memory oldConfig = hub1.getAssetConfig(assetId_);
    IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(assetId_);
    expectedConfig.liquidityFee = liquidityFee;
    // if new fee receiver is different from old one, and is not listed, update the spoke config of old fee receiver
    if (oldConfig.feeReceiver != feeReceiver) {
      if (!hub1.isSpokeListed(assetId_, feeReceiver)) {
        expectedConfig.feeReceiver = feeReceiver;
        vm.expectCall(
          address(hub1),
          abi.encodeCall(IHub.updateAssetConfig, (assetId_, expectedConfig, new bytes(0)))
        );
      } else {
        expectedConfig.liquidityFee = oldConfig.liquidityFee;
        // if new fee receiver is different from old one, and is already listed, revert
        vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
      }
    }
    if (expectedConfig.feeReceiver == feeReceiver) {
      vm.expectEmit(address(hubConfigurator));
      emit IHubConfigurator.LiquidityFeeUpdated(
        address(hub1),
        underlying,
        assetId_,
        oldConfig.liquidityFee,
        liquidityFee
      );
      vm.expectEmit(address(hubConfigurator));
      emit IHubConfigurator.FeeReceiverUpdated(
        address(hub1),
        underlying,
        assetId_,
        oldConfig.feeReceiver,
        feeReceiver
      );
    }
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeConfig(address(hub1), underlying, liquidityFee, feeReceiver);
    assertEq(hub1.getAssetConfig(assetId_), expectedConfig);
  }

  function test_updateFeeConfig_Scenario() public {
    // set same fee receiver and change liquidity fee
    test_updateFeeConfig_fuzz(0, 18_00, address(treasurySpoke));
    // set new fee receiver and liquidity fee
    test_updateFeeConfig_fuzz(0, 4_00, makeAddr('newFeeReceiver'));
    // set non-zero fee receiver
    test_updateFeeConfig_fuzz(0, 0, makeAddr('newFeeReceiver2'));
  }

  function test_updateInterestRateStrategy_fuzz_revertsWith_AccessManagedUnauthorized(
    address caller
  ) public {
    _assumeNonHubConfiguratorAdmin(caller);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    hubConfigurator.updateInterestRateStrategy(
      address(hub1),
      vm.randomAddress(),
      vm.randomAddress(),
      _encodedIrData
    );
  }

  function test_updateInterestRateStrategy() public {
    address newIrStrategy = address(new AssetInterestRateStrategy(address(hub1)));

    IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(_assetId);
    address oldIrStrategy = expectedConfig.irStrategy;
    IAssetInterestRateStrategy.InterestRateData memory oldIrData = IAssetInterestRateStrategy(
      oldIrStrategy
    ).getInterestRateData(_assetId);
    expectedConfig.irStrategy = newIrStrategy;

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateAssetConfig, (_assetId, expectedConfig, _encodedIrData))
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.InterestRateStrategyUpdated(
      address(hub1),
      _assetUnderlying,
      _assetId,
      oldIrStrategy,
      newIrStrategy
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.InterestRateDataUpdated(
      address(hub1),
      _assetUnderlying,
      _assetId,
      oldIrData,
      abi.decode(_encodedIrData, (IAssetInterestRateStrategy.InterestRateData))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateInterestRateStrategy(
      address(hub1),
      _assetUnderlying,
      newIrStrategy,
      _encodedIrData
    );

    assertEq(hub1.getAssetConfig(_assetId), expectedConfig);
  }

  function test_updateInterestRateStrategy_revertsWith_InvalidAddress_irStrategy() public {
    _assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    _assetUnderlying = _hub1Underlying(_assetId);

    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateInterestRateStrategy(
      address(hub1),
      _assetUnderlying,
      address(0),
      _encodedIrData
    );
  }

  function test_updateInterestRateStrategy_revertsWith_DrawnRateStrategyReverts() public {
    _assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    _assetUnderlying = _hub1Underlying(_assetId);
    address irStrategy = makeAddr('newDrawnRateStrategy');

    vm.expectRevert();
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateInterestRateStrategy(
      address(hub1),
      _assetUnderlying,
      irStrategy,
      _encodedIrData
    );
  }

  function test_updateInterestRateStrategy_revertsWith_InvalidInterestRateStrategy() public {
    vm.expectRevert(IHub.InvalidInterestRateStrategy.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateInterestRateStrategy(
      address(hub1),
      _assetUnderlying,
      address(irStrategy),
      _encodedIrData
    );
  }

  function test_updateReinvestmentController_fuzz_revertsWith_AccessManagedUnauthorized(
    address caller
  ) public {
    _assumeNonHubConfiguratorAdmin(caller);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    hubConfigurator.updateReinvestmentController(
      address(hub1),
      vm.randomAddress(),
      vm.randomAddress()
    );
  }

  function test_updateReinvestmentController() public {
    address reinvestmentController = makeAddr('newReinvestmentController');
    IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(_assetId);
    address oldReinvestmentController = expectedConfig.reinvestmentController;
    expectedConfig.reinvestmentController = reinvestmentController;
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateAssetConfig, (_assetId, expectedConfig, new bytes(0)))
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.ReinvestmentControllerUpdated(
      address(hub1),
      _assetUnderlying,
      _assetId,
      oldReinvestmentController,
      reinvestmentController
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateReinvestmentController(
      address(hub1),
      _assetUnderlying,
      reinvestmentController
    );

    assertEq(hub1.getAssetConfig(_assetId), expectedConfig);
  }

  function test_resetAssetCaps_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.resetAssetCaps(address(hub1), _assetUnderlying);
  }

  function test_resetAssetCaps() public {
    assertEq(hub1.getSpokeCount(_assetId), spokeAddresses.length, 'spoke count');
    for (uint256 i; i < spokeAddresses.length; i++) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, spokeAddresses[i]);
      spokeConfig.addCap = 0;
      spokeConfig.drawCap = 0;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spokeAddresses[i], spokeConfig))
      );

      riskPremiumThresholdsPerSpoke[spokeAddresses[i]] = spokeConfig.riskPremiumThreshold;
    }
    for (uint256 i; i < spokeAddresses.length; i++) {
      _expectSpokeCapsEvents(_assetId, hub1.getSpokeAddress(_assetId, i), 0, 0);
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.resetAssetCaps(address(hub1), _assetUnderlying);

    for (uint256 i; i < spokeAddresses.length; i++) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, spokeAddresses[i]);
      assertEq(spokeConfig.addCap, 0);
      assertEq(spokeConfig.drawCap, 0);
      assertEq(spokeConfig.riskPremiumThreshold, riskPremiumThresholdsPerSpoke[spokeAddresses[i]]);
    }
  }

  function test_deactivateAsset_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.deactivateAsset(address(hub1), _assetUnderlying);
  }

  function test_deactivateAsset() public {
    assertEq(hub1.getSpokeCount(_assetId), spokeAddresses.length, 'spoke count');
    for (uint256 i; i < spokeAddresses.length; i++) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, spokeAddresses[i]);
      spokeConfig.active = false;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spokeAddresses[i], spokeConfig))
      );
    }
    for (uint256 i; i < spokeAddresses.length; i++) {
      _expectSpokeActiveEvent(_assetId, hub1.getSpokeAddress(_assetId, i), false);
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.deactivateAsset(address(hub1), _assetUnderlying);

    for (uint256 i; i < spokeAddresses.length; i++) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, spokeAddresses[i]);
      assertEq(spokeConfig.active, false);
    }
  }

  function test_haltAsset_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);
  }

  function test_haltAsset() public {
    assertEq(hub1.getSpokeCount(_assetId), spokeAddresses.length, 'spoke count');
    for (uint256 i; i < spokeAddresses.length; i++) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, spokeAddresses[i]);
      spokeConfig.halted = true;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spokeAddresses[i], spokeConfig))
      );
    }
    for (uint256 i; i < spokeAddresses.length; i++) {
      _expectSpokeHaltedEvent(_assetId, hub1.getSpokeAddress(_assetId, i), true);
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);

    for (uint256 i; i < spokeAddresses.length; i++) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, spokeAddresses[i]);
      assertEq(spokeConfig.halted, true);
    }
  }

  function test_addSpoke_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    IHub.SpokeConfig memory spokeConfig;
    hubConfigurator.addSpoke(address(hub1), vm.randomAddress(), vm.randomAddress(), spokeConfig);
  }

  function test_addSpoke() public {
    address newSpoke = makeAddr('newSpoke');

    IHub.SpokeConfig memory daiSpokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: 1,
      drawCap: 2,
      riskPremiumThreshold: 22
    });

    vm.expectEmit(address(hub1));
    emit IHub.AddSpoke(daiAssetId, newSpoke);
    _expectAddSpokeEvents(daiAssetId, newSpoke, daiSpokeConfig);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.addSpoke(address(hub1), newSpoke, address(tokenList.dai), daiSpokeConfig);

    assertEq(hub1.getSpokeConfig(daiAssetId, newSpoke), daiSpokeConfig);
  }

  function test_addSpoke_inactiveHalted() public {
    address newSpoke = makeAddr('newSpoke');

    IHub.SpokeConfig memory daiSpokeConfig = IHub.SpokeConfig({
      active: false,
      halted: true,
      addCap: 0,
      drawCap: 0,
      riskPremiumThreshold: 0
    });

    vm.expectEmit(address(hub1));
    emit IHub.AddSpoke(daiAssetId, newSpoke);
    _expectAddSpokeEvents(daiAssetId, newSpoke, daiSpokeConfig);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.addSpoke(address(hub1), newSpoke, address(tokenList.dai), daiSpokeConfig);

    assertEq(hub1.getSpokeConfig(daiAssetId, newSpoke), daiSpokeConfig);
  }

  function test_addSpokeToAssets_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.addSpokeToAssets(
      address(hub1),
      vm.randomAddress(),
      new address[](0),
      new IHub.SpokeConfig[](0)
    );
  }

  function test_addSpokeToAssets_revertsWith_MismatchedConfigs() public {
    address[] memory underlyings = new address[](2);
    underlyings[0] = address(tokenList.dai);
    underlyings[1] = address(tokenList.weth);

    IHub.SpokeConfig[] memory spokeConfigs = new IHub.SpokeConfig[](3);
    spokeConfigs[0] = IHub.SpokeConfig({
      addCap: 1,
      drawCap: 2,
      active: true,
      halted: false,
      riskPremiumThreshold: 0
    });
    spokeConfigs[1] = IHub.SpokeConfig({
      addCap: 3,
      drawCap: 4,
      active: true,
      halted: false,
      riskPremiumThreshold: 0
    });
    spokeConfigs[2] = IHub.SpokeConfig({
      addCap: 5,
      drawCap: 6,
      active: true,
      halted: false,
      riskPremiumThreshold: 0
    });

    vm.expectRevert(IHubConfigurator.MismatchedConfigs.selector);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.addSpokeToAssets(address(hub1), spoke, underlyings, spokeConfigs);
  }

  function test_addSpokeToAssets_revertsWith_AssetNotListed() public {
    address newSpoke = makeAddr('newSpoke');
    address[] memory underlyings = new address[](2);
    underlyings[0] = address(tokenList.dai);
    underlyings[1] = makeAddr('unlistedUnderlying');

    IHub.SpokeConfig[] memory spokeConfigs = new IHub.SpokeConfig[](2);
    spokeConfigs[0] = IHub.SpokeConfig({
      addCap: 1,
      drawCap: 2,
      active: true,
      halted: false,
      riskPremiumThreshold: 0
    });
    spokeConfigs[1] = spokeConfigs[0];

    vm.expectRevert(IHub.AssetNotListed.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.addSpokeToAssets(address(hub1), newSpoke, underlyings, spokeConfigs);

    assertFalse(hub1.isSpokeListed(daiAssetId, newSpoke));
  }

  function test_addSpokeToAssets() public {
    address newSpoke = makeAddr('newSpoke');

    address[] memory underlyings = new address[](2);
    underlyings[0] = address(tokenList.dai);
    underlyings[1] = address(tokenList.weth);

    IHub.SpokeConfig memory daiSpokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: 1,
      drawCap: 2,
      riskPremiumThreshold: 0
    });
    IHub.SpokeConfig memory wethSpokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: 3,
      drawCap: 4,
      riskPremiumThreshold: 0
    });

    IHub.SpokeConfig[] memory spokeConfigs = new IHub.SpokeConfig[](2);
    spokeConfigs[0] = daiSpokeConfig;
    spokeConfigs[1] = wethSpokeConfig;

    vm.expectEmit(address(hub1));
    emit IHub.AddSpoke(daiAssetId, newSpoke);
    _expectAddSpokeEvents(daiAssetId, newSpoke, daiSpokeConfig);
    vm.expectEmit(address(hub1));
    emit IHub.AddSpoke(wethAssetId, newSpoke);
    _expectAddSpokeEvents(wethAssetId, newSpoke, wethSpokeConfig);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.addSpokeToAssets(address(hub1), newSpoke, underlyings, spokeConfigs);

    IHub.SpokeConfig memory daiSpokeData = hub1.getSpokeConfig(daiAssetId, newSpoke);
    IHub.SpokeConfig memory wethSpokeData = hub1.getSpokeConfig(wethAssetId, newSpoke);

    assertEq(daiSpokeData, daiSpokeConfig);
    assertEq(wethSpokeData, wethSpokeConfig);
  }

  function test_updateSpokeHalted_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.updateSpokeHalted(address(hub1), _assetUnderlying, spokeAddresses[0], false);
  }

  function test_updateSpokeHalted() public {
    IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(_assetId, spoke);
    for (uint256 i = 0; i < 2; ++i) {
      bool halted = (i == 0) ? false : true;
      expectedSpokeConfig.halted = halted;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spoke, expectedSpokeConfig))
      );
      _expectSpokeHaltedEvent(_assetId, spoke, halted);
      vm.prank(HUB_CONFIGURATOR_ADMIN);
      hubConfigurator.updateSpokeHalted(address(hub1), _assetUnderlying, spoke, halted);
      assertEq(hub1.getSpokeConfig(_assetId, spoke), expectedSpokeConfig);
    }
  }

  function test_updateSpokeActive_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.updateSpokeActive(address(hub1), _assetUnderlying, spokeAddresses[0], true);
  }

  function test_updateSpokeActive() public {
    IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(_assetId, spoke);
    for (uint256 i = 0; i < 2; ++i) {
      bool active = (i == 0) ? false : true;
      expectedSpokeConfig.active = active;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spoke, expectedSpokeConfig))
      );
      _expectSpokeActiveEvent(_assetId, spoke, active);
      vm.prank(HUB_CONFIGURATOR_ADMIN);
      hubConfigurator.updateSpokeActive(address(hub1), _assetUnderlying, spoke, active);
      assertEq(hub1.getSpokeConfig(_assetId, spoke), expectedSpokeConfig);
    }
  }

  function test_updateSpokeAddCap_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.updateSpokeAddCap(address(hub1), _assetUnderlying, spokeAddresses[0], 100);
  }

  function test_updateSpokeAddCap() public {
    uint40 newAddCap = 100;
    IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(_assetId, spoke);
    uint256 oldAddCap = expectedSpokeConfig.addCap;
    expectedSpokeConfig.addCap = newAddCap;
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spoke, expectedSpokeConfig))
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.SpokeAddCapUpdated(
      address(hub1),
      _assetUnderlying,
      _assetId,
      spoke,
      oldAddCap,
      newAddCap
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeAddCap(address(hub1), _assetUnderlying, spoke, newAddCap);
    assertEq(hub1.getSpokeConfig(_assetId, spoke), expectedSpokeConfig);
  }

  function test_updateSpokeDrawCap_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.updateSpokeDrawCap(address(hub1), _assetUnderlying, spokeAddresses[0], 100);
  }

  function test_updateSpokeDrawCap() public {
    uint40 newDrawCap = 100;
    IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(_assetId, spoke);
    uint256 oldDrawCap = expectedSpokeConfig.drawCap;
    expectedSpokeConfig.drawCap = newDrawCap;
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spoke, expectedSpokeConfig))
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.SpokeDrawCapUpdated(
      address(hub1),
      _assetUnderlying,
      _assetId,
      spoke,
      oldDrawCap,
      newDrawCap
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeDrawCap(address(hub1), _assetUnderlying, spoke, newDrawCap);
    assertEq(hub1.getSpokeConfig(_assetId, spoke), expectedSpokeConfig);
  }

  function test_updateSpokeRiskPremiumThreshold_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.updateSpokeRiskPremiumThreshold(
      address(hub1),
      _assetUnderlying,
      spokeAddresses[0],
      100
    );
  }

  function test_updateSpokeRiskPremiumThreshold() public {
    uint24 newRiskPremiumThreshold = 100;
    IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(_assetId, spoke);
    uint256 oldRiskPremiumThreshold = expectedSpokeConfig.riskPremiumThreshold;
    expectedSpokeConfig.riskPremiumThreshold = newRiskPremiumThreshold;
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spoke, expectedSpokeConfig))
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.SpokeRiskPremiumThresholdUpdated(
      address(hub1),
      _assetUnderlying,
      _assetId,
      spoke,
      oldRiskPremiumThreshold,
      newRiskPremiumThreshold
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeRiskPremiumThreshold(
      address(hub1),
      _assetUnderlying,
      spoke,
      newRiskPremiumThreshold
    );
    assertEq(hub1.getSpokeConfig(_assetId, spoke), expectedSpokeConfig);
  }

  function test_updateSpokeCaps_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.updateSpokeCaps(address(hub1), _assetUnderlying, spokeAddresses[0], 100, 100);
  }

  function test_updateSpokeCaps() public {
    uint40 newAddCap = 100;
    uint40 newDrawCap = 200;
    IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(_assetId, spoke);
    expectedSpokeConfig.addCap = newAddCap;
    expectedSpokeConfig.drawCap = newDrawCap;
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spoke, expectedSpokeConfig))
    );
    _expectSpokeCapsEvents(_assetId, spoke, newAddCap, newDrawCap);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeCaps(address(hub1), _assetUnderlying, spoke, newAddCap, newDrawCap);
    assertEq(hub1.getSpokeConfig(_assetId, spoke), expectedSpokeConfig);
  }

  function test_deactivateSpoke_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.deactivateSpoke(address(hub1), address(spoke3));
  }

  function test_deactivateSpoke() public {
    /// @dev Spoke3 is listed on hub1 on 4 assets: dai, weth, wbtc, usdx
    assertGt(hub1.getAssetCount(), 4, 'hub1 has less than 4 assets listed');

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      vm.expectCall(address(hub1), abi.encodeCall(IHub.isSpokeListed, (assetId, address(spoke3))));

      IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(assetId, address(spoke3));
      expectedSpokeConfig.active = false;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (assetId, address(spoke3), expectedSpokeConfig))
      );
      _expectSpokeActiveEvent(assetId, address(spoke3), false);
    }

    for (uint256 assetId = 4; assetId < hub1.getAssetCount(); ++assetId) {
      assertFalse(hub1.isSpokeListed(assetId, address(spoke3)));
      vm.expectCall(address(hub1), abi.encodeCall(IHub.isSpokeListed, (assetId, address(spoke3))));
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.deactivateSpoke(address(hub1), address(spoke3));

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(assetId, address(spoke3));
      assertEq(spokeConfig.active, false);
    }
  }

  function test_haltSpoke_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.haltSpoke(address(hub1), address(spoke3));
  }

  function test_haltSpoke() public {
    /// @dev Spoke3 is listed on hub1 on 4 assets: dai, weth, wbtc, usdx
    assertGt(hub1.getAssetCount(), 4, 'hub1 has less than 4 assets listed');

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      vm.expectCall(address(hub1), abi.encodeCall(IHub.isSpokeListed, (assetId, address(spoke3))));

      IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(assetId, address(spoke3));
      expectedSpokeConfig.halted = true;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (assetId, address(spoke3), expectedSpokeConfig))
      );
      _expectSpokeHaltedEvent(assetId, address(spoke3), true);
    }

    for (uint256 assetId = 4; assetId < hub1.getAssetCount(); ++assetId) {
      assertFalse(hub1.isSpokeListed(assetId, address(spoke3)));
      vm.expectCall(address(hub1), abi.encodeCall(IHub.isSpokeListed, (assetId, address(spoke3))));
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltSpoke(address(hub1), address(spoke3));

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(assetId, address(spoke3));
      assertEq(spokeConfig.halted, true);
    }
  }

  function test_resetSpokeCaps_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.resetSpokeCaps(address(hub1), address(spoke3));
  }

  function test_resetSpokeCaps() public {
    /// @dev Spoke3 is listed on hub1 on 4 assets: dai, weth, wbtc, usdx
    assertGt(hub1.getAssetCount(), 4, 'hub1 has less than 4 assets listed');

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      vm.expectCall(address(hub1), abi.encodeCall(IHub.isSpokeListed, (assetId, address(spoke3))));

      IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(assetId, address(spoke3));
      expectedSpokeConfig.addCap = 0;
      expectedSpokeConfig.drawCap = 0;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (assetId, address(spoke3), expectedSpokeConfig))
      );
      _expectSpokeCapsEvents(assetId, address(spoke3), 0, 0);

      riskPremiumThresholdsPerAsset[assetId] = expectedSpokeConfig.riskPremiumThreshold;
    }

    for (uint256 assetId = 4; assetId < hub1.getAssetCount(); ++assetId) {
      assertFalse(hub1.isSpokeListed(assetId, address(spoke3)));
      vm.expectCall(address(hub1), abi.encodeCall(IHub.isSpokeListed, (assetId, address(spoke3))));
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.resetSpokeCaps(address(hub1), address(spoke3));

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(assetId, address(spoke3));
      assertEq(spokeConfig.addCap, 0);
      assertEq(spokeConfig.drawCap, 0);
      assertEq(spokeConfig.riskPremiumThreshold, riskPremiumThresholdsPerAsset[assetId]);
    }
  }

  function test_updateInterestRateData_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.updateInterestRateData(address(hub1), _assetUnderlying, vm.randomBytes(32));
  }

  function test_updateInterestRateData() public {
    IAssetInterestRateStrategy.InterestRateData memory newIrData = IAssetInterestRateStrategy
      .InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseDrawnRate: 5_00, // 5.00%
        rateGrowthBeforeOptimal: 5_00, // 5.00%
        rateGrowthAfterOptimal: 5_00 // 5.00%
      });
    IAssetInterestRateStrategy.InterestRateData memory oldIrData = irStrategy.getInterestRateData(
      _assetId
    );

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.setInterestRateData, (_assetId, abi.encode(newIrData)))
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.InterestRateDataUpdated(
      address(hub1),
      _assetUnderlying,
      _assetId,
      oldIrData,
      newIrData
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateInterestRateData(address(hub1), _assetUnderlying, abi.encode(newIrData));

    assertEq(irStrategy.getInterestRateData(_assetId), newIrData);
  }

  function test_updateInterestRateData_emitsDistinctOldAndNewData() public {
    IAssetInterestRateStrategy.InterestRateData memory newIrData = _distinctIrData();
    assertEq(irStrategy.getInterestRateData(_assetId), _defaultIrData);

    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.InterestRateDataUpdated(
      address(hub1),
      _assetUnderlying,
      _assetId,
      _defaultIrData,
      newIrData
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateInterestRateData(address(hub1), _assetUnderlying, abi.encode(newIrData));

    assertEq(irStrategy.getInterestRateData(_assetId), newIrData);
  }

  function test_updateInterestRateStrategy_emitsDistinctOldAndNewData() public {
    address oldIrStrategy = hub1.getAssetConfig(_assetId).irStrategy;
    address newIrStrategy = address(new AssetInterestRateStrategy(address(hub1)));
    IAssetInterestRateStrategy.InterestRateData memory newIrData = _distinctIrData();
    assertEq(
      IAssetInterestRateStrategy(oldIrStrategy).getInterestRateData(_assetId),
      _defaultIrData
    );

    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.InterestRateStrategyUpdated(
      address(hub1),
      _assetUnderlying,
      _assetId,
      oldIrStrategy,
      newIrStrategy
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.InterestRateDataUpdated(
      address(hub1),
      _assetUnderlying,
      _assetId,
      _defaultIrData,
      newIrData
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateInterestRateStrategy(
      address(hub1),
      _assetUnderlying,
      newIrStrategy,
      abi.encode(newIrData)
    );

    assertEq(hub1.getAssetConfig(_assetId).irStrategy, newIrStrategy);
    assertEq(IAssetInterestRateStrategy(newIrStrategy).getInterestRateData(_assetId), newIrData);
  }

  function test_revertsWith_AssetNotListed() public {
    address unlisted = makeAddr('unlistedUnderlying');
    assertFalse(hub1.isUnderlyingListed(unlisted));
    IHub.SpokeConfig memory spokeConfig;

    bytes[] memory calls = new bytes[](16);
    calls[0] = abi.encodeCall(IHubConfigurator.updateLiquidityFee, (address(hub1), unlisted, 1));
    calls[1] = abi.encodeCall(
      IHubConfigurator.updateFeeReceiver,
      (address(hub1), unlisted, makeAddr('newFeeReceiver'))
    );
    calls[2] = abi.encodeCall(
      IHubConfigurator.updateFeeConfig,
      (address(hub1), unlisted, 1, makeAddr('newFeeReceiver'))
    );
    calls[3] = abi.encodeCall(
      IHubConfigurator.updateInterestRateStrategy,
      (address(hub1), unlisted, address(irStrategy), _encodedIrData)
    );
    calls[4] = abi.encodeCall(
      IHubConfigurator.updateReinvestmentController,
      (address(hub1), unlisted, makeAddr('newReinvestmentController'))
    );
    calls[5] = abi.encodeCall(
      IHubConfigurator.updateInterestRateData,
      (address(hub1), unlisted, _encodedIrData)
    );
    calls[6] = abi.encodeCall(IHubConfigurator.resetAssetCaps, (address(hub1), unlisted));
    calls[7] = abi.encodeCall(IHubConfigurator.deactivateAsset, (address(hub1), unlisted));
    calls[8] = abi.encodeCall(IHubConfigurator.haltAsset, (address(hub1), unlisted));
    calls[9] = abi.encodeCall(
      IHubConfigurator.addSpoke,
      (address(hub1), makeAddr('newSpoke'), unlisted, spokeConfig)
    );
    calls[10] = abi.encodeCall(
      IHubConfigurator.updateSpokeActive,
      (address(hub1), unlisted, spoke, false)
    );
    calls[11] = abi.encodeCall(
      IHubConfigurator.updateSpokeHalted,
      (address(hub1), unlisted, spoke, true)
    );
    calls[12] = abi.encodeCall(
      IHubConfigurator.updateSpokeAddCap,
      (address(hub1), unlisted, spoke, 1)
    );
    calls[13] = abi.encodeCall(
      IHubConfigurator.updateSpokeDrawCap,
      (address(hub1), unlisted, spoke, 1)
    );
    calls[14] = abi.encodeCall(
      IHubConfigurator.updateSpokeRiskPremiumThreshold,
      (address(hub1), unlisted, spoke, 1)
    );
    calls[15] = abi.encodeCall(
      IHubConfigurator.updateSpokeCaps,
      (address(hub1), unlisted, spoke, 1, 1)
    );

    for (uint256 i; i < calls.length; ++i) {
      vm.prank(HUB_CONFIGURATOR_ADMIN);
      (bool ok, bytes memory ret) = address(hubConfigurator).call(calls[i]);
      assertFalse(ok);
      assertEq(ret, abi.encodeWithSelector(IHub.AssetNotListed.selector));
    }
  }

  function test_implementation_initialize_revertsWith_InvalidInitialization() public {
    HubConfiguratorInstance impl = HubConfiguratorInstance(
      _getImplementationAddress(address(hubConfigurator))
    );
    assertEq(_getProxyInitializedVersion(address(impl)), type(uint64).max);

    address authority = hub1.authority();

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    impl.initialize(authority);
  }

  function test_proxy_initialize_revertsWith_InvalidInitialization() public {
    assertEq(_getProxyInitializedVersion(address(hubConfigurator)), 1);
    address authority = hub1.authority();

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    HubConfiguratorInstance(address(hubConfigurator)).initialize(authority);
  }

  function test_revision() public view {
    assertEq(HubConfiguratorInstance(address(hubConfigurator)).HUB_CONFIGURATOR_REVISION(), 1);
  }

  function test_proxy_constructor_revertsWith_InvalidAddress() public {
    address impl = address(new HubConfiguratorInstance());

    vm.expectRevert(IHubConfigurator.InvalidAddress.selector);
    new TransparentUpgradeableProxy(
      impl,
      ADMIN,
      abi.encodeCall(HubConfiguratorInstance.initialize, (address(0)))
    );
  }

  function test_initialize_revertsWith_InvalidAddress() public {
    HubConfiguratorInstance proxy = HubConfiguratorInstance(
      address(new TransparentUpgradeableProxy(address(new HubConfiguratorInstance()), ADMIN, ''))
    );
    assertEq(_getProxyInitializedVersion(address(proxy)), 0);

    vm.expectRevert(IHubConfigurator.InvalidAddress.selector);
    proxy.initialize(address(0));

    proxy.initialize(hub1.authority());
    assertEq(_getProxyInitializedVersion(address(proxy)), 1);
    assertEq(IAccessManaged(address(proxy)).authority(), hub1.authority());
  }

  function _expectAddAssetEvents(
    address underlying,
    uint256 assetId,
    address feeReceiver,
    uint256 liquidityFee,
    address irStrategy,
    IAssetInterestRateStrategy.InterestRateData memory irData
  ) internal {
    IAssetInterestRateStrategy.InterestRateData memory emptyIrData;
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.LiquidityFeeUpdated(address(hub1), underlying, assetId, 0, liquidityFee);
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.FeeReceiverUpdated(
      address(hub1),
      underlying,
      assetId,
      address(0),
      feeReceiver
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.InterestRateStrategyUpdated(
      address(hub1),
      underlying,
      assetId,
      address(0),
      irStrategy
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.InterestRateDataUpdated(
      address(hub1),
      underlying,
      assetId,
      emptyIrData,
      irData
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.ReinvestmentControllerUpdated(
      address(hub1),
      underlying,
      assetId,
      address(0),
      address(0)
    );
  }

  function _expectAddSpokeEvents(
    uint256 assetId,
    address spoke_,
    IHub.SpokeConfig memory config
  ) internal {
    address underlying = _hub1Underlying(assetId);
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.SpokeAddCapUpdated(
      address(hub1),
      underlying,
      assetId,
      spoke_,
      0,
      config.addCap
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.SpokeDrawCapUpdated(
      address(hub1),
      underlying,
      assetId,
      spoke_,
      0,
      config.drawCap
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.SpokeRiskPremiumThresholdUpdated(
      address(hub1),
      underlying,
      assetId,
      spoke_,
      0,
      config.riskPremiumThreshold
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.SpokeActiveUpdated(
      address(hub1),
      underlying,
      assetId,
      spoke_,
      false,
      config.active
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.SpokeHaltedUpdated(
      address(hub1),
      underlying,
      assetId,
      spoke_,
      false,
      config.halted
    );
  }

  /// @dev Reads the old values from the current hub state, so call before the configurator call.
  function _expectSpokeCapsEvents(
    uint256 assetId,
    address spoke_,
    uint256 newAddCap,
    uint256 newDrawCap
  ) internal {
    IHub.SpokeConfig memory oldConfig = hub1.getSpokeConfig(assetId, spoke_);
    address underlying = _hub1Underlying(assetId);
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.SpokeAddCapUpdated(
      address(hub1),
      underlying,
      assetId,
      spoke_,
      oldConfig.addCap,
      newAddCap
    );
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.SpokeDrawCapUpdated(
      address(hub1),
      underlying,
      assetId,
      spoke_,
      oldConfig.drawCap,
      newDrawCap
    );
  }

  /// @dev Reads the old value from the current hub state, so call before the configurator call.
  function _expectSpokeActiveEvent(uint256 assetId, address spoke_, bool newActive) internal {
    address underlying = _hub1Underlying(assetId);
    bool oldActive = hub1.getSpokeConfig(assetId, spoke_).active;
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.SpokeActiveUpdated(
      address(hub1),
      underlying,
      assetId,
      spoke_,
      oldActive,
      newActive
    );
  }

  /// @dev Reads the old value from the current hub state, so call before the configurator call.
  function _expectSpokeHaltedEvent(uint256 assetId, address spoke_, bool newHalted) internal {
    address underlying = _hub1Underlying(assetId);
    bool oldHalted = hub1.getSpokeConfig(assetId, spoke_).halted;
    vm.expectEmit(address(hubConfigurator));
    emit IHubConfigurator.SpokeHaltedUpdated(
      address(hub1),
      underlying,
      assetId,
      spoke_,
      oldHalted,
      newHalted
    );
  }

  function _distinctIrData()
    internal
    pure
    returns (IAssetInterestRateStrategy.InterestRateData memory)
  {
    return
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 80_00, // 80.00%
        baseDrawnRate: 4_00, // 4.00%
        rateGrowthBeforeOptimal: 6_00, // 6.00%
        rateGrowthAfterOptimal: 7_00 // 7.00%
      });
  }

  function _hub1Underlying(uint256 assetId) internal view returns (address underlying) {
    (underlying, ) = hub1.getAssetUnderlyingAndDecimals(assetId);
  }

  function _addAsset(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    uint256 liquidityFee,
    address irStrategy,
    bytes memory encodedIrData
  ) internal returns (uint256) {
    if (fetchErc20Decimals) {
      _mockDecimals(underlying, decimals);
      return
        hubConfigurator.addAsset(
          address(hub1),
          underlying,
          feeReceiver,
          liquidityFee,
          irStrategy,
          encodedIrData
        );
    } else {
      return
        hubConfigurator.addAssetWithDecimals(
          address(hub1),
          underlying,
          decimals,
          feeReceiver,
          liquidityFee,
          irStrategy,
          encodedIrData
        );
    }
  }

  function _assumeNonHubConfiguratorAdmin(address caller) internal view {
    vm.assume(
      caller != HUB_CONFIGURATOR_ADMIN &&
        caller != address(accessManager) &&
        caller != ADMIN &&
        caller != HUB_ADMIN
    );
  }
}
