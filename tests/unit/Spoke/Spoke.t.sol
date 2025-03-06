// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract SpokeTest is Base {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_updateReserveConfig() public {
    uint256 daiId = 0;

    DataTypes.Reserve memory reserveData = spoke1.getReserve(daiId);

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      liquidationThreshold: reserveData.config.liquidationThreshold + 1,
      liquidationBonus: reserveData.config.liquidationBonus + 1,
      liquidityPremium: 0,
      borrowable: !reserveData.config.borrowable,
      collateral: !reserveData.config.collateral
    });
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(
      daiId,
      newReserveConfig.liquidationThreshold,
      newReserveConfig.liquidationBonus,
      newReserveConfig.liquidityPremium,
      newReserveConfig.borrowable,
      newReserveConfig.collateral
    );
    spoke1.updateReserveConfig(daiId, newReserveConfig);

    reserveData = spoke1.getReserve(daiId);

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

  function test_setUsingAsCollateral_revertsWith_reserve_not_collateral() public {
    bool newCollateral = false;
    bool usingAsCollateral = true;
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    updateCollateral(spoke1, daiReserveId, newCollateral);

    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotCollateral.selector, daiReserveId));
    ISpoke(spoke1).setUsingAsCollateral(daiReserveId, usingAsCollateral);
  }

  function test_setUsingAsCollateral() public {
    bool newCollateral = true;
    bool usingAsCollateral = true;
    uint256 daiAmount = 100e18;

    // ensure DAI is allowed as collateral
    updateCollateral(spoke1, spokeInfo[spoke1].dai.reserveId, newCollateral);

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
}
