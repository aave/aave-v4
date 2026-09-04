// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

// Minimal accounting backend for testing reserve enumeration independently of Hub setup.
contract ReserveUniverseHub {
  address public immutable underlying;

  constructor(address token) {
    underlying = token;
  }

  function getAssetUnderlyingAndDecimals(uint256) external view returns (address, uint8) {
    return (underlying, 18);
  }

  function add(uint256, uint256 amount) external pure returns (uint256) {
    return amount;
  }

  function previewRemoveByShares(uint256, uint256 shares) external pure returns (uint256) {
    return shares;
  }
}

contract SpokeReserveUniverseTest is Base {
  function test_compat_reserveUniverseBeyondTwoBitmapBuckets() public {
    ReserveUniverseHub backend = new ReserveUniverseHub(address(tokenList.dai));
    address source = _deployMockPriceFeed(spoke1, 1e8);
    ISpoke.ReserveConfig memory config = _getDefaultReserveConfig(10_00);
    ISpoke.DynamicReserveConfig memory dynamicConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 80_00,
      maxLiquidationBonus: 105_00,
      liquidationFee: 0
    });
    uint256 reserveId;
    vm.startPrank(SPOKE_ADMIN);
    for (uint256 assetId; assetId < 300; ++assetId) {
      reserveId = spoke1.addReserve(address(backend), assetId, source, config, dynamicConfig);
    }
    vm.stopPrank();
    assertGt(reserveId, 256);
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: 1e18,
      onBehalfOf: alice
    });
    ISpoke.UserAccountData memory account = spoke1.getUserAccountData(alice);
    assertEq(account.activeCollateralCount, 1);
    assertEq(account.totalCollateralValue, 1e26);
  }
}
