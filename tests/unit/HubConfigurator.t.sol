// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract HubConfiguratorTest is LiquidityHubBase {
  HubConfigurator public hubConfigurator;

  address public HUB_CONFIGURATOR_ADMIN = makeAddr('HUB_CONFIGURATOR_ADMIN');
  uint256 public assetId;
  bytes public encodedIrData;

  address[4] public spokeAddresses;
  address spoke;

  function setUp() public virtual override {
    super.setUp();
    hubConfigurator = new HubConfigurator(HUB_CONFIGURATOR_ADMIN);
    IAccessManager accessManager = IAccessManager(hub.authority());
    // Grant hubConfigurator hub admin role with 0 delay
    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, address(hubConfigurator), 0);
    assetId = daiAssetId;
    encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );

    spokeAddresses = [address(spoke1), address(spoke2), address(spoke3), address(treasurySpoke)];
    spoke = address(spoke1);
  }

  function test_addAsset_fuzz_revertsWith_OwnableUnauthorizedAccount(address caller) public {
    vm.assume(caller != HUB_CONFIGURATOR_ADMIN);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    _addAsset({
      fetchErc20Decimals: vm.randomBool(),
      underlying: vm.randomAddress(),
      decimals: uint8(vm.randomUint()),
      feeReceiver: vm.randomAddress(),
      interestRateStrategy: vm.randomAddress(),
      encodedIrData: encodedIrData
    });
  }

  function test_addAsset_reverts_invalidIrData() public {
    vm.expectRevert();
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    _addAsset({
      fetchErc20Decimals: vm.randomBool(),
      underlying: vm.randomAddress(),
      decimals: uint8(10),
      feeReceiver: vm.randomAddress(),
      interestRateStrategy: vm.randomAddress(),
      encodedIrData: abi.encode('invalid')
    });
  }

  function test_addAsset_revertsWith_InvalidAssetDecimals() public {
    uint8 decimals = hub.MAX_ALLOWED_ASSET_DECIMALS() + 1;
    address underlying = makeAddr('newUnderlying');
    address feeReceiver = makeAddr('newFeeReceiver');
    address interestRateStrategy = makeAddr('newIrStrategy');

    vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector, address(hub));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    _addAsset(true, underlying, decimals, feeReceiver, interestRateStrategy, encodedIrData);
  }

  function test_addAsset_revertsWith_InvalidUnderlying() public {
    uint8 decimals = uint8(vm.randomUint(0, hub.MAX_ALLOWED_ASSET_DECIMALS()));
    address feeReceiver = makeAddr('newFeeReceiver');
    address interestRateStrategy = makeAddr('newIrStrategy');

    vm.expectRevert(ILiquidityHub.InvalidUnderlying.selector, address(hub));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    _addAsset(true, address(0), decimals, feeReceiver, interestRateStrategy, encodedIrData);
  }

  function test_addAsset_revertsWith_InvalidIrStrategy() public {
    address underlying = makeAddr('newUnderlying');
    uint8 decimals = uint8(vm.randomUint(0, hub.MAX_ALLOWED_ASSET_DECIMALS()));
    address feeReceiver = makeAddr('newFeeReceiver');

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector, address(hub));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    _addAsset(true, underlying, decimals, feeReceiver, address(0), encodedIrData);
  }

  function test_addAsset_fuzz(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    uint16 optimalUsageRatio,
    uint32 baseVariableBorrowRate,
    uint32 variableRateSlope1,
    uint32 variableRateSlope2
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);

    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));
    optimalUsageRatio = uint16(bound(optimalUsageRatio, MIN_OPTIMAL_RATIO, MAX_OPTIMAL_RATIO));

    baseVariableBorrowRate = uint32(bound(baseVariableBorrowRate, 0, MAX_BORROW_RATE / 3));
    uint32 remainingAfterBase = uint32(MAX_BORROW_RATE - baseVariableBorrowRate);
    variableRateSlope1 = uint32(bound(variableRateSlope1, 0, remainingAfterBase / 2));
    variableRateSlope2 = uint32(
      bound(
        variableRateSlope2,
        variableRateSlope1,
        MAX_BORROW_RATE - baseVariableBorrowRate - variableRateSlope1
      )
    );

    uint256 expectedAssetId = hub.getAssetCount();
    address interestRateStrategy = address(new AssetInterestRateStrategy(address(hub)));

    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: optimalUsageRatio,
        baseVariableBorrowRate: baseVariableBorrowRate,
        variableRateSlope1: variableRateSlope1,
        variableRateSlope2: variableRateSlope2
      })
    );

    DataTypes.AssetConfig memory expectedConfig = DataTypes.AssetConfig({
      liquidityFee: 0,
      feeReceiver: feeReceiver,
      irStrategy: interestRateStrategy
    });
    DataTypes.SpokeConfig memory expectedSpokeConfig = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max,
      active: true
    });

    vm.expectCall(
      address(hub),
      abi.encodeCall(
        ILiquidityHub.addAsset,
        (underlying, decimals, feeReceiver, interestRateStrategy, encodedIrData)
      )
    );

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.addSpoke, (expectedAssetId, feeReceiver, expectedSpokeConfig))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    uint256 assetId = _addAsset(
      fetchErc20Decimals,
      underlying,
      decimals,
      feeReceiver,
      interestRateStrategy,
      encodedIrData
    );

    assertEq(assetId, expectedAssetId, 'asset id');
    assertEq(hub.getAssetCount(), assetId + 1, 'asset count');
    assertEq(hub.getAsset(assetId).decimals, decimals, 'asset decimals');
    assertEq(hub.getAssetConfig(assetId), expectedConfig);
    assertEq(hub.getSpokeConfig(assetId, feeReceiver), expectedSpokeConfig);
  }

  function test_updateLiquidityFee_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateLiquidityFee(address(hub), vm.randomUint(), vm.randomUint());
  }

  function test_updateLiquidityFee_revertsWith_InvalidLiquidityFee() public {
    uint256 assetId = vm.randomUint(0, hub.getAssetCount() - 1);
    uint256 liquidityFee = vm.randomUint(
      PercentageMathExtended.PERCENTAGE_FACTOR + 1,
      type(uint256).max
    );

    vm.expectRevert(ILiquidityHub.InvalidLiquidityFee.selector);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateLiquidityFee(address(hub), assetId, liquidityFee);
  }

  function test_updateLiquidityFee_fuzz(uint256 assetId, uint256 liquidityFee) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    liquidityFee = bound(liquidityFee, 0, PercentageMathExtended.PERCENTAGE_FACTOR);

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.liquidityFee = liquidityFee;

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateLiquidityFee(address(hub), assetId, liquidityFee);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateFeeReceiver_revertsWith_OwnableUnauthorizedAccount(address caller) public {
    vm.assume(caller != HUB_CONFIGURATOR_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    hubConfigurator.updateFeeReceiver(address(hub), vm.randomUint(), vm.randomAddress());
  }

  function test_updateFeeReceiver_revertsWith_InvalidSpoke() public {
    uint256 assetId = vm.randomUint(0, hub.getAssetCount() - 1);

    vm.expectRevert(ILiquidityHub.InvalidSpoke.selector);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeReceiver(address(hub), assetId, address(0));
  }

  function test_updateFeeReceiver_fuzz(address feeReceiver) public {
    assumeNotZeroAddress(feeReceiver);

    DataTypes.AssetConfig memory oldConfig = hub.getAssetConfig(assetId);

    if (feeReceiver != oldConfig.feeReceiver) {
      vm.expectCall(
        address(hub),
        abi.encodeCall(
          ILiquidityHub.updateSpokeConfig,
          (
            assetId,
            oldConfig.feeReceiver,
            DataTypes.SpokeConfig({
              supplyCap: 0,
              drawCap: 0,
              active: hub.getSpokeConfig(assetId, oldConfig.feeReceiver).active
            })
          )
        )
      );

      if (!hub.isSpokeListed(assetId, feeReceiver)) {
        vm.expectCall(
          address(hub),
          abi.encodeCall(
            ILiquidityHub.addSpoke,
            (
              assetId,
              feeReceiver,
              DataTypes.SpokeConfig({
                supplyCap: type(uint256).max,
                drawCap: type(uint256).max,
                active: true
              })
            )
          )
        );
      } else {
        vm.expectCall(
          address(hub),
          abi.encodeCall(
            ILiquidityHub.updateSpokeConfig,
            (
              assetId,
              feeReceiver,
              DataTypes.SpokeConfig({
                supplyCap: type(uint256).max,
                drawCap: type(uint256).max,
                active: hub.getSpokeConfig(assetId, feeReceiver).active
              })
            )
          )
        );
      }

      // same struct, renaming to expectedConfig
      DataTypes.AssetConfig memory expectedConfig = oldConfig;
      expectedConfig.feeReceiver = feeReceiver;

      vm.expectCall(
        address(hub),
        abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
      );

      vm.prank(HUB_CONFIGURATOR_ADMIN);
      hubConfigurator.updateFeeReceiver(address(hub), assetId, feeReceiver);

      assertEq(hub.getAssetConfig(assetId), expectedConfig);
    }
  }

  /// @dev Test update fee receiver and fees can still be withdrawn from old fee receiver
  function test_updateFeeReceiver_WithdrawFromOldSpoke() public {
    assertEq(
      hub.getAssetConfig(daiAssetId).feeReceiver,
      address(treasurySpoke),
      'current fee receiver matches treasury spoke'
    );

    // Create debt to build up fees on the existing treasury spoke
    _openDebtPosition(spoke1, _daiReserveId(spoke1), 100e18, true);
    skip(365 days);

    assertGe(treasurySpoke.getSuppliedShares(daiAssetId), 0);
    uint256 fees = treasurySpoke.getSuppliedAmount(daiAssetId);

    // Change the fee receiver
    TreasurySpoke newTreasurySpoke = new TreasurySpoke(HUB_ADMIN, address(hub));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeReceiver(address(hub), daiAssetId, address(newTreasurySpoke));

    assertEq(
      hub.getAssetConfig(daiAssetId).feeReceiver,
      address(newTreasurySpoke),
      'new fee receiver updated'
    );
    assertTrue(
      hub.getSpokeConfig(daiAssetId, address(treasurySpoke)).active,
      'old fee receiver is not active'
    );

    // Withdraw fees from the old treasury spoke
    Utils.withdraw(_treasurySpoke(), daiAssetId, TREASURY_ADMIN, fees, address(treasurySpoke));

    assertEq(treasurySpoke.getSuppliedAmount(daiAssetId), 0, 'old treasury spoke should be empty');

    // Accrue more fees, this time to new fee receiver
    skip(365 days);

    assertGt(
      newTreasurySpoke.getSuppliedAmount(daiAssetId),
      0,
      'new fee receiver should have accrued fees'
    );
    assertEq(treasurySpoke.getSuppliedAmount(daiAssetId), 0, 'old fee receiver should be empty');
  }

  /// @dev Test update fee receiver and old fee receiver still accrues fees
  function test_updateFeeReceiver_correctAccruals() public {
    // Ensure current fee receiver is the treasury spoke
    assertEq(
      hub.getAssetConfig(daiAssetId).feeReceiver,
      address(treasurySpoke),
      'old fee receiver mismatch'
    );

    // Create debt to build up fees on the existing treasury spoke
    _openDebtPosition(spoke1, _daiReserveId(spoke1), 100e18, true);
    skip(365 days);

    assertGe(treasurySpoke.getSuppliedShares(daiAssetId), 0);
    uint256 feeShares = treasurySpoke.getSuppliedShares(daiAssetId);

    // Change the fee receiver
    TreasurySpoke newTreasurySpoke = new TreasurySpoke(HUB_ADMIN, address(hub));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeReceiver(address(hub), daiAssetId, address(newTreasurySpoke));

    // Ensure fee receiver was updated
    assertEq(
      hub.getAssetConfig(daiAssetId).feeReceiver,
      address(newTreasurySpoke),
      'new fee receiver mismatch'
    );

    // Ensure old fee receiver is still active
    assertTrue(
      hub.getSpokeConfig(daiAssetId, address(treasurySpoke)).active,
      'old fee receiver is not active'
    );

    // Withdraw half the fee shares from the old treasury spoke
    Utils.withdraw(
      _treasurySpoke(),
      daiAssetId,
      TREASURY_ADMIN,
      hub.convertToSuppliedAssets(daiAssetId, feeShares / 2),
      address(treasurySpoke)
    );

    // Get the remaining fee shares
    feeShares = treasurySpoke.getSuppliedShares(daiAssetId);

    // Accrue more fees, this time to new fee receiver
    skip(365 days);

    // Check that new fee receiver is getting the fees, and not old treasury spoke
    assertGt(
      newTreasurySpoke.getSuppliedAmount(daiAssetId),
      0,
      'new fee receiver should have accrued fees'
    );
    assertEq(
      treasurySpoke.getSuppliedShares(daiAssetId),
      feeShares,
      'old fee receiver should still have same share amount'
    );

    // Now withdraw remaining fee shares from old treasury spoke
    Utils.withdraw(
      _treasurySpoke(),
      daiAssetId,
      TREASURY_ADMIN,
      UINT256_MAX,
      address(treasurySpoke)
    );
    assertEq(treasurySpoke.getSuppliedShares(daiAssetId), 0, 'old fee receiver should be empty');
  }

  function test_updateFeeReceiver_Scenario() public {
    // set same fee receiver
    test_updateFeeReceiver_fuzz(address(treasurySpoke));
    // set new fee receiver
    test_updateFeeReceiver_fuzz(makeAddr('newFeeReceiver'));
    // set initial fee receiver
    test_updateFeeReceiver_fuzz(address(treasurySpoke));
  }

  function test_updateFeeConfig_revertsWith_OwnableUnauthorizedAccount(address caller) public {
    vm.assume(caller != HUB_CONFIGURATOR_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    hubConfigurator.updateFeeConfig({
      hub: address(hub),
      assetId: vm.randomUint(),
      liquidityFee: vm.randomUint(),
      feeReceiver: vm.randomAddress()
    });
  }

  function test_updateFeeConfig_revertsWith_InvalidSpoke() public {
    uint256 assetId = vm.randomUint(0, hub.getAssetCount() - 1);
    uint256 liquidityFee = vm.randomUint(1, PercentageMathExtended.PERCENTAGE_FACTOR);

    vm.expectRevert(ILiquidityHub.InvalidSpoke.selector);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeConfig(address(hub), assetId, liquidityFee, address(0));
  }

  function test_updateFeeConfig_revertsWith_InvalidLiquidityFee() public {
    uint256 assetId = vm.randomUint(0, hub.getAssetCount() - 1);
    uint256 liquidityFee = vm.randomUint(
      PercentageMathExtended.PERCENTAGE_FACTOR + 1,
      type(uint256).max
    );
    address feeReceiver = hub.getAssetConfig(assetId).feeReceiver;

    vm.expectRevert(ILiquidityHub.InvalidLiquidityFee.selector);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeConfig(address(hub), assetId, liquidityFee, feeReceiver);
  }

  function test_updateFeeConfig_fuzz(
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    liquidityFee = bound(liquidityFee, 0, PercentageMathExtended.PERCENTAGE_FACTOR);
    assumeNotZeroAddress(feeReceiver);

    DataTypes.AssetConfig memory oldConfig = hub.getAssetConfig(assetId);

    if (oldConfig.feeReceiver != feeReceiver) {
      vm.expectCall(
        address(hub),
        abi.encodeCall(
          ILiquidityHub.updateSpokeConfig,
          (
            assetId,
            oldConfig.feeReceiver,
            DataTypes.SpokeConfig({
              supplyCap: 0,
              drawCap: 0,
              active: hub.getSpokeConfig(assetId, oldConfig.feeReceiver).active
            })
          )
        )
      );

      if (!hub.isSpokeListed(assetId, feeReceiver)) {
        vm.expectCall(
          address(hub),
          abi.encodeCall(
            ILiquidityHub.addSpoke,
            (
              assetId,
              feeReceiver,
              DataTypes.SpokeConfig({
                supplyCap: type(uint256).max,
                drawCap: type(uint256).max,
                active: true
              })
            )
          )
        );
      } else {
        vm.expectCall(
          address(hub),
          abi.encodeCall(
            ILiquidityHub.updateSpokeConfig,
            (
              assetId,
              feeReceiver,
              DataTypes.SpokeConfig({
                supplyCap: type(uint256).max,
                drawCap: type(uint256).max,
                active: hub.getSpokeConfig(assetId, feeReceiver).active
              })
            )
          )
        );
      }
    }

    // same struct, renaming to expectedConfig
    DataTypes.AssetConfig memory expectedConfig = oldConfig;
    expectedConfig.feeReceiver = feeReceiver;
    expectedConfig.liquidityFee = liquidityFee;

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeConfig(address(hub), assetId, liquidityFee, feeReceiver);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateFeeConfig_Scenario() public {
    // set same fee receiver and change liquidity fee
    test_updateFeeConfig_fuzz(0, 18_00, address(treasurySpoke));
    // set new fee receiver and liquidity fee
    test_updateFeeConfig_fuzz(0, 4_00, makeAddr('newFeeReceiver'));
    // set non-zero fee receiver
    test_updateFeeConfig_fuzz(0, 0, makeAddr('newFeeReceiver2'));
    // set initial fee receiver and zero fee
    test_updateFeeConfig_fuzz(0, 0, address(treasurySpoke));
  }

  function test_updateInterestRateStrategy_revertsWith_OwnableUnauthorizedAccount(
    address caller
  ) public {
    vm.assume(caller != HUB_CONFIGURATOR_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    hubConfigurator.updateInterestRateStrategy(address(hub), vm.randomUint(), vm.randomAddress());
  }

  function test_updateInterestRateStrategy() public {
    address interestRateStrategy = makeAddr('newInterestRateStrategy');

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.irStrategy = interestRateStrategy;
    _mockInterestRateBps(interestRateStrategy, 5_00);

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateInterestRateStrategy(address(hub), assetId, interestRateStrategy);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateInterestRateStrategy_revertsWith_InvalidIrStrategy() public {
    assetId = vm.randomUint(0, hub.getAssetCount() - 1);

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateInterestRateStrategy(address(hub), assetId, address(0));
  }

  function test_updateInterestRateStrategy_fuzz_revertsWith_InterestRateStrategyReverts(
    address interestRateStrategy
  ) public {
    assetId = vm.randomUint(0, hub.getAssetCount() - 1);
    assumeUnusedAddress(interestRateStrategy);

    vm.expectRevert();
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateInterestRateStrategy(address(hub), assetId, interestRateStrategy);
  }

  function test_updateAssetConfig_revertsWith_OwnableUnauthorizedAccount(address caller) public {
    vm.assume(caller != HUB_CONFIGURATOR_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    hubConfigurator.updateAssetConfig(
      address(hub),
      vm.randomUint(),
      DataTypes.AssetConfig({
        liquidityFee: 0,
        feeReceiver: vm.randomAddress(),
        irStrategy: vm.randomAddress()
      })
    );
  }

  function test_updateAssetConfig() public {
    DataTypes.AssetConfig memory newAssetConfig = DataTypes.AssetConfig({
      liquidityFee: 0,
      feeReceiver: makeAddr('newFeeReceiver'),
      irStrategy: makeAddr('newInterestRateStrategy')
    });
    _mockInterestRateBps(newAssetConfig.irStrategy, 5_00);

    DataTypes.AssetConfig memory oldConfig = hub.getAssetConfig(assetId);

    vm.expectCall(
      address(hub),
      abi.encodeCall(
        ILiquidityHub.updateSpokeConfig,
        (
          assetId,
          oldConfig.feeReceiver,
          DataTypes.SpokeConfig({supplyCap: 0, drawCap: 0, active: true})
        )
      )
    );
    vm.expectCall(
      address(hub),
      abi.encodeCall(
        ILiquidityHub.addSpoke,
        (
          assetId,
          newAssetConfig.feeReceiver,
          DataTypes.SpokeConfig({
            supplyCap: type(uint256).max,
            drawCap: type(uint256).max,
            active: true
          })
        )
      )
    );
    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, newAssetConfig))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateAssetConfig(address(hub), assetId, newAssetConfig);

    assertEq(hub.getAssetConfig(assetId), newAssetConfig);
  }

  function test_freezeAsset_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.freezeAsset(address(hub), assetId);
  }

  function test_freezeAsset() public {
    for (uint256 i; i < spokeAddresses.length; i++) {
      DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spokeAddresses[i]);
      spokeConfig.supplyCap = 0;
      spokeConfig.drawCap = 0;
      vm.expectCall(
        address(hub),
        abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spokeAddresses[i], spokeConfig))
      );
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.freezeAsset(address(hub), assetId);

    for (uint256 i; i < spokeAddresses.length; i++) {
      DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spokeAddresses[i]);
      assertEq(spokeConfig.supplyCap, 0);
      assertEq(spokeConfig.drawCap, 0);
    }
  }

  function test_pauseAsset_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.pauseAsset(address(hub), assetId);
  }

  function test_pauseAsset() public {
    for (uint256 i; i < spokeAddresses.length; i++) {
      DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spokeAddresses[i]);
      spokeConfig.active = false;
      vm.expectCall(
        address(hub),
        abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spokeAddresses[i], spokeConfig))
      );
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.pauseAsset(address(hub), assetId);

    for (uint256 i; i < spokeAddresses.length; i++) {
      DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spokeAddresses[i]);
      assertEq(spokeConfig.active, false);
    }
  }

  function test_addSpoke_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    DataTypes.SpokeConfig memory spokeConfig;
    hubConfigurator.addSpoke(address(hub), vm.randomAddress(), 0, spokeConfig);
  }

  function test_addSpoke() public {
    address newSpoke = makeAddr('newSpoke');

    DataTypes.SpokeConfig memory daiSpokeConfig = DataTypes.SpokeConfig({
      supplyCap: 1,
      drawCap: 2,
      active: true
    });

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(daiAssetId, newSpoke);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.addSpoke(address(hub), newSpoke, daiAssetId, daiSpokeConfig);

    assertEq(hub.getSpokeConfig(daiAssetId, newSpoke), daiSpokeConfig);
  }

  function test_addSpokeToAssets_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.addSpokeToAssets(
      address(hub),
      vm.randomAddress(),
      new uint256[](0),
      new DataTypes.SpokeConfig[](0)
    );
  }

  function test_addSpokeToAssets_revertsWith_MismatchedConfigs() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](3);
    spokeConfigs[0] = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2, active: true});
    spokeConfigs[1] = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4, active: true});
    spokeConfigs[2] = DataTypes.SpokeConfig({supplyCap: 5, drawCap: 6, active: true});

    vm.expectRevert(IHubConfigurator.MismatchedConfigs.selector);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.addSpokeToAssets(address(hub), spoke, assetIds, spokeConfigs);
  }

  function test_addSpokeToAssets() public {
    address newSpoke = makeAddr('newSpoke');

    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig memory daiSpokeConfig = DataTypes.SpokeConfig({
      supplyCap: 1,
      drawCap: 2,
      active: true
    });
    DataTypes.SpokeConfig memory wethSpokeConfig = DataTypes.SpokeConfig({
      supplyCap: 3,
      drawCap: 4,
      active: true
    });

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = daiSpokeConfig;
    spokeConfigs[1] = wethSpokeConfig;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(daiAssetId, newSpoke);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(wethAssetId, newSpoke);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.addSpokeToAssets(address(hub), newSpoke, assetIds, spokeConfigs);

    DataTypes.SpokeConfig memory daiSpokeData = hub.getSpokeConfig(daiAssetId, newSpoke);
    DataTypes.SpokeConfig memory wethSpokeData = hub.getSpokeConfig(wethAssetId, newSpoke);

    assertEq(daiSpokeData, daiSpokeConfig);
    assertEq(wethSpokeData, wethSpokeConfig);
  }

  function test_updateSpokeActive_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateSpokeActive(address(hub), assetId, spokeAddresses[0], true);
  }

  function test_updateSpokeActive() public {
    DataTypes.SpokeConfig memory expectedSpokeConfig = hub.getSpokeConfig(assetId, spoke);
    for (uint256 i = 0; i < 2; ++i) {
      bool active = (i == 0) ? false : true;
      expectedSpokeConfig.active = active;
      vm.expectCall(
        address(hub),
        abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spoke, expectedSpokeConfig))
      );
      vm.prank(HUB_CONFIGURATOR_ADMIN);
      hubConfigurator.updateSpokeActive(address(hub), assetId, spoke, active);
      assertEq(hub.getSpokeConfig(assetId, spoke), expectedSpokeConfig);
    }
  }

  function test_updateSpokeSupplyCap_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateSpokeSupplyCap(address(hub), assetId, spokeAddresses[0], 100);
  }

  function test_updateSpokeSupplyCap() public {
    uint256 newSupplyCap = 100;
    DataTypes.SpokeConfig memory expectedSpokeConfig = hub.getSpokeConfig(assetId, spoke);
    expectedSpokeConfig.supplyCap = newSupplyCap;
    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spoke, expectedSpokeConfig))
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeSupplyCap(address(hub), assetId, spoke, newSupplyCap);
    assertEq(hub.getSpokeConfig(assetId, spoke), expectedSpokeConfig);
  }

  function test_updateSpokeDrawCap_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateSpokeDrawCap(address(hub), assetId, spokeAddresses[0], 100);
  }

  function test_updateSpokeDrawCap() public {
    uint256 newDrawCap = 100;
    DataTypes.SpokeConfig memory expectedSpokeConfig = hub.getSpokeConfig(assetId, spoke);
    expectedSpokeConfig.drawCap = newDrawCap;
    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spoke, expectedSpokeConfig))
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeDrawCap(address(hub), assetId, spoke, newDrawCap);
    assertEq(hub.getSpokeConfig(assetId, spoke), expectedSpokeConfig);
  }

  function test_updateSpokeCaps_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateSpokeCaps(address(hub), assetId, spokeAddresses[0], 100, 100);
  }

  function test_updateSpokeCaps() public {
    uint256 newSupplyCap = 100;
    uint256 newDrawCap = 200;
    DataTypes.SpokeConfig memory expectedSpokeConfig = hub.getSpokeConfig(assetId, spoke);
    expectedSpokeConfig.supplyCap = newSupplyCap;
    expectedSpokeConfig.drawCap = newDrawCap;
    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spoke, expectedSpokeConfig))
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeCaps(address(hub), assetId, spoke, newSupplyCap, newDrawCap);
    assertEq(hub.getSpokeConfig(assetId, spoke), expectedSpokeConfig);
  }

  function test_updateSpokeConfig_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateSpokeConfig(
      address(hub),
      assetId,
      spokeAddresses[0],
      DataTypes.SpokeConfig({supplyCap: 100, drawCap: 100, active: true})
    );
  }

  function test_updateSpokeConfig() public {
    DataTypes.SpokeConfig memory newSpokeConfig = DataTypes.SpokeConfig({
      supplyCap: 100,
      drawCap: 200,
      active: false
    });
    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spoke, newSpokeConfig))
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeConfig(address(hub), assetId, spoke, newSpokeConfig);
    assertEq(hub.getSpokeConfig(assetId, spoke), newSpokeConfig);
  }

  function _addAsset(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy,
    bytes memory encodedIrData
  ) internal returns (uint256) {
    if (fetchErc20Decimals) {
      _mockDecimals(underlying, decimals);
      return
        hubConfigurator.addAsset(
          address(hub),
          underlying,
          feeReceiver,
          interestRateStrategy,
          encodedIrData
        );
    } else {
      return
        hubConfigurator.addAsset(
          address(hub),
          underlying,
          decimals,
          feeReceiver,
          interestRateStrategy,
          encodedIrData
        );
    }
  }
}
