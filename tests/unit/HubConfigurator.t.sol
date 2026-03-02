// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubConfiguratorTest is HubBase {
  using SafeCast for uint256;

  HubConfigurator internal hubConfigurator;

  uint256 internal _assetId;
  bytes internal _encodedIrData;

  address[3] public spokeAddresses;
  address spoke;

  mapping(address => uint24) public riskPremiumThresholdsPerSpoke; // spoke address => risk premium threshold
  mapping(uint256 => uint24) public riskPremiumThresholdsPerAsset; // assetId => risk premium threshold

  function setUp() public virtual override {
    super.setUp();
    hubConfigurator = new HubConfigurator(hub1.authority());
    setUpHubConfiguratorRoles(address(hubConfigurator), hub1.authority());

    _assetId = daiAssetId;
    _encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
    // treasurySpoke is no longer auto-registered as a spoke; only spoke1/spoke2/spoke3 are registered for daiAssetId
    spokeAddresses = [address(spoke1), address(spoke2), address(spoke3)];
    spoke = address(spoke1);
  }

  function test_addAsset_fuzz_revertsWith_AccessManagedUnauthorized(address caller) public {
    vm.assume(caller != HUB_CONFIGURATOR);

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    _addAsset({
      fetchErc20Decimals: vm.randomBool(),
      underlying: vm.randomAddress(),
      decimals: vm
        .randomUint(
          Constants.MIN_ALLOWED_UNDERLYING_DECIMALS,
          Constants.MAX_ALLOWED_UNDERLYING_DECIMALS
        )
        .toUint8(),
      tokenizedSpoke: address(0),
      liquidityFee: vm.randomUint(),
      interestRateStrategy: vm.randomAddress(),
      encodedIrData: _encodedIrData
    });
  }

  function test_addAsset_reverts_invalidIrData() public {
    vm.expectRevert();
    vm.prank(HUB_CONFIGURATOR);
    _addAsset({
      fetchErc20Decimals: vm.randomBool(),
      underlying: vm.randomAddress(),
      decimals: 10,
      tokenizedSpoke: address(0),
      liquidityFee: vm.randomUint(),
      interestRateStrategy: vm.randomAddress(),
      encodedIrData: abi.encode('invalid')
    });
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    uint256 liquidityFee,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(interestRateStrategy);

    decimals = bound(decimals, Constants.MAX_ALLOWED_UNDERLYING_DECIMALS + 1, type(uint8).max)
      .toUint8();
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);

    vm.expectRevert(IHub.InvalidAssetDecimals.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR);
    _addAsset(
      fetchErc20Decimals,
      underlying,
      decimals,
      address(0),
      liquidityFee,
      interestRateStrategy,
      _encodedIrData
    );
  }

  function test_addAsset_revertsWith_InvalidAddress_underlying() public {
    uint8 decimals = uint8(
      vm.randomUint(
        Constants.MIN_ALLOWED_UNDERLYING_DECIMALS,
        Constants.MAX_ALLOWED_UNDERLYING_DECIMALS
      )
    );
    address interestRateStrategy = makeAddr('newIrStrategy');
    uint256 liquidityFee = vm.randomUint(0, PercentageMath.PERCENTAGE_FACTOR);

    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR);
    _addAsset(
      true,
      address(0),
      decimals,
      address(0),
      liquidityFee,
      interestRateStrategy,
      _encodedIrData
    );
  }

  function test_addAsset_revertsWith_InvalidAddress_irStrategy() public {
    address underlying = makeAddr('newUnderlying');
    uint8 decimals = uint8(
      vm.randomUint(
        Constants.MIN_ALLOWED_UNDERLYING_DECIMALS,
        Constants.MAX_ALLOWED_UNDERLYING_DECIMALS
      )
    );
    uint256 liquidityFee = vm.randomUint(0, PercentageMath.PERCENTAGE_FACTOR);

    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR);
    _addAsset(true, underlying, decimals, address(0), liquidityFee, address(0), _encodedIrData);
  }

  function test_addAsset_revertsWith_InvalidLiquidityFee() public {
    address underlying = makeAddr('newUnderlying');
    uint8 decimals = uint8(
      vm.randomUint(
        Constants.MIN_ALLOWED_UNDERLYING_DECIMALS,
        Constants.MAX_ALLOWED_UNDERLYING_DECIMALS
      )
    );
    address interestRateStrategy = address(new AssetInterestRateStrategy(address(hub1)));
    uint256 liquidityFee = vm.randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max);

    vm.expectRevert(IHub.InvalidLiquidityFee.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR);
    _addAsset(
      false,
      underlying,
      decimals,
      address(0),
      liquidityFee,
      interestRateStrategy,
      _encodedIrData
    );
  }

  function test_addAsset_fuzz(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    uint256 liquidityFee,
    uint16 optimalUsageRatio,
    uint32 baseVariableBorrowRate,
    uint32 variableRateSlope1,
    uint32 variableRateSlope2
  ) public {
    assumeUnusedAddress(underlying);
    // tokenizedSpoke CAN be address(0) — use address(0) to avoid TokenizedSpokeNotListed error

    decimals = bound(
      decimals,
      Constants.MIN_ALLOWED_UNDERLYING_DECIMALS,
      Constants.MAX_ALLOWED_UNDERLYING_DECIMALS
    ).toUint8();
    optimalUsageRatio = bound(optimalUsageRatio, MIN_OPTIMAL_RATIO, MAX_OPTIMAL_RATIO).toUint16();
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);

    baseVariableBorrowRate = bound(baseVariableBorrowRate, 0, MAX_BORROW_RATE / 3).toUint32();
    uint32 remainingAfterBase = MAX_BORROW_RATE.toUint32() - baseVariableBorrowRate;
    variableRateSlope1 = bound(variableRateSlope1, 0, remainingAfterBase / 2).toUint32();
    variableRateSlope2 = bound(
      variableRateSlope2,
      variableRateSlope1,
      MAX_BORROW_RATE - baseVariableBorrowRate - variableRateSlope1
    ).toUint32();

    uint256 expectedAssetId = hub1.getAssetCount();
    address interestRateStrategy = address(new AssetInterestRateStrategy(address(hub1)));

    _encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: optimalUsageRatio,
        baseVariableBorrowRate: baseVariableBorrowRate,
        variableRateSlope1: variableRateSlope1,
        variableRateSlope2: variableRateSlope2
      })
    );

    IHub.AssetConfig memory expectedConfig = IHub.AssetConfig({
      liquidityFee: liquidityFee.toUint16(),
      tokenizedSpoke: address(0),
      irStrategy: interestRateStrategy,
      reinvestmentController: address(0)
    });

    vm.expectCall(
      address(hub1),
      abi.encodeCall(
        IHub.addAsset,
        (underlying, decimals, address(0), interestRateStrategy, _encodedIrData)
      )
    );

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateAssetConfig, (hub1.getAssetCount(), expectedConfig, new bytes(0)))
    );

    vm.prank(HUB_CONFIGURATOR);
    _assetId = _addAsset(
      fetchErc20Decimals,
      underlying,
      decimals,
      address(0),
      liquidityFee,
      interestRateStrategy,
      _encodedIrData
    );

    assertEq(_assetId, expectedAssetId, 'asset id');
    assertEq(hub1.getAssetCount(), _assetId + 1, 'asset count');
    assertEq(hub1.getAsset(_assetId).decimals, decimals, 'asset decimals');
    assertEq(hub1.getAssetConfig(_assetId), expectedConfig);
    // tokenizedSpoke is NOT auto-registered as a spoke in the new design
    assertEq(hub1.getAsset(_assetId).reinvestmentController, address(0)); // should init to addr(0)
  }

  function test_updateLiquidityFee_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.updateLiquidityFee(address(hub1), vm.randomUint(), vm.randomUint());
  }

  function test_updateLiquidityFee_revertsWith_InvalidLiquidityFee() public {
    _assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    uint16 liquidityFee = uint16(
      vm.randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max)
    );

    vm.expectRevert(IHub.InvalidLiquidityFee.selector);
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateLiquidityFee(address(hub1), _assetId, liquidityFee);
  }

  function test_updateLiquidityFee_fuzz(uint256 assetId, uint16 liquidityFee) public {
    _assetId = bound(assetId, 0, hub1.getAssetCount() - 1);
    liquidityFee = uint16(bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR));

    IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(_assetId);
    expectedConfig.liquidityFee = liquidityFee;

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateAssetConfig, (_assetId, expectedConfig, new bytes(0)))
    );

    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateLiquidityFee(address(hub1), _assetId, expectedConfig.liquidityFee);

    assertEq(hub1.getAssetConfig(_assetId), expectedConfig);
  }

  function test_updateTokenizedSpoke_fuzz_revertsWith_AccessManagedUnauthorized(
    address caller
  ) public {
    vm.assume(caller != HUB_CONFIGURATOR);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    hubConfigurator.updateTokenizedSpoke(address(hub1), vm.randomUint(), vm.randomAddress());
  }

  /// @dev Setting tokenizedSpoke to address(0) when it is already address(0) is a no-op — does not revert
  function test_updateTokenizedSpoke_noopWhenAlreadyZero() public {
    _assetId = vm.randomUint(0, hub1.getAssetCount() - 1);

    IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(_assetId);
    expectedConfig.tokenizedSpoke = address(0);

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateAssetConfig, (_assetId, expectedConfig, new bytes(0)))
    );
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateTokenizedSpoke(address(hub1), _assetId, address(0));

    assertEq(hub1.getAssetConfig(_assetId), expectedConfig);
  }

  /// @dev Setting tokenizedSpoke to a non-listed, non-zero address reverts with TokenizedSpokeNotListed
  function test_updateTokenizedSpoke_fuzz(address tokenizedSpoke) public {
    IHub.AssetConfig memory oldConfig = hub1.getAssetConfig(_assetId);
    IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(_assetId);

    if (tokenizedSpoke != oldConfig.tokenizedSpoke) {
      if (hub1.isSpokeListed(_assetId, tokenizedSpoke)) {
        expectedConfig.tokenizedSpoke = tokenizedSpoke;
        vm.expectCall(
          address(hub1),
          abi.encodeCall(IHub.updateAssetConfig, (_assetId, expectedConfig, new bytes(0)))
        );
      } else {
        // non-listed tokenizedSpoke (including address(0)) reverts
        vm.expectRevert(IHub.TokenizedSpokeNotListed.selector, address(hub1));
      }
    }
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateTokenizedSpoke(address(hub1), _assetId, tokenizedSpoke);

    if (hub1.isSpokeListed(_assetId, tokenizedSpoke)) {
      assertEq(hub1.getAssetConfig(_assetId), expectedConfig);
    }
  }

  /// @dev Setting tokenizedSpoke to a listed spoke succeeds
  function test_updateTokenizedSpoke_revertsWith_TokenizedSpokeNotListed() public {
    address nonListedSpoke = makeAddr('nonListedSpoke');
    assertFalse(hub1.isSpokeListed(_assetId, nonListedSpoke), 'should not be listed');

    vm.expectRevert(IHub.TokenizedSpokeNotListed.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateTokenizedSpoke(address(hub1), _assetId, nonListedSpoke);
  }

  /// @dev Setting tokenizedSpoke to an already-listed spoke (e.g. spoke1) succeeds
  function test_updateTokenizedSpoke_succeeds_withListedSpoke() public {
    assertTrue(hub1.isSpokeListed(_assetId, address(spoke1)));

    IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(_assetId);
    expectedConfig.tokenizedSpoke = address(spoke1);

    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateTokenizedSpoke(address(hub1), _assetId, address(spoke1));

    assertEq(hub1.getAssetConfig(_assetId).tokenizedSpoke, address(spoke1));
  }

  function test_updateTokenizedSpoke_Scenario() public {
    // address(0) → address(0): no-op, no revert
    test_updateTokenizedSpoke_fuzz(address(0));
    // address(0) → listed spoke: succeeds
    test_updateTokenizedSpoke_fuzz(address(spoke1));
  }

  function test_updateFeeConfig_fuzz_revertsWith_AccessManagedUnauthorized(address caller) public {
    vm.assume(caller != HUB_CONFIGURATOR);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    hubConfigurator.updateFeeConfig({
      hub: address(hub1),
      assetId: vm.randomUint(),
      liquidityFee: vm.randomUint(),
      tokenizedSpoke: vm.randomAddress()
    });
  }

  /// @dev Passing address(0) for tokenizedSpoke when it is already address(0) is a no-op — does not revert
  function test_updateFeeConfig_noopWhenAlreadyZero() public {
    uint256 assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    uint256 liquidityFee = vm.randomUint(1, PercentageMath.PERCENTAGE_FACTOR);

    IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(assetId);
    expectedConfig.liquidityFee = uint16(liquidityFee);
    // tokenizedSpoke stays address(0) — no change, so no TokenizedSpokeNotListed revert

    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateFeeConfig(address(hub1), assetId, liquidityFee, address(0));
    assertEq(hub1.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateFeeConfig_revertsWith_InvalidLiquidityFee() public {
    uint256 assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    uint16 liquidityFee = uint16(
      vm.randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max)
    );
    address tokenizedSpoke = hub1.getAssetConfig(assetId).tokenizedSpoke;

    vm.expectRevert(IHub.InvalidLiquidityFee.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateFeeConfig(address(hub1), assetId, liquidityFee, tokenizedSpoke);
  }

  function test_updateFeeConfig_fuzz(
    uint256 assetId_,
    uint16 liquidityFee,
    address tokenizedSpoke
  ) public {
    assetId_ = bound(assetId_, 0, hub1.getAssetCount() - 1);
    liquidityFee = uint16(bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR));
    // tokenizedSpoke can be address(0) or any listed spoke

    IHub.AssetConfig memory oldConfig = hub1.getAssetConfig(assetId_);
    IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(assetId_);
    expectedConfig.liquidityFee = liquidityFee;

    if (oldConfig.tokenizedSpoke != tokenizedSpoke) {
      if (hub1.isSpokeListed(assetId_, tokenizedSpoke)) {
        expectedConfig.tokenizedSpoke = tokenizedSpoke;
        vm.expectCall(
          address(hub1),
          abi.encodeCall(IHub.updateAssetConfig, (assetId_, expectedConfig, new bytes(0)))
        );
      } else {
        expectedConfig.liquidityFee = oldConfig.liquidityFee;
        // non-listed tokenizedSpoke (including address(0)) reverts
        vm.expectRevert(IHub.TokenizedSpokeNotListed.selector, address(hub1));
      }
    }
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateFeeConfig(address(hub1), assetId_, liquidityFee, tokenizedSpoke);
    if (hub1.isSpokeListed(assetId_, tokenizedSpoke)) {
      assertEq(hub1.getAssetConfig(assetId_), expectedConfig);
    }
  }

  function test_updateFeeConfig_Scenario() public {
    // change liquidity fee only (tokenizedSpoke stays address(0), no-op change)
    test_updateFeeConfig_fuzz(0, 18_00, address(0));
    // set tokenizedSpoke to a listed spoke
    test_updateFeeConfig_fuzz(0, 4_00, address(spoke1));
    // change liquidity fee only (tokenizedSpoke stays spoke1, no-op change)
    test_updateFeeConfig_fuzz(0, 0, address(spoke1));
  }

  function test_updateInterestRateStrategy_fuzz_revertsWith_AccessManagedUnauthorized(
    address caller
  ) public {
    vm.assume(caller != HUB_CONFIGURATOR);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    hubConfigurator.updateInterestRateStrategy(
      address(hub1),
      vm.randomUint(),
      vm.randomAddress(),
      _encodedIrData
    );
  }

  function test_updateInterestRateStrategy() public {
    address interestRateStrategy = makeAddr('newInterestRateStrategy');

    IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(_assetId);
    expectedConfig.irStrategy = interestRateStrategy;
    _mockInterestRateBps(interestRateStrategy, 5_00);

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateAssetConfig, (_assetId, expectedConfig, _encodedIrData))
    );

    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateInterestRateStrategy(
      address(hub1),
      _assetId,
      interestRateStrategy,
      _encodedIrData
    );

    assertEq(hub1.getAssetConfig(_assetId), expectedConfig);
  }

  function test_updateInterestRateStrategy_revertsWith_InvalidAddress_irStrategy() public {
    _assetId = vm.randomUint(0, hub1.getAssetCount() - 1);

    vm.expectRevert(IHub.InvalidAddress.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateInterestRateStrategy(address(hub1), _assetId, address(0), _encodedIrData);
  }

  function test_updateInterestRateStrategy_revertsWith_InterestRateStrategyReverts() public {
    _assetId = vm.randomUint(0, hub1.getAssetCount() - 1);
    address interestRateStrategy = makeAddr('newInterestRateStrategy');

    vm.expectRevert();
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateInterestRateStrategy(
      address(hub1),
      _assetId,
      interestRateStrategy,
      _encodedIrData
    );
  }

  function test_updateInterestRateStrategy_revertsWith_InvalidInterestRateStrategy() public {
    vm.expectRevert(IHub.InvalidInterestRateStrategy.selector, address(hub1));
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateInterestRateStrategy(
      address(hub1),
      _assetId,
      address(irStrategy),
      _encodedIrData
    );
  }

  function test_updateReinvestmentController_fuzz_revertsWith_AccessManagedUnauthorized(
    address caller
  ) public {
    vm.assume(caller != HUB_CONFIGURATOR);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    hubConfigurator.updateReinvestmentController(
      address(hub1),
      vm.randomUint(),
      vm.randomAddress()
    );
  }

  function test_updateReinvestmentController() public {
    address reinvestmentController = makeAddr('newReinvestmentController');
    IHub.AssetConfig memory expectedConfig = hub1.getAssetConfig(_assetId);
    expectedConfig.reinvestmentController = reinvestmentController;
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateAssetConfig, (_assetId, expectedConfig, new bytes(0)))
    );
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateReinvestmentController(address(hub1), _assetId, reinvestmentController);

    assertEq(hub1.getAssetConfig(_assetId), expectedConfig);
  }

  function test_resetAssetCaps_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.resetAssetCaps(address(hub1), _assetId);
  }

  function test_resetAssetCaps() public {
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

    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.resetAssetCaps(address(hub1), _assetId);

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
    hubConfigurator.deactivateAsset(address(hub1), _assetId);
  }

  function test_deactivateAsset() public {
    for (uint256 i; i < spokeAddresses.length; i++) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, spokeAddresses[i]);
      spokeConfig.active = false;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spokeAddresses[i], spokeConfig))
      );
    }

    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.deactivateAsset(address(hub1), _assetId);

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
    hubConfigurator.haltAsset(address(hub1), _assetId);
  }

  function test_haltAsset() public {
    for (uint256 i; i < spokeAddresses.length; i++) {
      IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(_assetId, spokeAddresses[i]);
      spokeConfig.halted = true;
      vm.expectCall(
        address(hub1),
        abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spokeAddresses[i], spokeConfig))
      );
    }

    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.haltAsset(address(hub1), _assetId);

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
    hubConfigurator.addSpoke(address(hub1), vm.randomAddress(), 0, spokeConfig);
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
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.addSpoke(address(hub1), newSpoke, daiAssetId, daiSpokeConfig);

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
      new uint256[](0),
      new IHub.SpokeConfig[](0)
    );
  }

  function test_addSpokeToAssets_revertsWith_MismatchedConfigs() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

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
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.addSpokeToAssets(address(hub1), spoke, assetIds, spokeConfigs);
  }

  function test_addSpokeToAssets() public {
    address newSpoke = makeAddr('newSpoke');

    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

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
    vm.expectEmit(address(hub1));
    emit IHub.AddSpoke(wethAssetId, newSpoke);
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.addSpokeToAssets(address(hub1), newSpoke, assetIds, spokeConfigs);

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
    hubConfigurator.updateSpokeHalted(address(hub1), _assetId, spokeAddresses[0], false);
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
      vm.prank(HUB_CONFIGURATOR);
      hubConfigurator.updateSpokeHalted(address(hub1), _assetId, spoke, halted);
      assertEq(hub1.getSpokeConfig(_assetId, spoke), expectedSpokeConfig);
    }
  }

  function test_updateSpokeActive_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.updateSpokeActive(address(hub1), _assetId, spokeAddresses[0], true);
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
      vm.prank(HUB_CONFIGURATOR);
      hubConfigurator.updateSpokeActive(address(hub1), _assetId, spoke, active);
      assertEq(hub1.getSpokeConfig(_assetId, spoke), expectedSpokeConfig);
    }
  }

  function test_updateSpokeSupplyCap_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.updateSpokeSupplyCap(address(hub1), _assetId, spokeAddresses[0], 100);
  }

  function test_updateSpokeSupplyCap() public {
    uint40 newSupplyCap = 100;
    IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(_assetId, spoke);
    expectedSpokeConfig.addCap = newSupplyCap;
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spoke, expectedSpokeConfig))
    );
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateSpokeSupplyCap(address(hub1), _assetId, spoke, newSupplyCap);
    assertEq(hub1.getSpokeConfig(_assetId, spoke), expectedSpokeConfig);
  }

  function test_updateSpokeDrawCap_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.updateSpokeDrawCap(address(hub1), _assetId, spokeAddresses[0], 100);
  }

  function test_updateSpokeDrawCap() public {
    uint40 newDrawCap = 100;
    IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(_assetId, spoke);
    expectedSpokeConfig.drawCap = newDrawCap;
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spoke, expectedSpokeConfig))
    );
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateSpokeDrawCap(address(hub1), _assetId, spoke, newDrawCap);
    assertEq(hub1.getSpokeConfig(_assetId, spoke), expectedSpokeConfig);
  }

  function test_updateSpokeRiskPremiumThreshold_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hubConfigurator.updateSpokeRiskPremiumThreshold(
      address(hub1),
      _assetId,
      spokeAddresses[0],
      100
    );
  }

  function test_updateSpokeRiskPremiumThreshold() public {
    uint24 newRiskPremiumThreshold = 100;
    IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(_assetId, spoke);
    expectedSpokeConfig.riskPremiumThreshold = newRiskPremiumThreshold;
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spoke, expectedSpokeConfig))
    );
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateSpokeRiskPremiumThreshold(
      address(hub1),
      _assetId,
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
    hubConfigurator.updateSpokeCaps(address(hub1), _assetId, spokeAddresses[0], 100, 100);
  }

  function test_updateSpokeCaps() public {
    uint40 newSupplyCap = 100;
    uint40 newDrawCap = 200;
    IHub.SpokeConfig memory expectedSpokeConfig = hub1.getSpokeConfig(_assetId, spoke);
    expectedSpokeConfig.addCap = newSupplyCap;
    expectedSpokeConfig.drawCap = newDrawCap;
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.updateSpokeConfig, (_assetId, spoke, expectedSpokeConfig))
    );
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateSpokeCaps(address(hub1), _assetId, spoke, newSupplyCap, newDrawCap);
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
    }

    for (uint256 assetId = 4; assetId < hub1.getAssetCount(); ++assetId) {
      vm.expectCall(address(hub1), abi.encodeCall(IHub.isSpokeListed, (assetId, address(spoke3))));
    }

    vm.prank(HUB_CONFIGURATOR);
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
    }

    for (uint256 assetId = 4; assetId < hub1.getAssetCount(); ++assetId) {
      vm.expectCall(address(hub1), abi.encodeCall(IHub.isSpokeListed, (assetId, address(spoke3))));
    }

    vm.prank(HUB_CONFIGURATOR);
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

      riskPremiumThresholdsPerAsset[assetId] = expectedSpokeConfig.riskPremiumThreshold;
    }

    for (uint256 assetId = 4; assetId < hub1.getAssetCount(); ++assetId) {
      vm.expectCall(address(hub1), abi.encodeCall(IHub.isSpokeListed, (assetId, address(spoke3))));
    }

    vm.prank(HUB_CONFIGURATOR);
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
    hubConfigurator.updateInterestRateData(address(hub1), _assetId, vm.randomBytes(32));
  }

  function test_updateInterestRateData() public {
    IAssetInterestRateStrategy.InterestRateData memory newIrData = IAssetInterestRateStrategy
      .InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      });

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHub.setInterestRateData, (_assetId, abi.encode(newIrData)))
    );
    vm.prank(HUB_CONFIGURATOR);
    hubConfigurator.updateInterestRateData(address(hub1), _assetId, abi.encode(newIrData));

    assertEq(irStrategy.getInterestRateData(_assetId), newIrData);
  }

  function _addAsset(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    address tokenizedSpoke,
    uint256 liquidityFee,
    address interestRateStrategy,
    bytes memory encodedIrData
  ) internal returns (uint256) {
    if (fetchErc20Decimals) {
      _mockDecimals(underlying, decimals);
      return
        hubConfigurator.addAsset(
          address(hub1),
          underlying,
          tokenizedSpoke,
          liquidityFee,
          interestRateStrategy,
          encodedIrData
        );
    } else {
      return
        hubConfigurator.addAssetWithDecimals(
          address(hub1),
          underlying,
          decimals,
          tokenizedSpoke,
          liquidityFee,
          interestRateStrategy,
          encodedIrData
        );
    }
  }
}
