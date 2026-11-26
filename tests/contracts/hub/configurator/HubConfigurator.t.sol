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

  function test_zeroAssetCaps_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);
  }

  function test_zeroAssetCaps_savesCaps() public {
    (uint256[] memory addCaps, uint256[] memory drawCaps) = _capsOfAsset(_assetId);

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);

    for (uint256 i; i < addCaps.length; ++i) {
      assertTrue(addCaps[i] != 0 || drawCaps[i] != 0, 'caps zero before zeroAssetCaps');
      _assertSavedCaps(
        _assetId,
        hub1.getSpokeAddress(_assetId, i),
        addCaps[i],
        drawCaps[i],
        true,
        false
      );
      _assertCaps(_assetId, hub1.getSpokeAddress(_assetId, i), 0, 0);
    }
  }

  function test_zeroAssetCaps_skipsSpokesWithZeroCaps() public {
    address zeroCapsSpoke = spokeAddresses[0];
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeCaps(address(hub1), _assetUnderlying, zeroCapsSpoke, 0, 0);

    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, zeroCapsSpoke);
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, zeroCapsSpoke, spokeConfig)),
      0
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);

    _assertSavedCaps(_assetId, zeroCapsSpoke, 0, 0, false, false);
  }

  function test_restoreAssetCaps_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);
  }

  function test_restoreAssetCaps() public {
    (uint256[] memory addCaps, uint256[] memory drawCaps) = _capsOfAsset(_assetId);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);

    for (uint256 i; i < addCaps.length; ++i) {
      address spokeAddress = hub1.getSpokeAddress(_assetId, i);
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, spokeAddress);
      spokeConfig.addCap = addCaps[i].toUint40();
      spokeConfig.drawCap = drawCaps[i].toUint40();
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spokeAddress, spokeConfig))
      );
      _expectSpokeCapsEvents(_assetId, spokeAddress, addCaps[i], drawCaps[i]);
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);

    _assertCapsOfAsset(_assetId, addCaps, drawCaps);
    for (uint256 i; i < addCaps.length; ++i) {
      _assertSavedCaps(_assetId, hub1.getSpokeAddress(_assetId, i), 0, 0, false, false);
    }
  }

  function test_restoreAssetCaps_afterRepeatedZeroAssetCaps() public {
    (uint256[] memory addCaps, uint256[] memory drawCaps) = _capsOfAsset(_assetId);

    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);
    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);
    vm.stopPrank();

    _assertCapsOfAsset(_assetId, addCaps, drawCaps);
  }

  function test_restoreAssetCaps_restoresSingleNonZeroCap() public {
    address addCapSpoke = spokeAddresses[0];
    address drawCapSpoke = spokeAddresses[1];

    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeCaps(address(hub1), _assetUnderlying, addCapSpoke, 100, 0);
    hubConfigurator.updateSpokeCaps(address(hub1), _assetUnderlying, drawCapSpoke, 0, 200);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);
    _assertSavedCaps(_assetId, addCapSpoke, 100, 0, true, false);
    _assertSavedCaps(_assetId, drawCapSpoke, 0, 200, true, false);
    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);
    vm.stopPrank();

    _assertCaps(_assetId, addCapSpoke, 100, 0);
    _assertCaps(_assetId, drawCapSpoke, 0, 200);
  }

  function test_restoreAssetCaps_keepsCapsZeroBeforeZeroAssetCaps() public {
    address zeroCapsSpoke = spokeAddresses[0];
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeCaps(address(hub1), _assetUnderlying, zeroCapsSpoke, 0, 0);
    (uint256[] memory addCaps, uint256[] memory drawCaps) = _capsOfAsset(_assetId);

    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);
    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);
    vm.stopPrank();

    _assertCaps(_assetId, zeroCapsSpoke, 0, 0);
    _assertCapsOfAsset(_assetId, addCaps, drawCaps);
  }

  function test_restoreAssetCaps_keepsCapsSetThroughCapSetters() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);
    hubConfigurator.updateSpokeCaps(address(hub1), _assetUnderlying, spokeAddresses[0], 1, 2);
    hubConfigurator.updateSpokeAddCap(address(hub1), _assetUnderlying, spokeAddresses[1], 3);
    hubConfigurator.updateSpokeDrawCap(address(hub1), _assetUnderlying, spokeAddresses[2], 4);
    vm.stopPrank();

    for (uint256 i; i < 3; ++i) {
      _assertSavedCaps(_assetId, spokeAddresses[i], 0, 0, false, false);
    }
    vm.expectCall(
      address(hub1),
      abi.encodeWithSelector(IHub.updateSpokeConfig.selector, _assetId, spokeAddresses[0]),
      0
    );
    vm.expectCall(
      address(hub1),
      abi.encodeWithSelector(IHub.updateSpokeConfig.selector, _assetId, spokeAddresses[1]),
      0
    );
    vm.expectCall(
      address(hub1),
      abi.encodeWithSelector(IHub.updateSpokeConfig.selector, _assetId, spokeAddresses[2]),
      0
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);

    _assertCaps(_assetId, spokeAddresses[0], 1, 2);
    _assertCaps(_assetId, spokeAddresses[1], 3, 0);
    _assertCaps(_assetId, spokeAddresses[2], 0, 4);
  }

  function test_restoreAssetCaps_keepsCapsZeroThroughZeroSpokeCaps() public {
    address spokeAddress = address(spoke1);
    (uint256[] memory addCaps, uint256[] memory drawCaps) = _capsOfAsset(_assetId);
    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, spokeAddress);

    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);
    hubConfigurator.zeroSpokeCaps(address(hub1), spokeAddress);
    _assertSavedCaps(_assetId, spokeAddress, spokeConfig.addCap, spokeConfig.drawCap, true, true);
    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);
    vm.stopPrank();

    for (uint256 i; i < addCaps.length; ++i) {
      address restoredSpoke = hub1.getSpokeAddress(_assetId, i);
      if (restoredSpoke == spokeAddress) {
        _assertCaps(_assetId, restoredSpoke, 0, 0);
      } else {
        _assertCaps(_assetId, restoredSpoke, addCaps[i], drawCaps[i]);
      }
    }
    _assertSavedCaps(_assetId, spokeAddress, spokeConfig.addCap, spokeConfig.drawCap, false, true);

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.restoreSpokeCaps(address(hub1), spokeAddress);

    _assertCapsOfAsset(_assetId, addCaps, drawCaps);
  }

  function test_restoreAssetCaps_skipsSpokesWithCapsChangedOnHub() public {
    address changedSpoke = spokeAddresses[0];
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);
    _setCapsOnHub(_assetId, changedSpoke, 5, 0);

    vm.expectCall(
      address(hub1),
      abi.encodeWithSelector(IHub.updateSpokeConfig.selector, _assetId, changedSpoke),
      0
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);

    _assertCaps(_assetId, changedSpoke, 5, 0);
    _assertSavedCaps(_assetId, changedSpoke, 0, 0, false, false);
  }

  function test_restoreAssetCaps_skipsSpokesNotZeroedByZeroAssetCaps() public {
    address zeroCapsSpoke = spokeAddresses[0];
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeCaps(address(hub1), _assetUnderlying, zeroCapsSpoke, 0, 0);

    vm.expectCall(address(hub1), abi.encodeWithSelector(IHub.updateSpokeConfig.selector), 0);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);

    _assertCaps(_assetId, zeroCapsSpoke, 0, 0);
  }

  function test_restoreAssetCaps_leavesOtherAssetsZeroed() public {
    (uint256[] memory addCaps, uint256[] memory drawCaps) = _capsOfAsset(_assetId);

    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);
    hubConfigurator.zeroAssetCaps(address(hub1), address(tokenList.weth));
    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);
    vm.stopPrank();

    _assertCapsOfAsset(_assetId, addCaps, drawCaps);
    for (uint256 i; i < hub1.getSpokeCount(wethAssetId); ++i) {
      _assertCaps(wethAssetId, hub1.getSpokeAddress(wethAssetId, i), 0, 0);
    }
  }

  function test_restoreAssetCaps_keepsCapsZeroedByResetAssetCaps() public {
    assertGt(
      hub1.getSpokeConfig(_assetId, spokeAddresses[0]).addCap,
      0,
      'add cap zero before reset'
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.resetAssetCaps(address(hub1), _assetUnderlying);

    vm.expectCall(address(hub1), abi.encodeWithSelector(IHub.updateSpokeConfig.selector), 0);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);

    for (uint256 i; i < hub1.getSpokeCount(_assetId); ++i) {
      _assertCaps(_assetId, hub1.getSpokeAddress(_assetId, i), 0, 0);
    }
  }

  function test_restoreAssetCaps_keepsCapsZeroedByResetAssetCapsAfterZeroAssetCaps() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);
    hubConfigurator.resetAssetCaps(address(hub1), _assetUnderlying);
    vm.stopPrank();

    vm.expectCall(address(hub1), abi.encodeWithSelector(IHub.updateSpokeConfig.selector), 0);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);

    for (uint256 i; i < hub1.getSpokeCount(_assetId); ++i) {
      address spokeAddress = hub1.getSpokeAddress(_assetId, i);
      _assertCaps(_assetId, spokeAddress, 0, 0);
      _assertSavedCaps(_assetId, spokeAddress, 0, 0, false, false);
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
      _assertHaltedByBulkLevers(_assetId, spokeAddresses[i], true, false);
    }
  }

  function test_haltAsset_skipsSpokesAlreadyHalted() public {
    address haltedSpoke = spokeAddresses[0];
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeHalted(address(hub1), _assetUnderlying, haltedSpoke, true);

    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, haltedSpoke);
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, haltedSpoke, spokeConfig)),
      0
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);

    for (uint256 i; i < spokeAddresses.length; i++) {
      assertTrue(hub1.getSpokeConfig(_assetId, spokeAddresses[i]).halted);
      _assertHaltedByBulkLevers(
        _assetId,
        spokeAddresses[i],
        spokeAddresses[i] != haltedSpoke,
        false
      );
    }
  }

  function test_unhaltAsset_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);
  }

  function test_unhaltAsset() public {
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);

    assertEq(hub1.getSpokeCount(_assetId), spokeAddresses.length, 'spoke count');
    for (uint256 i; i < spokeAddresses.length; i++) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, spokeAddresses[i]);
      spokeConfig.halted = false;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spokeAddresses[i], spokeConfig))
      );
    }
    for (uint256 i; i < spokeAddresses.length; i++) {
      _expectSpokeHaltedEvent(_assetId, hub1.getSpokeAddress(_assetId, i), false);
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);

    for (uint256 i; i < spokeAddresses.length; i++) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, spokeAddresses[i]);
      assertEq(spokeConfig.halted, false);
      _assertHaltedByBulkLevers(_assetId, spokeAddresses[i], false, false);
    }
  }

  function test_unhaltAsset_afterRepeatedHaltAsset() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);
    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);
    vm.stopPrank();

    for (uint256 i; i < spokeAddresses.length; i++) {
      assertFalse(hub1.getSpokeConfig(_assetId, spokeAddresses[i]).halted);
    }
  }

  function test_unhaltAsset_keepsSpokesHaltedBeforeHaltAsset() public {
    address haltedSpoke = spokeAddresses[0];
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeHalted(address(hub1), _assetUnderlying, haltedSpoke, true);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);
    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);
    vm.stopPrank();

    for (uint256 i; i < spokeAddresses.length; i++) {
      assertEq(
        hub1.getSpokeConfig(_assetId, spokeAddresses[i]).halted,
        spokeAddresses[i] == haltedSpoke
      );
    }
  }

  function test_unhaltAsset_keepsSpokesHaltedThroughUpdateSpokeHalted() public {
    address haltedSpoke = spokeAddresses[1];
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);
    hubConfigurator.updateSpokeHalted(address(hub1), _assetUnderlying, haltedSpoke, true);
    _assertHaltedByBulkLevers(_assetId, haltedSpoke, false, false);
    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);
    vm.stopPrank();

    for (uint256 i; i < spokeAddresses.length; i++) {
      assertEq(
        hub1.getSpokeConfig(_assetId, spokeAddresses[i]).halted,
        spokeAddresses[i] == haltedSpoke
      );
    }
  }

  function test_unhaltAsset_keepsSpokesHaltedThroughHaltSpoke() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);
    hubConfigurator.haltSpoke(address(hub1), address(spoke1));
    _assertHaltedByBulkLevers(_assetId, address(spoke1), true, true);
    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);
    vm.stopPrank();

    for (uint256 i; i < spokeAddresses.length; i++) {
      assertEq(
        hub1.getSpokeConfig(_assetId, spokeAddresses[i]).halted,
        spokeAddresses[i] == address(spoke1)
      );
    }
    _assertHaltedByBulkLevers(_assetId, address(spoke1), false, true);

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltSpoke(address(hub1), address(spoke1));

    assertFalse(hub1.getSpokeConfig(_assetId, address(spoke1)).halted);
    _assertHaltedByBulkLevers(_assetId, address(spoke1), false, false);
  }

  function test_unhaltAsset_skipsSpokesUnhaltedOnHub() public {
    address unhaltedSpoke = spokeAddresses[0];
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);
    IHub.SpokeConfig memory spokeConfig = _unhaltOnHub(_assetId, unhaltedSpoke);

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, unhaltedSpoke, spokeConfig)),
      0
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);

    for (uint256 i; i < spokeAddresses.length; i++) {
      assertFalse(hub1.getSpokeConfig(_assetId, spokeAddresses[i]).halted);
    }
  }

  function test_unhaltAsset_skipsSpokesNotHaltedByHaltAsset() public {
    address haltedSpoke = spokeAddresses[0];
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeHalted(address(hub1), _assetUnderlying, haltedSpoke, true);

    vm.expectCall(address(hub1), abi.encodeWithSelector(IHub.updateSpokeConfig.selector), 0);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);

    assertTrue(hub1.getSpokeConfig(_assetId, haltedSpoke).halted);
  }

  function test_unhaltAsset_leavesOtherAssetsHalted() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);
    hubConfigurator.haltAsset(address(hub1), address(tokenList.weth));
    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);
    vm.stopPrank();

    for (uint256 i; i < hub1.getSpokeCount(wethAssetId); ++i) {
      assertTrue(hub1.getSpokeConfig(wethAssetId, hub1.getSpokeAddress(wethAssetId, i)).halted);
    }
    for (uint256 i; i < spokeAddresses.length; i++) {
      assertFalse(hub1.getSpokeConfig(_assetId, spokeAddresses[i]).halted);
    }
  }

  function test_getHaltedByBulkLevers() public {
    address spokeAddress = address(spoke3);
    _assertHaltedByBulkLevers(_assetId, spokeAddress, false, false);

    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);
    _assertHaltedByBulkLevers(_assetId, spokeAddress, true, false);

    hubConfigurator.haltSpoke(address(hub1), spokeAddress);
    _assertHaltedByBulkLevers(_assetId, spokeAddress, true, true);

    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);
    _assertHaltedByBulkLevers(_assetId, spokeAddress, false, true);

    hubConfigurator.unhaltSpoke(address(hub1), spokeAddress);
    _assertHaltedByBulkLevers(_assetId, spokeAddress, false, false);

    hubConfigurator.haltHub(address(hub1));
    _assertHaltedByBulkLevers(_assetId, spokeAddress, false, false, true);

    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);
    hubConfigurator.haltSpoke(address(hub1), spokeAddress);
    _assertHaltedByBulkLevers(_assetId, spokeAddress, true, true, true);

    hubConfigurator.unhaltHub(address(hub1));
    _assertHaltedByBulkLevers(_assetId, spokeAddress, true, true, false);

    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);
    hubConfigurator.unhaltSpoke(address(hub1), spokeAddress);
    _assertHaltedByBulkLevers(_assetId, spokeAddress, false, false, false);
    vm.stopPrank();
  }

  function _assertHaltedByBulkLevers(
    uint256 assetId,
    address spokeAddress,
    bool byHaltAsset,
    bool byHaltSpoke
  ) internal view {
    _assertHaltedByBulkLevers(assetId, spokeAddress, byHaltAsset, byHaltSpoke, false);
  }

  function _assertHaltedByBulkLevers(
    uint256 assetId,
    address spokeAddress,
    bool byHaltAsset,
    bool byHaltSpoke,
    bool byHaltHub
  ) internal view {
    (bool haltedByHaltAsset, bool haltedByHaltSpoke, bool haltedByHaltHub) = hubConfigurator
      .getHaltedByBulkLevers(address(hub1), _hub1Underlying(assetId), spokeAddress);
    assertEq(haltedByHaltAsset, byHaltAsset, 'halted by haltAsset');
    assertEq(haltedByHaltSpoke, byHaltSpoke, 'halted by haltSpoke');
    assertEq(haltedByHaltHub, byHaltHub, 'halted by haltHub');
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
      _assertHaltedByBulkLevers(assetId, address(spoke3), false, true);
    }
  }

  function test_haltSpoke_skipsAssetsAlreadyHalted() public {
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeHalted(address(hub1), _assetUnderlying, address(spoke3), true);

    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, address(spoke3));
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, address(spoke3), spokeConfig)),
      0
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltSpoke(address(hub1), address(spoke3));

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      assertTrue(hub1.getSpokeConfig(assetId, address(spoke3)).halted);
      _assertHaltedByBulkLevers(assetId, address(spoke3), false, assetId != _assetId);
    }
  }

  function test_unhaltSpoke_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.unhaltSpoke(address(hub1), address(spoke3));
  }

  function test_unhaltSpoke() public {
    /// @dev Spoke3 is listed on hub1 on 4 assets: dai, weth, wbtc, usdx
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltSpoke(address(hub1), address(spoke3));

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(assetId, address(spoke3));
      expectedSpokeConfig.halted = false;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (assetId, address(spoke3), expectedSpokeConfig))
      );
      _expectSpokeHaltedEvent(assetId, address(spoke3), false);
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltSpoke(address(hub1), address(spoke3));

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      assertFalse(hub1.getSpokeConfig(assetId, address(spoke3)).halted);
      _assertHaltedByBulkLevers(assetId, address(spoke3), false, false);
    }
  }

  function test_unhaltSpoke_afterRepeatedHaltSpoke() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltSpoke(address(hub1), address(spoke3));
    hubConfigurator.haltSpoke(address(hub1), address(spoke3));
    hubConfigurator.unhaltSpoke(address(hub1), address(spoke3));
    vm.stopPrank();

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      assertFalse(hub1.getSpokeConfig(assetId, address(spoke3)).halted);
    }
  }

  function test_unhaltSpoke_keepsAssetsHaltedBeforeHaltSpoke() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeHalted(address(hub1), _assetUnderlying, address(spoke3), true);
    hubConfigurator.haltSpoke(address(hub1), address(spoke3));
    hubConfigurator.unhaltSpoke(address(hub1), address(spoke3));
    vm.stopPrank();

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      assertEq(hub1.getSpokeConfig(assetId, address(spoke3)).halted, assetId == _assetId);
    }
  }

  function test_unhaltSpoke_keepsAssetsHaltedThroughUpdateSpokeHalted() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltSpoke(address(hub1), address(spoke3));
    hubConfigurator.updateSpokeHalted(address(hub1), _assetUnderlying, address(spoke3), true);
    _assertHaltedByBulkLevers(_assetId, address(spoke3), false, false);
    hubConfigurator.unhaltSpoke(address(hub1), address(spoke3));
    vm.stopPrank();

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      assertEq(hub1.getSpokeConfig(assetId, address(spoke3)).halted, assetId == _assetId);
    }
  }

  function test_unhaltSpoke_keepsAssetsHaltedThroughHaltAsset() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltSpoke(address(hub1), address(spoke3));
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);
    _assertHaltedByBulkLevers(_assetId, address(spoke3), true, true);
    hubConfigurator.unhaltSpoke(address(hub1), address(spoke3));
    vm.stopPrank();

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      assertEq(hub1.getSpokeConfig(assetId, address(spoke3)).halted, assetId == _assetId);
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);

    for (uint256 i; i < spokeAddresses.length; i++) {
      assertFalse(hub1.getSpokeConfig(_assetId, spokeAddresses[i]).halted);
    }
  }

  function test_unhaltSpoke_skipsAssetsNotHaltedByHaltSpoke() public {
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);

    vm.expectCall(address(hub1), abi.encodeWithSelector(IHub.updateSpokeConfig.selector), 0);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltSpoke(address(hub1), address(spoke3));

    assertTrue(hub1.getSpokeConfig(_assetId, address(spoke3)).halted);
    _assertHaltedByBulkLevers(_assetId, address(spoke3), true, false);
  }

  function test_unhaltSpoke_skipsAssetsUnhaltedOnHub() public {
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltSpoke(address(hub1), address(spoke3));
    IHub.SpokeConfig memory spokeConfig = _unhaltOnHub(_assetId, address(spoke3));

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, address(spoke3), spokeConfig)),
      0
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltSpoke(address(hub1), address(spoke3));

    for (uint256 assetId = 0; assetId < 4; ++assetId) {
      assertFalse(hub1.getSpokeConfig(assetId, address(spoke3)).halted);
    }
  }

  function test_unhaltSpoke_leavesOtherSpokesHalted() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltSpoke(address(hub1), address(spoke1));
    hubConfigurator.haltSpoke(address(hub1), address(spoke3));
    hubConfigurator.unhaltSpoke(address(hub1), address(spoke3));
    vm.stopPrank();

    assertTrue(hub1.getSpokeConfig(_assetId, address(spoke1)).halted);
    assertFalse(hub1.getSpokeConfig(_assetId, address(spoke3)).halted);
  }

  /// @dev Unhalts a Spoke directly on the Hub, bypassing the configurator, and returns its new config.
  function _unhaltOnHub(
    uint256 assetId,
    address spokeAddress
  ) internal returns (IHub.SpokeConfig memory) {
    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(assetId, spokeAddress);
    spokeConfig.halted = false;
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(assetId, spokeAddress, spokeConfig);
    return spokeConfig;
  }

  function test_haltHub_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.haltHub(address(hub1));
  }

  function test_haltHub() public {
    assertGt(hub1.getAssetCount(), 1, 'hub1 has less than 2 assets listed');
    (uint256[] memory assetIds, address[] memory spokes) = _hub1Pairs();
    for (uint256 k; k < assetIds.length; ++k) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(assetIds[k], spokes[k]);
      assertFalse(spokeConfig.halted, 'halted before haltHub');
      spokeConfig.halted = true;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (assetIds[k], spokes[k], spokeConfig))
      );
      _expectSpokeHaltedEvent(assetIds[k], spokes[k], true);
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltHub(address(hub1));

    for (uint256 k; k < assetIds.length; ++k) {
      assertTrue(hub1.getSpokeConfig(assetIds[k], spokes[k]).halted);
      _assertHaltedByBulkLevers(assetIds[k], spokes[k], false, false, true);
    }
  }

  function test_haltHub_skipsSpokesAlreadyHalted() public {
    address haltedSpoke = spokeAddresses[0];
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeHalted(address(hub1), _assetUnderlying, haltedSpoke, true);

    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, haltedSpoke);
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, haltedSpoke, spokeConfig)),
      0
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltHub(address(hub1));

    (uint256[] memory assetIds, address[] memory spokes) = _hub1Pairs();
    for (uint256 k; k < assetIds.length; ++k) {
      assertTrue(hub1.getSpokeConfig(assetIds[k], spokes[k]).halted);
      bool haltedBefore = assetIds[k] == _assetId && spokes[k] == haltedSpoke;
      _assertHaltedByBulkLevers(assetIds[k], spokes[k], false, false, !haltedBefore);
    }
  }

  function test_unhaltHub_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.unhaltHub(address(hub1));
  }

  function test_unhaltHub() public {
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltHub(address(hub1));

    (uint256[] memory assetIds, address[] memory spokes) = _hub1Pairs();
    for (uint256 k; k < assetIds.length; ++k) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(assetIds[k], spokes[k]);
      spokeConfig.halted = false;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (assetIds[k], spokes[k], spokeConfig))
      );
      _expectSpokeHaltedEvent(assetIds[k], spokes[k], false);
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltHub(address(hub1));

    for (uint256 k; k < assetIds.length; ++k) {
      assertFalse(hub1.getSpokeConfig(assetIds[k], spokes[k]).halted);
      _assertHaltedByBulkLevers(assetIds[k], spokes[k], false, false, false);
    }
  }

  function test_unhaltHub_afterRepeatedHaltHub() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltHub(address(hub1));
    hubConfigurator.haltHub(address(hub1));
    hubConfigurator.unhaltHub(address(hub1));
    vm.stopPrank();

    _assertHub1Halted(type(uint256).max, address(0));
  }

  function test_unhaltHub_keepsSpokesHaltedBeforeHaltHub() public {
    address haltedSpoke = spokeAddresses[0];
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeHalted(address(hub1), _assetUnderlying, haltedSpoke, true);
    hubConfigurator.haltHub(address(hub1));
    hubConfigurator.unhaltHub(address(hub1));
    vm.stopPrank();

    _assertOnlyPairHalted(_assetId, haltedSpoke);
  }

  function test_unhaltHub_keepsSpokesHaltedThroughUpdateSpokeHalted() public {
    address haltedSpoke = spokeAddresses[1];
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltHub(address(hub1));
    hubConfigurator.updateSpokeHalted(address(hub1), _assetUnderlying, haltedSpoke, true);
    _assertHaltedByBulkLevers(_assetId, haltedSpoke, false, false, false);
    hubConfigurator.unhaltHub(address(hub1));
    vm.stopPrank();

    _assertOnlyPairHalted(_assetId, haltedSpoke);
  }

  function test_unhaltHub_keepsSpokesHaltedThroughHaltAsset() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltHub(address(hub1));
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);
    _assertHaltedByBulkLevers(_assetId, address(spoke1), true, false, true);
    hubConfigurator.unhaltHub(address(hub1));
    vm.stopPrank();

    _assertHub1Halted(_assetId, address(0));
    _assertHaltedByBulkLevers(_assetId, address(spoke1), true, false, false);

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);

    _assertHub1Halted(type(uint256).max, address(0));
  }

  function test_unhaltHub_keepsAssetsHaltedThroughHaltSpoke() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltHub(address(hub1));
    hubConfigurator.haltSpoke(address(hub1), address(spoke3));
    _assertHaltedByBulkLevers(_assetId, address(spoke3), false, true, true);
    hubConfigurator.unhaltHub(address(hub1));
    vm.stopPrank();

    _assertHub1Halted(type(uint256).max, address(spoke3));
    _assertHaltedByBulkLevers(_assetId, address(spoke3), false, true, false);

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltSpoke(address(hub1), address(spoke3));

    _assertHub1Halted(type(uint256).max, address(0));
  }

  function test_unhaltAsset_keepsSpokesHaltedThroughHaltHub() public {
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltAsset(address(hub1), _assetUnderlying);
    hubConfigurator.haltHub(address(hub1));
    _assertHaltedByBulkLevers(_assetId, address(spoke1), true, false, true);
    hubConfigurator.unhaltAsset(address(hub1), _assetUnderlying);
    vm.stopPrank();

    (uint256[] memory assetIds, address[] memory spokes) = _hub1Pairs();
    for (uint256 k; k < assetIds.length; ++k) {
      assertTrue(hub1.getSpokeConfig(assetIds[k], spokes[k]).halted);
    }
    _assertHaltedByBulkLevers(_assetId, address(spoke1), false, false, true);

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltHub(address(hub1));

    _assertHub1Halted(type(uint256).max, address(0));
  }

  function test_unhaltHub_skipsSpokesUnhaltedOnHub() public {
    address unhaltedSpoke = spokeAddresses[0];
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.haltHub(address(hub1));
    IHub.SpokeConfig memory spokeConfig = _unhaltOnHub(_assetId, unhaltedSpoke);

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, unhaltedSpoke, spokeConfig)),
      0
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltHub(address(hub1));

    _assertHub1Halted(type(uint256).max, address(0));
  }

  function test_unhaltHub_skipsSpokesNotHaltedByHaltHub() public {
    address haltedSpoke = spokeAddresses[0];
    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeHalted(address(hub1), _assetUnderlying, haltedSpoke, true);
    hubConfigurator.haltAsset(address(hub1), address(tokenList.weth));
    vm.stopPrank();

    vm.expectCall(address(hub1), abi.encodeWithSelector(IHub.updateSpokeConfig.selector), 0);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.unhaltHub(address(hub1));

    assertTrue(hub1.getSpokeConfig(_assetId, haltedSpoke).halted);
    for (uint256 i; i < hub1.getSpokeCount(wethAssetId); ++i) {
      assertTrue(hub1.getSpokeConfig(wethAssetId, hub1.getSpokeAddress(wethAssetId, i)).halted);
    }
  }

  /// @dev Returns every asset and Spoke pair registered on hub1.
  function _hub1Pairs() internal view returns (uint256[] memory assetIds, address[] memory spokes) {
    uint256 assetCount = hub1.getAssetCount();
    uint256 pairCount;
    for (uint256 assetId; assetId < assetCount; ++assetId) {
      pairCount += hub1.getSpokeCount(assetId);
    }
    assetIds = new uint256[](pairCount);
    spokes = new address[](pairCount);
    uint256 k;
    for (uint256 assetId; assetId < assetCount; ++assetId) {
      for (uint256 i; i < hub1.getSpokeCount(assetId); ++i) {
        assetIds[k] = assetId;
        spokes[k] = hub1.getSpokeAddress(assetId, i);
        ++k;
      }
    }
  }

  /// @dev Asserts that a pair on hub1 is halted only if its asset is `haltedAssetId` or its Spoke is
  /// `haltedSpoke`. Pass `type(uint256).max` and `address(0)` to assert that no pair is halted.
  function _assertHub1Halted(uint256 haltedAssetId, address haltedSpoke) internal view {
    (uint256[] memory assetIds, address[] memory spokes) = _hub1Pairs();
    for (uint256 k; k < assetIds.length; ++k) {
      assertEq(
        hub1.getSpokeConfig(assetIds[k], spokes[k]).halted,
        assetIds[k] == haltedAssetId || spokes[k] == haltedSpoke
      );
    }
  }

  /// @dev Asserts that the `assetId` pair of `haltedSpoke` is the only halted pair on hub1.
  function _assertOnlyPairHalted(uint256 assetId, address haltedSpoke) internal view {
    (uint256[] memory assetIds, address[] memory spokes) = _hub1Pairs();
    for (uint256 k; k < assetIds.length; ++k) {
      assertEq(
        hub1.getSpokeConfig(assetIds[k], spokes[k]).halted,
        assetIds[k] == assetId && spokes[k] == haltedSpoke
      );
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

  function test_zeroSpokeCaps_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.zeroSpokeCaps(address(hub1), address(spoke3));
  }

  function test_zeroSpokeCaps_savesCaps() public {
    address spokeAddress = address(spoke3);
    (uint256[] memory addCaps, uint256[] memory drawCaps) = _capsOfSpoke(spokeAddress);

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroSpokeCaps(address(hub1), spokeAddress);

    for (uint256 assetId; assetId < addCaps.length; ++assetId) {
      if (hub1.isSpokeListed(assetId, spokeAddress)) {
        _assertSavedCaps(assetId, spokeAddress, addCaps[assetId], drawCaps[assetId], false, true);
        _assertCaps(assetId, spokeAddress, 0, 0);
      }
    }
  }

  function test_restoreSpokeCaps_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.restoreSpokeCaps(address(hub1), address(spoke3));
  }

  function test_restoreSpokeCaps() public {
    address spokeAddress = address(spoke3);
    (uint256[] memory addCaps, uint256[] memory drawCaps) = _capsOfSpoke(spokeAddress);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroSpokeCaps(address(hub1), spokeAddress);

    for (uint256 assetId; assetId < addCaps.length; ++assetId) {
      if (hub1.isSpokeListed(assetId, spokeAddress)) {
        IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(assetId, spokeAddress);
        spokeConfig.addCap = addCaps[assetId].toUint40();
        spokeConfig.drawCap = drawCaps[assetId].toUint40();
        vm.expectCall(
          address(hub1),
          abi.encodeCall(IHub.updateSpokeConfig, (assetId, spokeAddress, spokeConfig))
        );
        _expectSpokeCapsEvents(assetId, spokeAddress, addCaps[assetId], drawCaps[assetId]);
      }
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.restoreSpokeCaps(address(hub1), spokeAddress);

    _assertCapsOfSpoke(spokeAddress, addCaps, drawCaps);
    for (uint256 assetId; assetId < addCaps.length; ++assetId) {
      if (hub1.isSpokeListed(assetId, spokeAddress)) {
        _assertSavedCaps(assetId, spokeAddress, 0, 0, false, false);
      }
    }
  }

  function test_restoreSpokeCaps_keepsCapsZeroThroughZeroAssetCaps() public {
    address spokeAddress = address(spoke3);
    (uint256[] memory addCaps, uint256[] memory drawCaps) = _capsOfSpoke(spokeAddress);
    (uint256[] memory assetAddCaps, uint256[] memory assetDrawCaps) = _capsOfAsset(_assetId);

    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroSpokeCaps(address(hub1), spokeAddress);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);
    hubConfigurator.restoreSpokeCaps(address(hub1), spokeAddress);
    vm.stopPrank();

    for (uint256 assetId; assetId < addCaps.length; ++assetId) {
      if (assetId == _assetId) {
        _assertCaps(assetId, spokeAddress, 0, 0);
      } else if (hub1.isSpokeListed(assetId, spokeAddress)) {
        _assertCaps(assetId, spokeAddress, addCaps[assetId], drawCaps[assetId]);
      }
    }
    _assertSavedCaps(_assetId, spokeAddress, addCaps[_assetId], drawCaps[_assetId], true, false);

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);

    _assertCapsOfSpoke(spokeAddress, addCaps, drawCaps);
    _assertCapsOfAsset(_assetId, assetAddCaps, assetDrawCaps);
  }

  function test_restoreSpokeCaps_leavesOtherSpokesZeroed() public {
    (uint256[] memory addCaps, uint256[] memory drawCaps) = _capsOfSpoke(address(spoke3));

    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroSpokeCaps(address(hub1), address(spoke2));
    hubConfigurator.zeroSpokeCaps(address(hub1), address(spoke3));
    hubConfigurator.restoreSpokeCaps(address(hub1), address(spoke3));
    vm.stopPrank();

    _assertCapsOfSpoke(address(spoke3), addCaps, drawCaps);
    for (uint256 assetId; assetId < hub1.getAssetCount(); ++assetId) {
      if (hub1.isSpokeListed(assetId, address(spoke2))) {
        _assertCaps(assetId, address(spoke2), 0, 0);
      }
    }
  }

  function test_getSavedCaps() public {
    address spokeAddress = address(spoke3);
    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, spokeAddress);
    _assertSavedCaps(_assetId, spokeAddress, 0, 0, false, false);

    vm.startPrank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.zeroAssetCaps(address(hub1), _assetUnderlying);
    _assertSavedCaps(_assetId, spokeAddress, spokeConfig.addCap, spokeConfig.drawCap, true, false);

    hubConfigurator.zeroSpokeCaps(address(hub1), spokeAddress);
    _assertSavedCaps(_assetId, spokeAddress, spokeConfig.addCap, spokeConfig.drawCap, true, true);

    hubConfigurator.restoreAssetCaps(address(hub1), _assetUnderlying);
    _assertSavedCaps(_assetId, spokeAddress, spokeConfig.addCap, spokeConfig.drawCap, false, true);

    hubConfigurator.restoreSpokeCaps(address(hub1), spokeAddress);
    _assertSavedCaps(_assetId, spokeAddress, 0, 0, false, false);
    vm.stopPrank();
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

    bytes[] memory calls = new bytes[](21);
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
    calls[7] = abi.encodeCall(IHubConfigurator.zeroAssetCaps, (address(hub1), unlisted));
    calls[8] = abi.encodeCall(IHubConfigurator.restoreAssetCaps, (address(hub1), unlisted));
    calls[9] = abi.encodeCall(IHubConfigurator.deactivateAsset, (address(hub1), unlisted));
    calls[10] = abi.encodeCall(IHubConfigurator.haltAsset, (address(hub1), unlisted));
    calls[11] = abi.encodeCall(IHubConfigurator.unhaltAsset, (address(hub1), unlisted));
    calls[12] = abi.encodeCall(
      IHubConfigurator.addSpoke,
      (address(hub1), makeAddr('newSpoke'), unlisted, spokeConfig)
    );
    calls[13] = abi.encodeCall(
      IHubConfigurator.updateSpokeActive,
      (address(hub1), unlisted, spoke, false)
    );
    calls[14] = abi.encodeCall(
      IHubConfigurator.updateSpokeHalted,
      (address(hub1), unlisted, spoke, true)
    );
    calls[15] = abi.encodeCall(
      IHubConfigurator.updateSpokeAddCap,
      (address(hub1), unlisted, spoke, 1)
    );
    calls[16] = abi.encodeCall(
      IHubConfigurator.updateSpokeDrawCap,
      (address(hub1), unlisted, spoke, 1)
    );
    calls[17] = abi.encodeCall(
      IHubConfigurator.updateSpokeRiskPremiumThreshold,
      (address(hub1), unlisted, spoke, 1)
    );
    calls[18] = abi.encodeCall(
      IHubConfigurator.updateSpokeCaps,
      (address(hub1), unlisted, spoke, 1, 1)
    );
    calls[19] = abi.encodeCall(
      IHubConfigurator.getHaltedByBulkLevers,
      (address(hub1), unlisted, spoke)
    );
    calls[20] = abi.encodeCall(IHubConfigurator.getSavedCaps, (address(hub1), unlisted, spoke));

    for (uint256 i; i < calls.length; ++i) {
      vm.prank(HUB_CONFIGURATOR_ADMIN);
      (bool ok, bytes memory ret) = address(hubConfigurator).call(calls[i]);
      assertFalse(ok);
      assertEq(ret, abi.encodeWithSelector(IHub.AssetNotListed.selector));
    }
  }

  function test_implementation_initialize_revertsWith_InvalidInitialization() public {
    IHubConfiguratorInstance impl = IHubConfiguratorInstance(
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
    IHubConfiguratorInstance(address(hubConfigurator)).initialize(authority);
  }

  function test_revision() public view {
    assertEq(IHubConfiguratorInstance(address(hubConfigurator)).HUB_CONFIGURATOR_REVISION(), 1);
  }

  function test_proxy_constructor_revertsWith_InvalidAddress() public {
    address impl = deployCode(
      'src/hub/instances/HubConfiguratorInstance.sol:HubConfiguratorInstance'
    );

    vm.expectRevert(IHubConfigurator.InvalidAddress.selector);
    new TransparentUpgradeableProxy(
      impl,
      ADMIN,
      abi.encodeCall(IHubConfiguratorInstance.initialize, (address(0)))
    );
  }

  function test_initialize_revertsWith_InvalidAddress() public {
    IHubConfiguratorInstance proxy = IHubConfiguratorInstance(
      address(
        new TransparentUpgradeableProxy(
          deployCode('src/hub/instances/HubConfiguratorInstance.sol:HubConfiguratorInstance'),
          ADMIN,
          ''
        )
      )
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

  /// @dev Returns the caps of every Spoke of `assetId` on hub1, in Hub order.
  function _capsOfAsset(
    uint256 assetId
  ) internal view returns (uint256[] memory addCaps, uint256[] memory drawCaps) {
    uint256 spokeCount = hub1.getSpokeCount(assetId);
    addCaps = new uint256[](spokeCount);
    drawCaps = new uint256[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(
        assetId,
        hub1.getSpokeAddress(assetId, i)
      );
      addCaps[i] = spokeConfig.addCap;
      drawCaps[i] = spokeConfig.drawCap;
    }
  }

  /// @dev Returns the caps of `spokeAddress` on hub1, indexed by asset identifier, with zero for unlisted assets.
  function _capsOfSpoke(
    address spokeAddress
  ) internal view returns (uint256[] memory addCaps, uint256[] memory drawCaps) {
    uint256 assetCount = hub1.getAssetCount();
    addCaps = new uint256[](assetCount);
    drawCaps = new uint256[](assetCount);
    for (uint256 assetId; assetId < assetCount; ++assetId) {
      if (hub1.isSpokeListed(assetId, spokeAddress)) {
        IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(assetId, spokeAddress);
        addCaps[assetId] = spokeConfig.addCap;
        drawCaps[assetId] = spokeConfig.drawCap;
      }
    }
  }

  function _assertCapsOfAsset(
    uint256 assetId,
    uint256[] memory addCaps,
    uint256[] memory drawCaps
  ) internal view {
    for (uint256 i; i < addCaps.length; ++i) {
      _assertCaps(assetId, hub1.getSpokeAddress(assetId, i), addCaps[i], drawCaps[i]);
    }
  }

  function _assertCapsOfSpoke(
    address spokeAddress,
    uint256[] memory addCaps,
    uint256[] memory drawCaps
  ) internal view {
    for (uint256 assetId; assetId < addCaps.length; ++assetId) {
      if (hub1.isSpokeListed(assetId, spokeAddress)) {
        _assertCaps(assetId, spokeAddress, addCaps[assetId], drawCaps[assetId]);
      }
    }
  }

  function _assertCaps(
    uint256 assetId,
    address spokeAddress,
    uint256 addCap,
    uint256 drawCap
  ) internal view {
    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(assetId, spokeAddress);
    assertEq(spokeConfig.addCap, addCap, 'add cap');
    assertEq(spokeConfig.drawCap, drawCap, 'draw cap');
  }

  function _assertSavedCaps(
    uint256 assetId,
    address spokeAddress,
    uint256 addCap,
    uint256 drawCap,
    bool byZeroAssetCaps,
    bool byZeroSpokeCaps
  ) internal view {
    (
      uint256 savedAddCap,
      uint256 savedDrawCap,
      bool heldByZeroAssetCaps,
      bool heldByZeroSpokeCaps
    ) = hubConfigurator.getSavedCaps(address(hub1), _hub1Underlying(assetId), spokeAddress);
    assertEq(savedAddCap, addCap, 'saved add cap');
    assertEq(savedDrawCap, drawCap, 'saved draw cap');
    assertEq(heldByZeroAssetCaps, byZeroAssetCaps, 'held by zeroAssetCaps');
    assertEq(heldByZeroSpokeCaps, byZeroSpokeCaps, 'held by zeroSpokeCaps');
  }

  /// @dev Sets the caps directly on hub1, bypassing the configurator.
  function _setCapsOnHub(
    uint256 assetId,
    address spokeAddress,
    uint256 addCap,
    uint256 drawCap
  ) internal {
    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(assetId, spokeAddress);
    spokeConfig.addCap = addCap.toUint40();
    spokeConfig.drawCap = drawCap.toUint40();
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(assetId, spokeAddress, spokeConfig);
  }
}
