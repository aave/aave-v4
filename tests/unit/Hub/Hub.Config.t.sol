// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubConfigTest is HubBase {
  using SharesMath for uint256;
  using WadRayMath for uint32;
  using SafeCast for uint256;

  bytes public encodedIrData;

  function setUp() public virtual override {
    super.setUp();
    encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
  }

  function test_hub_deploy_revertsWith_InvalidAddress() public {
    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    new Hub(address(0));
  }

  function test_hub_max_riskPremium() public {
    assertEq(Constants.MAX_ALLOWED_RISK_PREMIUM_CAP, hub1.MAX_ALLOWED_RISK_PREMIUM_CAP());
  }

  function test_addSpoke_fuzz_revertsWith_AssetNotListed(
    uint256 assetId,
    IHub.SpokeConfig calldata spokeConfig
  ) public {
    assetId = bound(assetId, hub1.getAssetCount(), type(uint256).max);
    vm.expectRevert(IHub.AssetNotListed.selector, address(hub1));
    Utils.addSpoke(hub1, ADMIN, assetId, address(spoke1), spokeConfig);
  }

  function test_addSpoke_fuzz_revertsWith_InvalidAddress_spoke(
    uint256 assetId,
    IHub.SpokeConfig calldata spokeConfig
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);

    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    Utils.addSpoke(hub1, ADMIN, assetId, address(0), spokeConfig);
  }

  function test_addSpoke_revertsWith_SpokeAlreadyListed() public {
    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(daiAssetId, address(spoke1));
    vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
    Utils.addSpoke(hub1, ADMIN, daiAssetId, address(spoke1), spokeConfig);
  }

  function test_addSpoke_fuzz(uint256 assetId, IHub.SpokeConfig calldata spokeConfig) public {
    address newSpoke = makeAddr('newSpoke');
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);

    vm.expectEmit(address(hub1));
    emit IHub.AddSpoke(assetId, newSpoke);
    vm.expectEmit(address(hub1));
    emit IHub.UpdateSpokeConfig(assetId, newSpoke, spokeConfig);
    Utils.addSpoke(hub1, ADMIN, assetId, newSpoke, spokeConfig);

    assertEq(hub1.getSpokeConfig(assetId, newSpoke), spokeConfig);
  }

  function test_updateSpokeConfig_revertsWith_AssetNotListed() public {
    uint256 assetId = _randomInvalidAssetId(hub1);
    address spoke = vm.randomAddress();
    IHub.SpokeConfig memory spokeConfig;
    vm.expectRevert(IHub.AssetNotListed.selector);
    Utils.updateSpokeConfig(hub1, ADMIN, assetId, spoke, spokeConfig);
  }

  function test_updateSpokeConfig_fuzz_revertsWith_SpokeNotListed(
    uint256 assetId,
    address spoke,
    IHub.SpokeConfig calldata spokeConfig
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 3);
    assumeUnusedAddress(spoke);
    vm.expectRevert(IHub.SpokeNotListed.selector, address(hub1));
    Utils.updateSpokeConfig(hub1, ADMIN, assetId, spoke, spokeConfig);
  }

  function test_updateSpokeConfig_fuzz(
    uint256 assetId,
    IHub.SpokeConfig calldata spokeConfig
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 3); // Exclude duplicated DAI and usdy

    vm.expectEmit(address(hub1));
    emit IHub.UpdateSpokeConfig(assetId, address(spoke1), spokeConfig);

    Utils.updateSpokeConfig(hub1, ADMIN, assetId, address(spoke1), spokeConfig);
    assertEq(hub1.getSpokeConfig(assetId, address(spoke1)), spokeConfig);
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);
    assumeNotZeroAddress(interestRateStrategy);

    decimals = bound(decimals, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS + 1, type(uint8).max)
      .toUint8();

    vm.expectRevert(IHub.InvalidAssetDecimals.selector, address(hub1));
    Utils.addAsset(
      hub1,
      ADMIN,
      underlying,
      decimals,
      feeReceiver,
      interestRateStrategy,
      encodedIrData
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals_tooLow(
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);
    assumeNotZeroAddress(interestRateStrategy);

    decimals = bound(decimals, 0, Constants.MIN_ALLOWED_UNDERLYING_DECIMALS - 1).toUint8();

    vm.expectRevert(IHub.InvalidAssetDecimals.selector, address(hub1));
    Utils.addAsset(
      hub1,
      ADMIN,
      underlying,
      decimals,
      feeReceiver,
      interestRateStrategy,
      encodedIrData
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidAddress_underlying(
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy
  ) public {
    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    Utils.addAsset(
      hub1,
      ADMIN,
      address(0),
      decimals,
      feeReceiver,
      interestRateStrategy,
      encodedIrData
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidAddress_feeReceiver(
    address underlying,
    uint8 decimals,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(interestRateStrategy);

    decimals = bound(decimals, 0, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS).toUint8();

    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    Utils.addAsset(
      hub1,
      ADMIN,
      underlying,
      decimals,
      address(0), // feeReceiver
      interestRateStrategy,
      encodedIrData
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidAddress_irStrategy(
    address underlying,
    uint8 decimals,
    address feeReceiver
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);

    decimals = bound(decimals, 0, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS).toUint8();

    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    Utils.addAsset(hub1, ADMIN, underlying, decimals, feeReceiver, address(0), encodedIrData);
  }

  function test_addAsset_fuzz_reverts_InvalidIrData(
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);
    assumeNotZeroAddress(interestRateStrategy);
    decimals = bound(decimals, 0, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS).toUint8();

    vm.expectRevert();
    Utils.addAsset(
      hub1,
      ADMIN,
      underlying,
      decimals,
      feeReceiver,
      interestRateStrategy,
      abi.encode('invalid')
    );
  }

  function test_addAsset_revertsWith_DrawnRateDowncastOverflow() public {
    uint256 drawnRateRay = uint256(type(uint96).max) + 1;
    _mockInterestRateRay(drawnRateRay);
    vm.expectRevert(
      abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, 96, drawnRateRay),
      address(hub1)
    );
    Utils.addAsset(
      hub1,
      ADMIN,
      address(tokenList.dai),
      18,
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
  }

  function test_addAsset_revertsWith_BlockTimestampDowncastOverflow() public {
    uint256 blockTimestamp = uint256(type(uint32).max) + 1;
    vm.warp(blockTimestamp);
    vm.expectRevert(
      abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, 32, blockTimestamp),
      address(hub1)
    );
    Utils.addAsset(
      hub1,
      ADMIN,
      address(tokenList.dai),
      18,
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
  }

  function test_addAsset_fuzz(address underlying, uint8 decimals, address feeReceiver) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);

    decimals = bound(
      decimals,
      Constants.MAX_ALLOWED_UNDERLYING_DECIMALS,
      Constants.MAX_ALLOWED_UNDERLYING_DECIMALS
    ).toUint8();

    uint256 expectedAssetId = hub1.getAssetCount();
    address interestRateStrategy = address(new AssetInterestRateStrategy(address(hub1)));

    IHub.AssetConfig memory expectedConfig = IHub.AssetConfig({
      feeReceiver: feeReceiver,
      liquidityFee: 0,
      irStrategy: interestRateStrategy,
      reinvestmentController: address(0)
    });

    (, uint32 baseVariableBorrowRate, , ) = abi.decode(
      encodedIrData,
      (uint32, uint32, uint32, uint32)
    );

    // feeReceiver risk premium cap defaults to 0
    IHub.SpokeConfig memory expectedSpokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: 0,
      riskPremiumCap: 0
    });

    vm.expectEmit(address(hub1));
    emit IHub.AddSpoke(expectedAssetId, feeReceiver);
    vm.expectEmit(address(hub1));
    emit IHub.UpdateSpokeConfig(expectedAssetId, feeReceiver, expectedSpokeConfig);
    vm.expectEmit(address(hub1));
    emit IHub.AddAsset(expectedAssetId, underlying, decimals);
    vm.expectEmit(address(hub1));
    emit IHub.UpdateAssetConfig(expectedAssetId, expectedConfig);
    vm.expectEmit(address(hub1));
    emit IHub.UpdateAsset(expectedAssetId, WadRayMath.RAY, baseVariableBorrowRate.bpsToRay());

    uint256 assetId = Utils.addAsset(
      hub1,
      ADMIN,
      underlying,
      decimals,
      feeReceiver,
      interestRateStrategy,
      encodedIrData
    );

    assertBorrowRateSynced(hub1, assetId, 'addAsset');
    assertEq(assetId, expectedAssetId, 'asset id');
    assertEq(hub1.getAssetCount(), assetId + 1, 'asset count');
    assertEq(hub1.getAsset(assetId).decimals, decimals, 'asset decimals');
    assertEq(hub1.getAssetConfig(assetId), expectedConfig);
    assertEq(hub1.getAsset(assetId).reinvestmentController, address(0)); // should init to addr(0)
    assertEq(hub1.getSpokeConfig(assetId, feeReceiver), expectedSpokeConfig);
  }

  function test_updateAssetConfig_fuzz_revertsWith_InvalidLiquidityFee(
    uint256 assetId,
    IHub.AssetConfig memory newConfig
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);
    _assumeValidAssetConfig(newConfig);
    newConfig.liquidityFee = vm
      .randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max)
      .toUint16();
    vm.expectRevert(IHub.InvalidLiquidityFee.selector, address(hub1));
    vm.prank(HUB_ADMIN);
    hub1.updateAssetConfig(assetId, newConfig, new bytes(0));
  }

  // @dev can only reset reinvestment strategy if swept is zero
  function test_updateAssetConfig_fuzz_revertsWith_InvalidReinvestmentController() public {
    uint256 assetId = _randomAssetId(hub1);
    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);

    config.reinvestmentController = address(0);
    assertEq(hub1.getAssetSwept(assetId), 0);

    vm.prank(HUB_ADMIN);
    hub1.updateAssetConfig(assetId, config, new bytes(0));
    assertEq(hub1.getAsset(assetId).reinvestmentController, address(0));

    address reinvestmentController = makeAddr('reinvestmentController');
    updateAssetReinvestmentController(hub1, assetId, reinvestmentController);
    _addLiquidity(assetId, 1000e18);
    vm.prank(reinvestmentController);
    hub1.sweep(assetId, 100e18);

    assertEq(hub1.getAssetSwept(assetId), 100e18);
    assertEq(config.reinvestmentController, address(0));
    assertNotEq(hub1.getAsset(assetId).reinvestmentController, address(0));

    vm.expectRevert(IHub.InvalidReinvestmentController.selector, address(hub1));
    vm.prank(HUB_ADMIN);
    hub1.updateAssetConfig(assetId, config, new bytes(0));
  }

  function test_updateAssetConfig_fuzz_revertsWith_calculateInterestRateReverts(
    uint256 assetId,
    IHub.AssetConfig memory newConfig
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);
    _assumeValidAssetConfig(newConfig);
    assumeUnusedAddress(newConfig.irStrategy);
    assumeUnusedAddress(newConfig.feeReceiver);

    vm.mockCall(
      newConfig.irStrategy,
      abi.encodeCall(IBasicInterestRateStrategy.setInterestRateData, (assetId, encodedIrData)),
      new bytes(0)
    );
    vm.mockCallRevert(
      newConfig.irStrategy,
      IBasicInterestRateStrategy.calculateInterestRate.selector,
      'custom revert'
    );

    vm.expectRevert(newConfig.irStrategy);
    vm.prank(HUB_ADMIN);
    hub1.updateAssetConfig(assetId, newConfig, encodedIrData);
  }

  function test_updateAssetConfig_fuzz_revertsWith_setInterestRateDataReverts(
    uint256 assetId,
    IHub.AssetConfig memory newConfig
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);
    _assumeValidAssetConfig(newConfig);
    assumeUnusedAddress(newConfig.irStrategy);

    vm.mockCallRevert(
      newConfig.irStrategy,
      abi.encodeCall(IBasicInterestRateStrategy.setInterestRateData, (assetId, encodedIrData)),
      'custom revert'
    );

    vm.expectRevert(address(newConfig.irStrategy));
    vm.prank(HUB_ADMIN);
    hub1.updateAssetConfig(assetId, newConfig, encodedIrData);
  }

  function test_updateAssetConfig_fuzz(uint256 assetId, IHub.AssetConfig memory newConfig) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);
    _assumeValidAssetConfig(newConfig);
    _mockInterestRateBps(newConfig.irStrategy, 5_00);
    vm.mockCall(
      newConfig.irStrategy,
      abi.encodeCall(IBasicInterestRateStrategy.setInterestRateData, (assetId, encodedIrData)),
      new bytes(0)
    );

    uint256 liquidity = hub1.getAssetLiquidity(assetId);
    (uint256 drawn, ) = hub1.getAssetOwed(assetId);

    // new spoke is added only if it is different from the old one and not yet listed
    if (
      newConfig.feeReceiver != _getFeeReceiver(hub1, assetId) &&
      !hub1.isSpokeListed(assetId, newConfig.feeReceiver)
    ) {
      vm.expectEmit(address(hub1));
      emit IHub.AddSpoke(assetId, newConfig.feeReceiver);
      vm.expectEmit(address(hub1));
      emit IHub.UpdateSpokeConfig(
        assetId,
        newConfig.feeReceiver,
        IHub.SpokeConfig({
          active: true,
          paused: false,
          addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
          drawCap: 0,
          riskPremiumCap: 0
        })
      );
    } else {
      newConfig.feeReceiver = _getFeeReceiver(hub1, assetId);
    }
    vm.expectEmit(address(hub1));
    emit IHub.UpdateAsset(
      assetId,
      hub1.getAssetDrawnIndex(assetId),
      IBasicInterestRateStrategy(irStrategy).calculateInterestRate({
        assetId: assetId,
        liquidity: liquidity,
        drawn: drawn,
        deficit: 0,
        swept: 0
      })
    );
    vm.expectEmit(address(hub1));
    emit IHub.UpdateAssetConfig(assetId, newConfig);

    // if ir strategy is new, expect an emit of setInterestRateData
    bool isNewIrStrategy = newConfig.irStrategy != hub1.getAsset(assetId).irStrategy;
    if (isNewIrStrategy) {
      vm.expectCall(
        newConfig.irStrategy,
        abi.encodeCall(IBasicInterestRateStrategy.setInterestRateData, (assetId, encodedIrData))
      );
    }

    Utils.updateAssetConfig(
      hub1,
      ADMIN,
      assetId,
      newConfig,
      isNewIrStrategy ? encodedIrData : new bytes(0)
    );

    assertEq(hub1.getAssetConfig(assetId), newConfig);
    assertBorrowRateSynced(hub1, assetId, 'updateAssetConfig');
  }

  function test_updateAssetConfig_fuzz_Scenario(uint256 assetId) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);

    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    // set same config
    test_updateAssetConfig_fuzz(assetId, config);
    // set new fee receiver
    config.feeReceiver = makeAddr('newFeeReceiver');
    test_updateAssetConfig_fuzz(assetId, config);
    // set zero liquidity fee
    config.liquidityFee = 0;
    test_updateAssetConfig_fuzz(assetId, config);
    // set zero liquidity fee again
    test_updateAssetConfig_fuzz(assetId, config);
    // set non-zero fee receiver
    config.feeReceiver = makeAddr('newFeeReceiver2');
    test_updateAssetConfig_fuzz(assetId, config);
    // set initial config
    test_updateAssetConfig_fuzz(assetId, hub1.getAssetConfig(assetId));
  }

  /// Updates to new fee receiver, with previously accrued fees not transferred to the new receiver
  function test_updateAssetConfig_fuzz_NewFeeReceiver(uint256 assetId) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    address oldFeeReceiver = config.feeReceiver;
    config.feeReceiver = makeAddr('newFeeReceiver');

    uint256 feesShares = hub1.getSpokeAddedShares(assetId, oldFeeReceiver);
    assertTrue(feesShares > 0, 'no fees');

    test_updateAssetConfig_fuzz(assetId, config);

    assertEq(hub1.getSpokeAddedShares(assetId, oldFeeReceiver), feesShares);
    assertEq(hub1.getSpokeAddedShares(assetId, config.feeReceiver), 0);

    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(assetId, oldFeeReceiver);
    assertTrue(spokeConfig.active, 'old fee receiver remains active');
    assertEq(spokeConfig.addCap, 0, 'old fee receiver add cap');
    assertEq(spokeConfig.drawCap, 0, 'old fee receiver draw cap');
  }

  /// Updates the fee receiver by reusing a previously assigned spoke, with no impact on accrued fees
  function test_updateAssetConfig_fuzz_ReuseFeeReceiver_revertsWith_SpokeAlreadyListed(
    uint256 assetId
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);
    test_updateAssetConfig_fuzz_NewFeeReceiver(assetId);

    address oldFeeReceiver = address(treasurySpoke);
    uint256 oldFees = hub1.getSpokeAddedShares(assetId, oldFeeReceiver);

    skip(365 days);

    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    address newFeeReceiver = config.feeReceiver;

    uint256 newFees = hub1.getSpokeAddedShares(assetId, newFeeReceiver);
    assertTrue(newFees > 0);

    config.feeReceiver = address(treasurySpoke);

    vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
    Utils.updateAssetConfig(hub1, ADMIN, assetId, config, new bytes(0));

    assertEq(hub1.getSpokeAddedShares(assetId, config.feeReceiver), oldFees);
    assertEq(hub1.getSpokeAddedShares(assetId, newFeeReceiver), newFees);
  }

  /// Updates the fee receiver to an existing spoke of the hub1, so ends up with existing supplied shares plus accrued fees
  function test_updateAssetConfig_fuzz_UseExistingSpokeAsFeeReceiver_revertsWith_SpokeAlreadyListed(
    uint256 assetId
  ) public {
    assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    address newFeeReceiver = address(spoke1);

    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    config.feeReceiver = newFeeReceiver;

    vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
    vm.prank(HUB_ADMIN);
    hub1.updateAssetConfig(assetId, config, new bytes(0));
  }

  /// Updates the fee receiver to an existing spoke of the hub1 which is already listed on the asset
  function test_updateAssetConfig_UseExistingSpokeAndListedAsFeeReceiver_revertsWith_SpokeAlreadyListed()
    public
  {
    uint256 assetId = 3;

    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);

    config.feeReceiver = address(spoke1);

    // spoke1 is already listed on this asset, therefore is not allowed
    assertTrue(hub1.isSpokeListed(assetId, address(spoke1)));

    vm.expectRevert(IHub.SpokeAlreadyListed.selector, address(hub1));
    vm.prank(HUB_ADMIN);
    hub1.updateAssetConfig(assetId, config, new bytes(0));
  }

  function test_updateAssetConfig_fuzz_revertsWith_InvalidInterestRateStrategy(
    uint256 assetId
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);
    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    vm.expectRevert(IHub.InvalidInterestRateStrategy.selector, address(hub1));
    Utils.updateAssetConfig(hub1, ADMIN, assetId, config, encodedIrData);
  }

  /// Triggers accrual when liquidity fee update, based on old liquidity fee
  function test_updateAssetConfig_fuzz_LiquidityFee(uint256 assetId, uint16 liquidityFee) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);
    liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR).toUint16();

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    uint256 feeShares = hub1.getSpokeAddedShares(assetId, config.feeReceiver);
    assertTrue(feeShares > 0, 'no fees');

    config.liquidityFee = liquidityFee;
    test_updateAssetConfig_fuzz(assetId, config);

    assertEq(hub1.getSpokeAddedShares(assetId, config.feeReceiver), feeShares);
  }

  /// No fees accrued whe updating liquidity fee from zero to non-zero
  function test_updateAssetConfig_fuzz_FromZeroLiquidityFee(
    uint256 assetId,
    uint16 liquidityFee
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);
    liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR).toUint16();

    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    config.liquidityFee = 0;
    test_updateAssetConfig_fuzz(assetId, config);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    config.liquidityFee = liquidityFee;
    config.feeReceiver = makeAddr('feeReceiver');
    test_updateAssetConfig_fuzz(assetId, config);

    assertEq(hub1.getSpokeAddedShares(assetId, address(0)), 0);
    assertEq(hub1.getSpokeAddedShares(assetId, config.feeReceiver), 0);
  }

  /// Triggers accrual when interest rate strategy is updated, based on old strategy
  /// Also makes sure that the base borrow rate is updated after accrual
  function test_updateAssetConfig_fuzz_NewInterestRateStrategy(uint256 assetId) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    uint256 fees = hub1.getSpokeAddedShares(assetId, address(treasurySpoke));
    assertTrue(fees > 0, 'no fees');

    skip(365 days);
    uint256 futureFees = hub1.getSpokeAddedShares(assetId, address(treasurySpoke));
    rewind(365 days);

    AssetInterestRateStrategy newIrStrategy = new AssetInterestRateStrategy(address(hub1));
    _mockInterestRateRay(address(newIrStrategy), hub1.getAssetDrawnRate(assetId) * 10);
    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    config.irStrategy = address(newIrStrategy);

    vm.expectCall(
      address(newIrStrategy),
      abi.encodeCall(IBasicInterestRateStrategy.setInterestRateData, (assetId, encodedIrData)),
      1
    );
    Utils.updateAssetConfig(hub1, ADMIN, assetId, config, encodedIrData);

    skip(365 days);
    assertNotEq(hub1.getSpokeAddedShares(assetId, config.feeReceiver), futureFees);
  }

  function _assumeValidAssetConfig(IHub.AssetConfig memory newConfig) internal pure {
    newConfig.liquidityFee = bound(newConfig.liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();
    vm.assume(address(newConfig.feeReceiver) != address(0) || newConfig.liquidityFee == 0);
    assumeNotPrecompile(newConfig.feeReceiver);
    assumeNotForgeAddress(newConfig.feeReceiver);
    assumeNotZeroAddress(newConfig.irStrategy);
    assumeNotPrecompile(newConfig.irStrategy);
    assumeNotForgeAddress(newConfig.irStrategy);
  }
}
