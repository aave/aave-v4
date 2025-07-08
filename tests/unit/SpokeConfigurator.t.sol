// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'tests/Base.t.sol';

contract SpokeConfiguratorTest is Base {
  SpokeConfigurator internal spokeConfigurator;
  address internal SPOKE_CONFIGURATOR_ADMIN = makeAddr('SPOKE_CONFIGURATOR_ADMIN');

  address internal spokeAddr;
  ISpoke internal spoke;
  uint256 internal reserveId;
  uint256 internal invalidReserveId;

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();

    spokeConfigurator = new SpokeConfigurator(SPOKE_CONFIGURATOR_ADMIN);
    spokeAddr = address(spoke1);
    spoke = ISpoke(spokeAddr);
    reserveId = 0;
    invalidReserveId = spoke.reserveCount();

    // Grant spokeConfigurator spoke admin role with 0 delay
    IAccessManager accessManager = IAccessManager(spoke1.authority());
    vm.prank(ADMIN);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, address(spokeConfigurator), 0);
  }

  function test_updateLiquidationCloseFactor_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateLiquidationCloseFactor(spokeAddr, 0);
  }

  function test_updateLiquidationCloseFactor_revertsWith_InvalidCloseFactor() public {
    uint256 invalidCloseFactor = spoke.HEALTH_FACTOR_LIQUIDATION_THRESHOLD() - 1;
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InvalidCloseFactor.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationCloseFactor(spokeAddr, invalidCloseFactor);
  }

  function test_updateLiquidationCloseFactor() public {
    uint256 newCloseFactor = ISpoke(spoke).HEALTH_FACTOR_LIQUIDATION_THRESHOLD() * 2;

    DataTypes.LiquidationConfig memory expectedLiquidationConfig = spoke.getLiquidationConfig();
    expectedLiquidationConfig.closeFactor = newCloseFactor;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (expectedLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.LiquidationConfigUpdated(expectedLiquidationConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationCloseFactor(spokeAddr, newCloseFactor);

    assertEq(spoke.getLiquidationConfig(), expectedLiquidationConfig);
  }

  function test_updateLiquidationHealthFactorForMaxBonus_revertsWith_OwnableUnauthorizedAccount()
    public
  {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateLiquidationHealthFactorForMaxBonus(spokeAddr, 0);
  }

  function test_updateLiquidationHealthFactorForMaxBonus_revertsWith_InvalidHealthFactorForMaxBonus()
    public
  {
    uint256 invalidHealthFactorForMaxBonus = spoke.HEALTH_FACTOR_LIQUIDATION_THRESHOLD() + 1;
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InvalidHealthFactorForMaxBonus.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationHealthFactorForMaxBonus(
      spokeAddr,
      invalidHealthFactorForMaxBonus
    );
  }

  function test_updateLiquidationHealthFactorForMaxBonus() public {
    uint256 newHealthFactorForMaxBonus = spoke.HEALTH_FACTOR_LIQUIDATION_THRESHOLD() / 2;

    DataTypes.LiquidationConfig memory expectedLiquidationConfig = spoke.getLiquidationConfig();
    expectedLiquidationConfig.healthFactorForMaxBonus = newHealthFactorForMaxBonus;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (expectedLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.LiquidationConfigUpdated(expectedLiquidationConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationHealthFactorForMaxBonus(
      spokeAddr,
      newHealthFactorForMaxBonus
    );

    assertEq(spoke.getLiquidationConfig().healthFactorForMaxBonus, newHealthFactorForMaxBonus);
  }

  function test_updateLiquidationBonusFactor_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateLiquidationBonusFactor(spokeAddr, 0);
  }

  function test_updateLiquidationBonusFactor_revertsWith_InvalidLiquidationBonusFactor() public {
    uint256 invalidLiquidationBonusFactor = PercentageMathExtended.PERCENTAGE_FACTOR + 1;
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InvalidLiquidationBonusFactor.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationBonusFactor(spokeAddr, invalidLiquidationBonusFactor);
  }

  function test_updateLiquidationBonusFactor() public {
    uint256 newLiquidationBonusFactor = PercentageMathExtended.PERCENTAGE_FACTOR / 2;

    DataTypes.LiquidationConfig memory expectedLiquidationConfig = spoke.getLiquidationConfig();
    expectedLiquidationConfig.liquidationBonusFactor = newLiquidationBonusFactor;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (expectedLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.LiquidationConfigUpdated(expectedLiquidationConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationBonusFactor(spokeAddr, newLiquidationBonusFactor);

    assertEq(spoke.getLiquidationConfig(), expectedLiquidationConfig);
  }

  function test_updateActive_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateActive(spokeAddr, reserveId, true);
  }

  function test_updateActive_revertsWith_ReserveNotListed() public {
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateActive(spokeAddr, invalidReserveId, true);
  }

  function test_updateActive() public {
    DataTypes.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);
    expectedReserveConfig.active = !expectedReserveConfig.active;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.ReserveConfigUpdated(reserveId, expectedReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateActive(spokeAddr, reserveId, expectedReserveConfig.active);

    assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
  }

  function test_updatePaused_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updatePaused(spokeAddr, reserveId, true);
  }

  function test_updatePaused_revertsWith_ReserveNotListed() public {
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updatePaused(spokeAddr, invalidReserveId, true);
  }

  function test_updatePaused() public {
    DataTypes.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);
    expectedReserveConfig.paused = !expectedReserveConfig.paused;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.ReserveConfigUpdated(reserveId, expectedReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updatePaused(spokeAddr, reserveId, expectedReserveConfig.paused);

    assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
  }

  function test_updateFrozen_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateFrozen(spokeAddr, reserveId, true);
  }

  function test_updateFrozen_revertsWith_ReserveNotListed() public {
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateFrozen(spokeAddr, invalidReserveId, true);
  }

  function test_updateFrozen() public {
    DataTypes.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);
    expectedReserveConfig.frozen = !expectedReserveConfig.frozen;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.ReserveConfigUpdated(reserveId, expectedReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateFrozen(spokeAddr, reserveId, expectedReserveConfig.frozen);

    assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
  }

  function test_updateBorrowable_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateBorrowable(spokeAddr, reserveId, true);
  }

  function test_updateBorrowable_revertsWith_ReserveNotListed() public {
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateBorrowable(spokeAddr, invalidReserveId, true);
  }

  function test_updateBorrowable() public {
    DataTypes.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);
    expectedReserveConfig.borrowable = !expectedReserveConfig.borrowable;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.ReserveConfigUpdated(reserveId, expectedReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateBorrowable(spokeAddr, reserveId, expectedReserveConfig.borrowable);

    assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
  }

  function test_updateCollateral_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateCollateral(spokeAddr, reserveId, true);
  }

  function test_updateCollateral_revertsWith_ReserveNotListed() public {
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateCollateral(spokeAddr, invalidReserveId, true);
  }

  function test_updateCollateral() public {
    DataTypes.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);
    expectedReserveConfig.collateral = !expectedReserveConfig.collateral;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.ReserveConfigUpdated(reserveId, expectedReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateCollateral(spokeAddr, reserveId, expectedReserveConfig.collateral);

    assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
  }

  function test_updateLiquidationBonus_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateLiquidationBonus(spokeAddr, reserveId, 0);
  }

  function test_updateLiquidationBonus_revertsWith_ReserveNotListed() public {
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationBonus(spokeAddr, invalidReserveId, 0);
  }

  function test_updateLiquidationBonus_revertsWith_InvalidLiquidationBonus() public {
    uint256 invalidLiquidationBonus = PercentageMathExtended.PERCENTAGE_FACTOR - 1;
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InvalidLiquidationBonus.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationBonus(spokeAddr, reserveId, invalidLiquidationBonus);
  }

  function test_updateLiquidationBonus() public {
    uint256 newLiquidationBonus = PercentageMathExtended.PERCENTAGE_FACTOR * 2;

    DataTypes.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);
    expectedReserveConfig.liquidationBonus = newLiquidationBonus;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.ReserveConfigUpdated(reserveId, expectedReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationBonus(spokeAddr, reserveId, newLiquidationBonus);

    assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
  }

  function test_updateLiquidityPremium_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateLiquidityPremium(spokeAddr, reserveId, 0);
  }

  function test_updateLiquidityPremium_revertsWith_ReserveNotListed() public {
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidityPremium(spokeAddr, invalidReserveId, 0);
  }

  function test_updateLiquidityPremium_revertsWith_InvalidLiquidityPremium() public {
    uint256 invalidLiquidityPremium = spoke.MAX_LIQUIDITY_PREMIUM() + 1;
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InvalidLiquidityPremium.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidityPremium(spokeAddr, reserveId, invalidLiquidityPremium);
  }

  function test_updateLiquidityPremium() public {
    uint256 newLiquidityPremium = spoke.MAX_LIQUIDITY_PREMIUM() / 2;

    DataTypes.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);
    expectedReserveConfig.liquidityPremium = newLiquidityPremium;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.ReserveConfigUpdated(reserveId, expectedReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidityPremium(spokeAddr, reserveId, newLiquidityPremium);

    assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
  }

  function test_updateLiquidationFee_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateLiquidationFee(spokeAddr, reserveId, 0);
  }

  function test_updateLiquidationFee_revertsWith_ReserveNotListed() public {
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationFee(spokeAddr, invalidReserveId, 0);
  }

  function test_updateLiquidationFee_revertsWith_InvalidLiquidationFee() public {
    uint256 invalidLiquidationFee = PercentageMathExtended.PERCENTAGE_FACTOR + 1;
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InvalidLiquidationFee.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationFee(spokeAddr, reserveId, invalidLiquidationFee);
  }

  function test_updateLiquidationFee() public {
    uint256 newLiquidationFee = PercentageMathExtended.PERCENTAGE_FACTOR / 2;

    DataTypes.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);
    expectedReserveConfig.liquidationFee = newLiquidationFee;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.ReserveConfigUpdated(reserveId, expectedReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationFee(spokeAddr, reserveId, newLiquidationFee);

    assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
  }

  function test_updateCollateralFactor_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateCollateralFactor(spokeAddr, reserveId, 0);
  }

  function test_updateCollateralFactor_revertsWith_ReserveNotListed() public {
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateCollateralFactor(spokeAddr, invalidReserveId, 0);
  }

  function test_updateCollateralFactor_revertsWith_InvalidCollateralFactor() public {
    uint16 invalidCollateralFactor = uint16(PercentageMathExtended.PERCENTAGE_FACTOR + 1);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InvalidCollateralFactor.selector));
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateCollateralFactor(spokeAddr, reserveId, invalidCollateralFactor);
  }

  function test_updateCollateralFactor() public {
    uint16 newCollateralFactor = uint16(PercentageMathExtended.PERCENTAGE_FACTOR / 2);

    DataTypes.DynamicReserveConfig memory expectedDynamicReserveConfig = spoke
      .getDynamicReserveConfig(reserveId);
    expectedDynamicReserveConfig.collateralFactor = newCollateralFactor;

    uint16 expectedConfigKey = spoke.getReserve(reserveId).dynamicConfigKey + 1;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateDynamicReserveConfig, (reserveId, expectedDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.DynamicReserveConfigUpdated(
      reserveId,
      expectedConfigKey,
      expectedDynamicReserveConfig
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateCollateralFactor(spokeAddr, reserveId, newCollateralFactor);

    assertEq(spoke.getDynamicReserveConfig(reserveId), expectedDynamicReserveConfig);
    assertEq(spoke.getReserve(reserveId).dynamicConfigKey, expectedConfigKey);
  }
}
