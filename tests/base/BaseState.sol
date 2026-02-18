// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Vm, VmSafe} from 'forge-std/Vm.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {ITreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {TestTypes} from 'tests/types/TestTypes.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

/// @title BaseState
/// @notice Shared state variables, constants, and low-level helpers for the Aave V4 test suite.
abstract contract BaseState is TestTypes, Test {
  using WadRayMath for *;
  using PercentageMath for uint256;
  using SafeCast for *;

  bytes32 internal constant ERC1967_ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
  bytes32 internal constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  bytes32 internal constant INITIALIZABLE_SLOT =
    0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

  uint256 internal constant MIN_TOKEN_DECIMALS_SUPPORTED = 6;
  uint256 internal constant MAX_TOKEN_DECIMALS_SUPPORTED = 18;
  uint256 internal constant MAX_SUPPLY_ASSET_UNITS = 1e12;
  uint256 internal MAX_SUPPLY_AMOUNT_USDX;
  uint256 internal MAX_SUPPLY_AMOUNT_DAI;
  uint256 internal MAX_SUPPLY_AMOUNT_WBTC;
  uint256 internal MAX_SUPPLY_AMOUNT_WETH;
  uint256 internal MAX_SUPPLY_AMOUNT_USDY;
  uint256 internal MAX_SUPPLY_AMOUNT_USDZ;
  uint256 internal constant MAX_SUPPLY_IN_BASE_CURRENCY = 1e39;
  uint24 internal constant MIN_COLLATERAL_RISK_BPS = 0;
  uint24 internal constant MAX_COLLATERAL_RISK_BPS = 1000_00;
  uint256 internal constant MAX_SUPPLY_PRICE = 100;
  uint256 internal constant MIN_DRAWN_INDEX = WadRayMath.RAY;
  uint256 internal constant MAX_DRAWN_INDEX = 100 * WadRayMath.RAY;
  uint24 internal constant MIN_BORROW_RATE = 0;
  uint256 internal constant MAX_BORROW_RATE = 1000_00;
  uint256 internal constant MIN_OPTIMAL_RATIO = 1_00;
  uint256 internal constant MAX_OPTIMAL_RATIO = 99_00;
  uint256 internal constant MAX_SKIP_TIME = 10_000 days;
  uint32 internal constant MIN_LIQUIDATION_BONUS = uint32(PercentageMath.PERCENTAGE_FACTOR);
  uint32 internal constant MAX_LIQUIDATION_BONUS = 150_00;
  uint16 internal constant MAX_LIQUIDATION_BONUS_FACTOR = uint16(PercentageMath.PERCENTAGE_FACTOR);
  uint16 internal constant MAX_LIQUIDATION_FEE = 100_00;
  uint16 internal constant MIN_LIQUIDATION_FEE = 0;
  uint128 internal constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;
  uint128 internal constant MIN_CLOSE_FACTOR = 1e18;
  uint128 internal constant MAX_CLOSE_FACTOR = 2e18;
  uint256 internal constant MAX_COLLATERAL_FACTOR = 100_00;
  uint256 internal constant MAX_ASSET_PRICE = 1e8 * 1e8;
  uint256 internal constant MAX_LIQUIDATION_PROTOCOL_FEE_PERCENTAGE =
    PercentageMath.PERCENTAGE_FACTOR;
  IHubBase.PremiumDelta internal ZERO_PREMIUM_DELTA;

  IAaveOracle internal oracle1;
  IAaveOracle internal oracle2;
  IAaveOracle internal oracle3;
  IHub internal hub1;
  ITreasurySpoke internal treasurySpoke;
  ISpoke internal spoke1;
  ISpoke internal spoke2;
  ISpoke internal spoke3;
  AssetInterestRateStrategy internal irStrategy;
  IAccessManager internal accessManager;

  string internal constant ALICE = 'alice';
  string internal constant BOB = 'bob';
  string internal constant CAROL = 'carol';
  string internal constant DERL = 'derl';

  address internal alice = makeAddr(ALICE);
  uint256 internal alicePk = makeKey(ALICE);
  address internal bob = makeAddr(BOB);
  uint256 internal bobPk = makeKey(BOB);
  address internal carol = makeAddr(CAROL);
  uint256 internal carolPk = makeKey(CAROL);
  address internal derl = makeAddr(DERL);
  uint256 internal derlPk = makeKey(DERL);

  address internal ADMIN = makeAddr('ADMIN');
  address internal HUB_ADMIN = makeAddr('HUB_ADMIN');
  address internal SPOKE_ADMIN = makeAddr('SPOKE_ADMIN');
  address internal USER_POSITION_UPDATER = makeAddr('USER_POSITION_UPDATER');
  address internal DEFICIT_ELIMINATOR = makeAddr('DEFICIT_ELIMINATOR');
  address internal TREASURY_ADMIN = makeAddr('TREASURY_ADMIN');
  address internal LIQUIDATOR = makeAddr('LIQUIDATOR');
  address internal POSITION_MANAGER = makeAddr('POSITION_MANAGER');
  address internal HUB_CONFIGURATOR = makeAddr('HUB_CONFIGURATOR');
  address internal SPOKE_CONFIGURATOR = makeAddr('SPOKE_CONFIGURATOR');

  TokenList internal tokenList;
  uint256 internal wethAssetId = 0;
  uint256 internal usdxAssetId = 1;
  uint256 internal daiAssetId = 2;
  uint256 internal wbtcAssetId = 3;
  uint256 internal usdyAssetId = 4;
  uint256 internal usdzAssetId = 5;

  mapping(ISpoke => SpokeInfo) internal spokeInfo;

  /// @notice Pauses the prank mode to allow test helpers to prank other actors.
  modifier pausePrank() {
    (VmSafe.CallerMode callerMode, address msgSender, address txOrigin) = vm.readCallers();
    if (callerMode == VmSafe.CallerMode.RecurrentPrank) vm.stopPrank();
    _;
    if (callerMode == VmSafe.CallerMode.RecurrentPrank) vm.startPrank(msgSender, txOrigin);
  }

  function _getProxyAdminAddress(address proxy) internal view returns (address) {
    bytes32 slotData = vm.load(proxy, ERC1967_ADMIN_SLOT);
    return address(uint160(uint256(slotData)));
  }

  function _getImplementationAddress(address proxy) internal view returns (address) {
    bytes32 slotData = vm.load(proxy, IMPLEMENTATION_SLOT);
    return address(uint160(uint256(slotData)));
  }

  function _getProxyInitializedVersion(address proxy) internal view returns (uint64) {
    bytes32 slotData = vm.load(proxy, INITIALIZABLE_SLOT);
    return uint64(uint256(slotData) & ((1 << 64) - 1));
  }

  function makeEntity(string memory id, bytes32 key) internal returns (address) {
    return makeAddr(string.concat(id, '-', vm.toString(uint256(key))));
  }

  function makeUser(uint256 i) internal returns (address) {
    return makeEntity('user', bytes32(i));
  }

  function makeUser() internal returns (address) {
    return makeEntity('user', vm.randomBytes8());
  }

  function makeSpoke() internal returns (address) {
    return makeEntity('spoke', vm.randomBytes8());
  }

  function makeKey(string memory name) internal returns (uint256) {
    (, uint256 key) = makeAddrAndKey(name);
    return key;
  }

  function _randomBps() internal returns (uint16) {
    return vm.randomUint(0, PercentageMath.PERCENTAGE_FACTOR).toUint16();
  }

  function _randomAddressOmit(address omit) internal returns (address) {
    address addr = vm.randomAddress();
    while (addr == omit) addr = vm.randomAddress();
    return addr;
  }

  function _bpsToRay(uint256 bps) internal pure returns (uint256) {
    return (bps * WadRayMath.RAY) / PercentageMath.PERCENTAGE_FACTOR;
  }

  function _assumeValidSupplier(address user) internal view {
    vm.assume(
      user != address(0) &&
        user != address(hub1) &&
        user != address(spoke1) &&
        user != address(spoke2) &&
        user != address(spoke3) &&
        user != _getProxyAdminAddress(address(spoke1)) &&
        user != _getProxyAdminAddress(address(spoke2)) &&
        user != _getProxyAdminAddress(address(spoke3))
    );
  }

  function _underlying(ISpoke spoke, uint256 reserveId) internal view returns (TestnetERC20) {
    return TestnetERC20(spoke.getReserve(reserveId).underlying);
  }

  function _hub(ISpoke spoke, uint256 reserveId) internal view returns (IHub) {
    return IHub(address(spoke.getReserve(reserveId).hub));
  }

  function _reserveAssetId(ISpoke spoke, uint256 reserveId) internal view returns (uint256) {
    return spoke.getReserve(reserveId).assetId;
  }
}
