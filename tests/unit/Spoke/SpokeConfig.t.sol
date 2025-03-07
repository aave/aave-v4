// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeConfigTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function test_updateReserveConfig() public {
    uint256 daiReserveId = daiReserveId(spoke1);
    DataTypes.Reserve memory reserveData = spoke1.getReserve(daiReserveId);

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: reserveData.config.decimals + 1,
      active: !reserveData.config.active,
      frozen: !reserveData.config.frozen,
      paused: !reserveData.config.paused,
      liquidationThreshold: reserveData.config.liquidationThreshold + 1,
      liquidationBonus: reserveData.config.liquidationBonus + 1,
      liquidityPremium: 0,
      borrowable: !reserveData.config.borrowable,
      collateral: !reserveData.config.collateral
    });
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(
      daiReserveId,
      newReserveConfig.decimals,
      newReserveConfig.active,
      newReserveConfig.frozen,
      newReserveConfig.paused,
      newReserveConfig.liquidationThreshold,
      newReserveConfig.liquidationBonus,
      newReserveConfig.liquidityPremium,
      newReserveConfig.borrowable,
      newReserveConfig.collateral
    );
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    reserveData = spoke1.getReserve(daiReserveId);

    assertEq(
      reserveData.config.liquidationThreshold,
      newReserveConfig.liquidationThreshold,
      'wrong lt'
    );
    assertEq(reserveData.config.liquidationBonus, newReserveConfig.liquidationBonus, 'wrong lb');
    assertEq(
      reserveData.config.liquidityPremium,
      newReserveConfig.liquidityPremium,
      'wrong liquidityPremium'
    );
    assertEq(reserveData.config.borrowable, newReserveConfig.borrowable, 'wrong borrowable');
    assertEq(reserveData.config.collateral, newReserveConfig.collateral, 'wrong collateral');
  }

  function test_setUsingAsCollateral_revertsWith_ReserveNotCollateral() public {
    bool newCollateralFlag = false;
    bool usingAsCollateral = true;
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    updateCollateralFlag(spoke1, daiReserveId, newCollateralFlag);

    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotCollateral.selector, daiReserveId));
    ISpoke(spoke1).setUsingAsCollateral(daiReserveId, usingAsCollateral);
  }

  function test_setUsingAsCollateral() public {
    bool newCollateralFlag = true;
    bool usingAsCollateral = true;
    uint256 daiAmount = 100e18;

    // ensure DAI is allowed as collateral
    updateCollateralFlag(spoke1, spokeInfo[spoke1].dai.reserveId, newCollateralFlag);

    // Bob supply dai into spoke1
    deal(address(tokenList.dai), bob, daiAmount);
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, bob, daiAmount, bob);

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.UsingAsCollateral(spokeInfo[spoke1].dai.reserveId, bob, usingAsCollateral);
    ISpoke(spoke1).setUsingAsCollateral(spokeInfo[spoke1].dai.reserveId, usingAsCollateral);

    DataTypes.UserPosition memory userData = spoke1.getUserPosition(
      spokeInfo[spoke1].dai.reserveId,
      bob
    );
    assertEq(userData.usingAsCollateral, usingAsCollateral, 'wrong usingAsCollateral');
  }

  function test_updateReserveConfig_revertsWith_InvalidLiquidityPremium() public {
    uint256 daiReserveId = daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;

    config.liquidityPremium = PercentageMath.PERCENTAGE_FACTOR * 10 + 1;

    vm.prank(SPOKE_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InvalidLiquidityPremium.selector));
    spoke1.updateReserveConfig(daiReserveId, config);
  }

  function test_updateReserveConfig_revertsWith_InvalidReserve() public {
    uint256 invalidReserveId = spoke1.reserveCount();
    DataTypes.ReserveConfig memory config;

    vm.prank(SPOKE_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InvalidReserve.selector));
    spoke1.updateReserveConfig(invalidReserveId, config);
  }

  function test_updateReserveConfig_revertsWith_ReserveCannotBePaused() public {
    uint256 daiReserveId = daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;
    config.active = false;

    // supply some DAI to the reserve to prevent pausing
    Utils.spokeSupply({
      spoke: spoke1,
      reserveId: daiReserveId,
      user: bob,
      amount: 100e18,
      onBehalfOf: bob
    });

    vm.prank(SPOKE_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveCannotBeInactive.selector));
    spoke1.updateReserveConfig(daiReserveId, config);
  }
}
