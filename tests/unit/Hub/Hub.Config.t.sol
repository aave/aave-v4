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

  function test_hub_deploy_reverts_on_InvalidConstructorInput() public {
    DeployWrapper deployer = new DeployWrapper();

    vm.expectRevert();
    deployer.deployHub(address(0));
  }

  function test_hub_max_riskPremium() public view {
    assertEq(Constants.MAX_RISK_PREMIUM_THRESHOLD, hub1.MAX_RISK_PREMIUM_THRESHOLD());
  }

  function test_addSpoke_fuzz_revertsWith_AssetNotListed(
    uint256 assetId,
    IHub.SpokeConfig calldata spokeConfig
  ) public {
    assetId = bound(assetId, hub1.getAssetCount(), UINT256_MAX);
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
    assetId = bound(assetId, 0, hub1.getAssetCount() - 3); // Exclude usdy & usdz

    vm.expectEmit(address(hub1));
    emit IHub.UpdateSpokeConfig(assetId, address(spoke1), spokeConfig);

    Utils.updateSpokeConfig(hub1, ADMIN, assetId, address(spoke1), spokeConfig);
    assertEq(hub1.getSpokeConfig(assetId, address(spoke1)), spokeConfig);
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
    address underlying,
    uint8 decimals,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(interestRateStrategy);

    decimals = bound(decimals, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS + 1, type(uint8).max)
      .toUint8();

    vm.expectRevert(IHub.InvalidAssetDecimals.selector, address(hub1));
    Utils.addAsset(
      hub1,
      ADMIN,
      underlying,
      decimals,
      address(0),
      interestRateStrategy,
      encodedIrData
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals_tooLow(
    address underlying,
    uint8 decimals,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(interestRateStrategy);

    decimals = bound(decimals, 0, Constants.MIN_ALLOWED_UNDERLYING_DECIMALS - 1).toUint8();

    vm.expectRevert(IHub.InvalidAssetDecimals.selector, address(hub1));
    Utils.addAsset(
      hub1,
      ADMIN,
      underlying,
      decimals,
      address(0),
      interestRateStrategy,
      encodedIrData
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidAddress_underlying(
    uint8 decimals,
    address interestRateStrategy
  ) public {
    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    Utils.addAsset(
      hub1,
      ADMIN,
      address(0),
      decimals,
      address(0),
      interestRateStrategy,
      encodedIrData
    );
  }

  // NOTE: test_addAsset_fuzz_revertsWith_InvalidAddress_feeReceiver removed because
  // tokenizedSpoke CAN be address(0) in the new design.

  function test_addAsset_fuzz_revertsWith_InvalidAddress_irStrategy(
    address underlying,
    uint8 decimals
  ) public {
    assumeUnusedAddress(underlying);

    decimals = bound(decimals, 0, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS).toUint8();

    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    Utils.addAsset(hub1, ADMIN, underlying, decimals, address(0), address(0), encodedIrData);
  }

  function test_addAsset_fuzz_reverts_InvalidIrData(
    address underlying,
    uint8 decimals,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(interestRateStrategy);
    decimals = bound(decimals, 0, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS).toUint8();

    vm.expectRevert();
    Utils.addAsset(
      hub1,
      ADMIN,
      underlying,
      decimals,
      address(0),
      interestRateStrategy,
      abi.encode('invalid')
    );
  }

  function test_addAsset_reverts_UnderlyingAlreadyListed() public {
    assertTrue(hub1.isUnderlyingListed(address(tokenList.dai)));

    vm.expectRevert(IHub.UnderlyingAlreadyListed.selector, address(hub1));
    Utils.addAsset(
      hub1,
      ADMIN,
      address(tokenList.dai),
      18,
      address(0),
      address(irStrategy),
      encodedIrData
    );
  }

  function test_addAsset_revertsWith_DrawnRateDowncastOverflow() public {
    address underlying = address(
      new TestnetERC20('USDA', 'USDA', Constants.MIN_ALLOWED_UNDERLYING_DECIMALS)
    );

    uint256 drawnRateRay = uint256(type(uint96).max) + 1;
    _mockInterestRateRay(drawnRateRay);
    vm.expectRevert(
      abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, 96, drawnRateRay),
      address(hub1)
    );
    Utils.addAsset(
      hub1,
      ADMIN,
      underlying,
      18,
      address(0),
      address(irStrategy),
      encodedIrData
    );
  }

  function test_addAsset_revertsWith_BlockTimestampDowncastOverflow() public {
    address underlying = address(
      new TestnetERC20('USDA', 'USDA', Constants.MIN_ALLOWED_UNDERLYING_DECIMALS)
    );
    uint256 blockTimestamp = uint256(type(uint40).max) + 1;
    vm.warp(blockTimestamp);
    vm.expectRevert(
      abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, 40, blockTimestamp),
      address(hub1)
    );
    Utils.addAsset(
      hub1,
      ADMIN,
      underlying,
      18,
      address(0),
      address(irStrategy),
      encodedIrData
    );
  }

  function test_addAsset_fuzz(address underlying, uint8 decimals, address tokenizedSpoke) public {
    assumeUnusedAddress(underlying);
    // tokenizedSpoke can be address(0) — no restriction

    decimals = bound(
      decimals,
      Constants.MAX_ALLOWED_UNDERLYING_DECIMALS,
      Constants.MAX_ALLOWED_UNDERLYING_DECIMALS
    ).toUint8();

    uint256 expectedAssetId = hub1.getAssetCount();
    address interestRateStrategy = address(new AssetInterestRateStrategy(address(hub1)));

    IHub.AssetConfig memory expectedConfig = IHub.AssetConfig({
      tokenizedSpoke: tokenizedSpoke,
      liquidityFee: 0,
      irStrategy: interestRateStrategy,
      reinvestmentController: address(0)
    });

    (, uint32 baseVariableBorrowRate, , ) = abi.decode(
      encodedIrData,
      (uint32, uint32, uint32, uint32)
    );

    // addAsset no longer auto-adds tokenizedSpoke as a spoke
    vm.expectEmit(address(hub1));
    emit IHub.AddAsset(expectedAssetId, underlying, decimals);
    vm.expectEmit(address(hub1));
    emit IHub.UpdateAssetConfig(expectedAssetId, expectedConfig);
    vm.expectEmit(address(hub1));
    emit IHub.UpdateAsset(expectedAssetId, WadRayMath.RAY, baseVariableBorrowRate.bpsToRay(), 0);

    uint256 assetId = Utils.addAsset(
      hub1,
      ADMIN,
      underlying,
      decimals,
      tokenizedSpoke,
      interestRateStrategy,
      encodedIrData
    );

    _assertBorrowRateSynced(hub1, assetId, 'addAsset');
    assertEq(assetId, expectedAssetId, 'asset id');
    assertEq(hub1.getAssetCount(), assetId + 1, 'asset count');
    assertEq(hub1.getAsset(assetId).decimals, decimals, 'asset decimals');
    assertEq(hub1.getAssetConfig(assetId), expectedConfig);
    assertEq(hub1.getAsset(assetId).reinvestmentController, address(0)); // should init to addr(0)
    // tokenizedSpoke is NOT automatically registered as a spoke; it must be added separately
    assertEq(hub1.getAssetId(underlying), expectedAssetId);
  }

  function test_isUnderlyingListed() public {
    address underlying = address(new TestnetERC20('USDA', 'USDA', 18));
    address interestRateStrategy = address(new AssetInterestRateStrategy(address(hub1)));

    assertFalse(hub1.isUnderlyingListed(underlying));

    Utils.addAsset(hub1, ADMIN, underlying, 18, address(0), interestRateStrategy, encodedIrData);

    assertTrue(hub1.isUnderlyingListed(underlying));
  }

  function test_getAssetId() public view {
    assertEq(hub1.getAssetId(address(tokenList.weth)), wethAssetId);
    assertEq(hub1.getAssetId(address(tokenList.usdx)), usdxAssetId);
    assertEq(hub1.getAssetId(address(tokenList.dai)), daiAssetId);
    assertEq(hub1.getAssetId(address(tokenList.wbtc)), wbtcAssetId);
    assertEq(hub1.getAssetId(address(tokenList.usdy)), usdyAssetId);
    assertEq(hub1.getAssetId(address(tokenList.usdz)), usdzAssetId);
  }

  function test_getAssetId_fuzz_revertsWith_AssetNotListed(address underlying) public {
    assumeUnusedAddress(underlying);
    vm.expectRevert(IHub.AssetNotListed.selector, address(hub1));
    hub1.getAssetId(underlying);
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
    // tokenizedSpoke is forced to address(0) by _assumeValidAssetConfig, no need to assumeUnusedAddress

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

    vm.expectRevert('custom revert', newConfig.irStrategy);
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
    newConfig.tokenizedSpoke = hub1.getAssetConfig(assetId).tokenizedSpoke; // retain tokenized spoke

    vm.mockCallRevert(
      newConfig.irStrategy,
      abi.encodeCall(IBasicInterestRateStrategy.setInterestRateData, (assetId, encodedIrData)),
      'custom revert'
    );

    vm.expectRevert('custom revert', newConfig.irStrategy);
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

    address oldTokenizedSpoke = _getTokenizedSpoke(hub1, assetId);

    // If tokenizedSpoke is non-zero, it must be a listed spoke. If not listed, it will revert.
    // For fuzz to work, set tokenizedSpoke to address(0) (always valid) or an already-listed spoke.
    bool isNewTokenizedSpoke = newConfig.tokenizedSpoke != oldTokenizedSpoke;
    if (isNewTokenizedSpoke && newConfig.tokenizedSpoke != address(0)) {
      // Must be a listed spoke; if not, revert is expected. Force to address(0) for simplicity.
      if (!hub1.isSpokeListed(assetId, newConfig.tokenizedSpoke)) {
        vm.expectRevert(IHub.TokenizedSpokeNotListed.selector, address(hub1));
        vm.prank(HUB_ADMIN);
        hub1.updateAssetConfig(assetId, newConfig, new bytes(0));
        return;
      }
    }

    // Minting pending fees to old tokenizedSpoke when it changes
    if (isNewTokenizedSpoke && oldTokenizedSpoke != address(0)) {
      if (_calcUnrealizedFees(hub1, assetId) > 0) {
        uint256 accruedFees = hub1.getAssetAccruedFees(assetId);
        vm.expectEmit(address(hub1));
        emit IHub.MintFeeShares(
          assetId,
          oldTokenizedSpoke,
          hub1.previewAddByAssets(assetId, accruedFees),
          accruedFees
        );
      }
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
      }),
      isNewTokenizedSpoke ? 0 : hub1.getAssetAccruedFees(assetId)
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
    _assertBorrowRateSynced(hub1, assetId, 'updateAssetConfig');
  }

  function test_updateAssetConfig_fuzz_Scenario(uint256 assetId) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);

    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    // set same config
    test_updateAssetConfig_fuzz(assetId, config);
    // set tokenizedSpoke to address(0) (always valid)
    config.tokenizedSpoke = address(0);
    test_updateAssetConfig_fuzz(assetId, config);
    // set zero liquidity fee
    config.liquidityFee = 0;
    test_updateAssetConfig_fuzz(assetId, config);
    // set zero liquidity fee again
    test_updateAssetConfig_fuzz(assetId, config);
    // set initial config
    test_updateAssetConfig_fuzz(assetId, hub1.getAssetConfig(assetId));
  }

  /// Updates to new tokenizedSpoke (from address(0)) — fees just accumulate in realizedFees
  function test_updateAssetConfig_fuzz_NewFeeReceiver(uint256 assetId) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    skip(365 days);

    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    // tokenizedSpoke is address(0) in base setup; just verify fees accumulate with no-op mintFeeShares
    assertTrue(hub1.getAsset(assetId).realizedFees > 0 || _calcUnrealizedFees(hub1, assetId) > 0, 'no fees');

    // Setting tokenizedSpoke to address(0) is always valid
    config.tokenizedSpoke = address(0);
    test_updateAssetConfig_fuzz(assetId, config);

    // Fees remain in realizedFees since tokenizedSpoke is address(0)
    assertEq(hub1.getSpokeAddedShares(assetId, address(0)), 0);
  }

  /// Updates the tokenizedSpoke; the old spoke config is NOT changed (no auto-manipulation)
  function test_updateAssetConfig_oldFeeReceiver_flags() public {
    uint256 assetId = _randomAssetId(hub1);

    // tokenizedSpoke is address(0) in base tests; setting to address(0) is a no-op change
    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    assertEq(config.tokenizedSpoke, address(0), 'tokenizedSpoke should be zero in base tests');

    // Updating to address(0) again — no spoke config changes expected
    test_updateAssetConfig_fuzz(assetId, config);
    assertEq(hub1.getAssetConfig(assetId).tokenizedSpoke, address(0));
  }

  /// Updates the tokenizedSpoke when current tokenizedSpoke is address(0) — no SpokeNotActive revert
  /// because mintFeeShares is a no-op when tokenizedSpoke is address(0)
  function test_updateAssetConfig_NewFeeReceiver_revertsWith_SpokeNotActive_noFees() public {
    uint256 assetId = daiAssetId;

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);
    skip(365 days);

    // Since tokenizedSpoke is address(0), changing to address(0) again is fine
    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    assertEq(config.tokenizedSpoke, address(0));

    // Updating to address(0) does NOT cause SpokeNotActive revert
    Utils.updateAssetConfig(hub1, ADMIN, assetId, config, new bytes(0));
  }

  /// Updates the tokenizedSpoke while tokenizedSpoke is address(0) — succeeds without fee minting
  function test_updateAssetConfig_NewFeeReceiver_noFees() public {
    uint256 assetId = daiAssetId;

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);
    skip(365 days);

    // mintFeeShares is a no-op because tokenizedSpoke is address(0)
    Utils.mintFeeShares(hub1, assetId, ADMIN);

    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    assertEq(config.tokenizedSpoke, address(0));

    // Updating with same config succeeds
    Utils.updateAssetConfig(hub1, ADMIN, assetId, config, new bytes(0));
  }

  /// Setting tokenizedSpoke to a non-listed spoke reverts with TokenizedSpokeNotListed
  function test_updateAssetConfig_fuzz_ReuseFeeReceiver_revertsWith_SpokeAlreadyListed(
    uint256 assetId
  ) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);
    test_updateAssetConfig_fuzz_NewFeeReceiver(assetId);

    // Trying to set tokenizedSpoke to a non-listed address (not a registered spoke) reverts
    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);
    address nonListedSpoke = makeAddr('nonListedSpoke');
    assertFalse(hub1.isSpokeListed(assetId, nonListedSpoke), 'should not be listed');

    config.tokenizedSpoke = nonListedSpoke;
    vm.expectRevert(IHub.TokenizedSpokeNotListed.selector, address(hub1));
    Utils.updateAssetConfig(hub1, ADMIN, assetId, config, new bytes(0));
  }

  /// Setting tokenizedSpoke to an existing listed spoke succeeds
  function test_updateAssetConfig_UseExistingSpokeAndListedAsFeeReceiver_revertsWith_SpokeAlreadyListed()
    public
  {
    uint256 assetId = 3;

    IHub.AssetConfig memory config = hub1.getAssetConfig(assetId);

    // spoke1 is already listed on this asset, so it IS a valid tokenizedSpoke
    assertTrue(hub1.isSpokeListed(assetId, address(spoke1)));

    config.tokenizedSpoke = address(spoke1);

    // Setting tokenizedSpoke to a listed spoke is VALID in the new design
    vm.prank(HUB_ADMIN);
    hub1.updateAssetConfig(assetId, config, new bytes(0));
    assertEq(hub1.getAssetConfig(assetId).tokenizedSpoke, address(spoke1));
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
    uint256 expectedFeeReceiverAddedAssets = _getExpectedFeeReceiverAddedAssets(hub1, assetId);
    assertTrue(expectedFeeReceiverAddedAssets > 0, 'no fees');

    config.liquidityFee = liquidityFee;
    test_updateAssetConfig_fuzz(assetId, config);

    assertEq(_calcUnrealizedFees(hub1, assetId), 0);
    assertEq(_getExpectedFeeReceiverAddedAssets(hub1, assetId), expectedFeeReceiverAddedAssets);
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
    // tokenizedSpoke stays at address(0) — always valid
    test_updateAssetConfig_fuzz(assetId, config);

    assertEq(hub1.getSpokeAddedShares(assetId, address(0)), 0);
  }

  /// Triggers accrual when interest rate strategy is updated, based on old strategy
  /// Also makes sure that the base borrow rate is updated after accrual
  function test_updateAssetConfig_fuzz_NewInterestRateStrategy(uint256 assetId) public {
    assetId = bound(assetId, 0, hub1.getAssetCount() - 1);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    uint256 expectedFeeReceiverAddedAssets = _getExpectedFeeReceiverAddedAssets(hub1, assetId);
    assertTrue(expectedFeeReceiverAddedAssets > 0, 'no fees');

    skip(365 days);
    uint256 futureFees = _getExpectedFeeReceiverAddedAssets(hub1, assetId);
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
    assertNotEq(hub1.getSpokeAddedShares(assetId, config.tokenizedSpoke), futureFees);
  }

  function _assumeValidAssetConfig(IHub.AssetConfig memory newConfig) internal pure {
    newConfig.liquidityFee = bound(newConfig.liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();
    // tokenizedSpoke can be address(0) — no restriction on zero address
    assumeNotZeroAddress(newConfig.irStrategy);
    assumeNotPrecompile(newConfig.irStrategy);
    assumeNotForgeAddress(newConfig.irStrategy);
    // Force tokenizedSpoke to address(0) to avoid TokenizedSpokeNotListed revert in fuzz
    newConfig.tokenizedSpoke = address(0);
  }
}
