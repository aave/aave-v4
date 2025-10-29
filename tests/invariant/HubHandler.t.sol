// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';
import {Hub} from 'src/hub/Hub.sol';
import {AssetInterestRateStrategy, IAssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {Spoke} from 'src/spoke/Spoke.sol';
import {TreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';
import {MockPriceFeed} from '../mocks/MockPriceFeed.sol';
import '../mocks/MockERC20.sol';
import '../Utils.sol';

contract HubHandler is Test {
  IERC20 public usdc;
  IERC20 public dai;
  IERC20 public usdt;

  IPriceOracle public oracle;
  Hub public hub1;
  Spoke public spoke1;
  TreasurySpoke public treasurySpoke;
  AccessManager public accessManager;
  AssetInterestRateStrategy irStrategy;

  address internal hubAdmin = makeAddr('HUB_ADMIN');

  struct State {
    mapping(address => uint256) reserveSupplied; // asset => supply
    mapping(address => mapping(address => uint256)) userSupplied; // asset => user => supply
    mapping(address => uint256) assetDonated; // underlying => donation
    mapping(address => uint256) lastExchangeRate; // asset => supplyIndex
  }

  State internal s;

  function setUp() public {
    vm.startPrank(hubAdmin);
    accessManager = new AccessManager(hubAdmin);
    hub1 = new Hub(address(accessManager));
    irStrategy = new AssetInterestRateStrategy(address(hub1));
    address predictedSpoke = vm.computeCreateAddress(hubAdmin, vm.getNonce(hubAdmin) + 3);
    oracle = new AaveOracle(predictedSpoke, 8, 'Spoke 1 (USD)');
    address spokeImpl = address(new SpokeInstance(address(oracle)));
    spoke1 = Spoke(
      address(
        new TransparentUpgradeableProxy(
          spokeImpl,
          hubAdmin,
          abi.encodeCall(Spoke.initialize, (address(accessManager)))
        )
      )
    );
    assertEq(address(spoke1), predictedSpoke, 'predictedSpoke');
    treasurySpoke = new TreasurySpoke(hubAdmin);
    usdc = new MockERC20();
    dai = new MockERC20();
    usdt = new MockERC20();
    vm.stopPrank();

    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );

    vm.startPrank(hubAdmin);
    // Add dai
    hub1.addAsset(address(dai), 18, address(treasurySpoke), address(irStrategy), encodedIrData);
    hub1.updateAssetConfig(
      address(dai),
      IHub.AssetConfig({
        feeReceiver: address(treasurySpoke),
        liquidityFee: 0,
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      }),
      new bytes(0)
    );
    spoke1.addReserve(
      address(hub1),
      address(dai),
      _deployMockPriceFeed(spoke1, 1e8),
      ISpoke.ReserveConfig({frozen: false, paused: false, collateralRisk: 0, borrowable: false}),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 0,
        maxLiquidationBonus: 100_00,
        liquidationFee: 0
      })
    );
    vm.stopPrank();
  }

  function getReserveSupplied(address asset) public view returns (uint256) {
    return s.reserveSupplied[asset];
  }

  function getUserSupplied(address asset, address user) public view returns (uint256) {
    return s.userSupplied[asset][user];
  }

  function getAssetDonated(address underlying) public view returns (uint256) {
    return s.assetDonated[underlying];
  }

  function getLastExchangeRate(address asset) public view returns (uint256) {
    return s.lastExchangeRate[asset];
  }

  function supply(uint256 assetIdx, address user, uint256 amount, address onBehalfOf) public {
    vm.assume(user != address(hub1) && user != address(0) && onBehalfOf != address(0));
    assetIdx = bound(assetIdx, 0, hub1.getAssetCount() - 1);
    amount = bound(amount, 1, type(uint120).max);
    address asset = hub1.getUnderlyingAddress(assetIdx);

    deal(asset, user, amount);
    Utils.add({hub: hub1, asset: asset, caller: address(spoke1), amount: amount, user: user});

    _updateState(asset);
    s.reserveSupplied[asset] += amount;
    s.userSupplied[asset][onBehalfOf] += amount;
  }

  function withdraw(uint256 assetIdx, address user, uint256 amount, address to) public {
    assetIdx = bound(assetIdx, 0, hub1.getAssetCount() - 1);
    // TODO: bound by spoke1 user balance
    amount = bound(amount, 1, 2);
    address asset = hub1.getUnderlyingAddress(assetIdx);

    Utils.remove({hub: hub1, asset: asset, caller: address(spoke1), amount: amount, to: to});

    _updateState(asset);
    s.reserveSupplied[asset] -= amount;
    s.userSupplied[asset][user] -= amount;
  }

  function donate(uint256 assetIdx, address user, uint256 amount) public {
    vm.assume(user != address(hub1) && user != address(0));
    assetIdx = bound(assetIdx, 0, hub1.getAssetCount() - 1);
    amount = bound(amount, 1, type(uint120).max);
    address asset = hub1.getUnderlyingAddress(assetIdx);

    deal(asset, user, amount);
    vm.prank(user);
    IERC20(asset).transfer(address(hub1), amount);

    s.assetDonated[asset] += amount;
  }

  function _updateState(address asset) internal {
    revert('implement me');

    // IHub.Asset memory reserveData = hub1.getAsset(asset);
    // // todo: remove last exchange rate, bad idea to store like this, looses precision
    // s.lastExchangeRate[asset] = reserveData.suppliedShares == 0
    //   ? 0
    //   : hub1.getTotalAssets(asset) / reserveData.suppliedShares;
  }

  function _deployMockPriceFeed(Spoke spoke, uint256 price) internal returns (address) {
    AaveOracle oracle = AaveOracle(spoke.ORACLE());
    return address(new MockPriceFeed(oracle.DECIMALS(), oracle.DESCRIPTION(), price));
  }
}
