// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';
import {AaveOracle} from 'src/contracts/AaveOracle.sol';
import {LiquidityHub} from 'src/contracts/LiquidityHub.sol';
import {Spoke} from 'src/contracts/Spoke.sol';
import {TreasurySpoke} from 'src/contracts/TreasurySpoke.sol';
import {AssetInterestRateStrategy, IAssetInterestRateStrategy} from 'src/contracts/AssetInterestRateStrategy.sol';
import {MockPriceFeed} from '../mocks/MockPriceFeed.sol';
import '../mocks/MockERC20.sol';
import '../Utils.sol';

contract LiquidityHubHandler is Test {
  IERC20 public usdc;
  IERC20 public dai;
  IERC20 public usdt;

  IPriceOracle public oracle;
  LiquidityHub public hub;
  Spoke public spoke1;
  TreasurySpoke public treasurySpoke;
  AccessManager public accessManager;
  AssetInterestRateStrategy irStrategy;

  address internal hubAdmin = makeAddr('HUB_ADMIN');

  struct State {
    mapping(uint256 => uint256) reserveSupplied; // asset => supply
    mapping(uint256 => mapping(address => uint256)) userSupplied; // asset => user => supply
    mapping(address => uint256) assetDonated; // underlying => donation
    mapping(uint256 => uint256) lastExchangeRate; // asset => supplyIndex
  }

  State internal s;

  constructor() {
    vm.startPrank(hubAdmin);
    accessManager = new AccessManager(hubAdmin);
    hub = new LiquidityHub(address(accessManager));
    irStrategy = new AssetInterestRateStrategy(address(hub));
    spoke1 = new Spoke(address(accessManager));
    oracle = new AaveOracle(address(spoke1), 8, 'Spoke 1 (USD)');
    spoke1.updateOracle(address(oracle));
    treasurySpoke = new TreasurySpoke(hubAdmin, address(hub));
    usdc = new MockERC20();
    dai = new MockERC20();
    usdt = new MockERC20();

    // Add dai
    hub.addAsset(address(dai), 18, address(treasurySpoke), address(irStrategy));
    vm.stopPrank();
    vm.prank(address(hub));
    irStrategy.setInterestRateData(
      0,
      abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00, // 90.00%
          baseVariableBorrowRate: 5_00, // 5.00%
          variableRateSlope1: 5_00, // 5.00%
          variableRateSlope2: 5_00 // 5.00%
        })
      )
    );
    vm.startPrank(hubAdmin);
    hub.updateAssetConfig(
      0,
      DataTypes.AssetConfig({
        feeReceiver: address(treasurySpoke),
        active: true,
        frozen: false,
        paused: false,
        liquidityFee: 0,
        irStrategy: address(irStrategy)
      })
    );
    spoke1.addReserve(
      0,
      address(hub),
      _deployMockPriceFeed(spoke1, 1e8),
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        liquidityPremium: 0,
        borrowable: false,
        collateral: false
      }),
      DataTypes.DynamicReserveConfig({
        collateralFactor: 0,
        liquidationBonus: 100_00,
        liquidationFee: 0
      })
    );
    vm.stopPrank();
  }

  function getReserveSupplied(uint256 assetId) public view returns (uint256) {
    return s.reserveSupplied[assetId];
  }

  function getUserSupplied(uint256 assetId, address user) public view returns (uint256) {
    return s.userSupplied[assetId][user];
  }

  function getAssetDonated(address underlying) public view returns (uint256) {
    return s.assetDonated[underlying];
  }

  function getLastExchangeRate(uint256 assetId) public view returns (uint256) {
    return s.lastExchangeRate[assetId];
  }

  function supply(uint256 assetId, address user, uint256 amount, address onBehalfOf) public {
    vm.assume(user != address(hub) && user != address(0) && onBehalfOf != address(0));
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    deal(hub.getAsset(assetId).underlying, user, amount);
    Utils.add({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      user: user,
      to: onBehalfOf
    });

    _updateState(assetId);
    s.reserveSupplied[assetId] += amount;
    s.userSupplied[assetId][onBehalfOf] += amount;
  }

  function withdraw(uint256 assetId, address user, uint256 amount, address to) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    // TODO: bound by spoke1 user balance
    amount = bound(amount, 1, 2);

    Utils.remove({hub: hub, assetId: assetId, spoke: address(spoke1), amount: amount, to: to});

    _updateState(assetId);
    s.reserveSupplied[assetId] -= amount;
    s.userSupplied[assetId][user] -= amount;
  }

  function donate(uint256 assetId, address user, uint256 amount) public {
    vm.assume(user != address(hub) && user != address(0));
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    address underlying = hub.getAsset(assetId).underlying;

    deal(underlying, user, amount);
    vm.prank(user);
    IERC20(underlying).transfer(address(hub), amount);

    s.assetDonated[underlying] += amount;
  }

  function _updateState(uint256 assetId) internal {
    revert('implement me');

    // DataTypes.Asset memory reserveData = hub.getAsset(assetId);
    // // todo: remove last exchange rate, bad idea to store like this, looses precision
    // s.lastExchangeRate[assetId] = reserveData.suppliedShares == 0
    //   ? 0
    //   : hub.getTotalAssets(assetId) / reserveData.suppliedShares;
  }

  function _deployMockPriceFeed(Spoke spoke, uint256 price) internal returns (address) {
    AaveOracle oracle = AaveOracle(address(spoke.oracle()));
    return address(new MockPriceFeed(oracle.DECIMALS(), oracle.DESCRIPTION(), price));
  }
}
