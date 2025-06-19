// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import 'tests/Base.t.sol';

contract ConfiguratorTest is Base {
  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
    bool fetchErc20Decimals,
    address asset,
    uint8 decimals,
    address interestRateStrategy
  ) public {
    vm.assume(asset != address(0) && interestRateStrategy != address(0));
    decimals = uint8(bound(decimals, hub.MAX_ALLOWED_ASSET_DECIMALS() + 1, type(uint8).max));

    vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector, address(hub));
    _addAsset(fetchErc20Decimals, asset, decimals, interestRateStrategy);
  }

  function test_addAsset_revertsWith_InvalidAssetDecimals() public {
    test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
      false,
      address(tokenList.dai),
      hub.MAX_ALLOWED_ASSET_DECIMALS() + 1,
      address(irStrategy)
    );
    test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
      true,
      address(tokenList.dai),
      hub.MAX_ALLOWED_ASSET_DECIMALS() + 1,
      address(irStrategy)
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetAddress(
    bool fetchErc20Decimals,
    uint8 decimals,
    address interestRateStrategy
  ) public {
    vm.expectRevert(ILiquidityHub.InvalidAssetAddress.selector, address(hub));
    _addAsset(fetchErc20Decimals, address(0), decimals, interestRateStrategy);
  }

  function test_addAsset_revertsWith_InvalidAssetAddress() public {
    test_addAsset_fuzz_revertsWith_InvalidAssetAddress(false, 18, address(irStrategy));
    test_addAsset_fuzz_revertsWith_InvalidAssetAddress(true, 18, address(irStrategy));
  }

  function test_addAsset_fuzz_revertsWith_InvalidIrStrategy(
    bool fetchErc20Decimals,
    address asset,
    uint8 decimals
  ) public {
    vm.assume(asset != address(0));
    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector, address(hub));

    _addAsset(fetchErc20Decimals, asset, decimals, address(0));
  }

  function test_addAsset_revertsWith_InvalidIrStrategy() public {
    test_addAsset_fuzz_revertsWith_InvalidIrStrategy(false, address(tokenList.dai), 18);
    test_addAsset_fuzz_revertsWith_InvalidIrStrategy(true, address(tokenList.dai), 18);
  }

  function test_addAsset_fuzz(
    bool fetchErc20Decimals,
    address asset,
    uint8 decimals,
    address interestRateStrategy
  ) public {
    vm.assume(asset != address(0) && interestRateStrategy != address(0));
    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));
    _checkedAddAsset(fetchErc20Decimals, asset, decimals, interestRateStrategy);
  }

  function test_addAsset() public {
    test_addAsset_fuzz(false, address(tokenList.dai), 18, address(irStrategy));
    test_addAsset_fuzz(true, address(tokenList.dai), 18, address(irStrategy));
  }

  function _checkedAddAsset(
    bool fetchErc20Decimals,
    address asset,
    uint8 decimals,
    address interestRateStrategy
  ) internal {
    uint256 assetId = hub.assetCount();

    DataTypes.AssetConfig memory expectedConfig = DataTypes.AssetConfig({
      active: true,
      frozen: false,
      paused: false,
      feeReceiver: address(0),
      liquidityFee: 0,
      irStrategy: IReserveInterestRateStrategy(interestRateStrategy)
    });

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetAdded(assetId, asset, decimals);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, expectedConfig);

    _addAsset(fetchErc20Decimals, asset, decimals, interestRateStrategy);

    assertEq(hub.assetCount(), assetId + 1, 'asset count');
    assertEq(hub.getAssetDecimals(assetId), decimals, 'asset decimals');
    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function _addAsset(
    bool fetchErc20Decimals,
    address asset,
    uint8 decimals,
    address interestRateStrategy
  ) internal {
    if (fetchErc20Decimals) {
      _mockDecimals(asset, decimals);
      configurator.addAsset(address(hub), asset, interestRateStrategy);
    } else {
      configurator.addAsset(address(hub), asset, decimals, interestRateStrategy);
    }
  }

  function _mockDecimals(address asset, uint8 decimals) internal {
    vm.mockCall(
      asset,
      abi.encodeWithSelector(IERC20Metadata.decimals.selector),
      abi.encode(decimals)
    );
  }
}
