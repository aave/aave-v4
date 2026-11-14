// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {
  AssetInterestRateStrategy,
  IAssetInterestRateStrategy
} from 'src/hub/AssetInterestRateStrategy.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {ITreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/SpokeConfigurator.sol';
import {CommonHelpers} from 'tests/helpers/commons/CommonHelpers.sol';
import {HubHelpers} from 'tests/helpers/hub/HubHelpers.sol';
import {SpokeHelpers} from 'tests/helpers/spoke/SpokeHelpers.sol';
import {TestnetERC20} from 'tests/helpers/mocks/TestnetERC20.sol';
import {TestTypes} from 'tests/utils/TestTypes.sol';

/// @title BaseState
/// @notice Shared state variables, constants, and low-level helpers for the Aave V4 test suite.
abstract contract BaseState is HubHelpers, SpokeHelpers {
  using WadRayMath for *;
  using PercentageMath for uint256;
  using SafeCast for *;

  struct SpokeInfo {
    ReserveInfo weth;
    ReserveInfo wbtc;
    ReserveInfo dai;
    ReserveInfo usdx;
    ReserveInfo usdy;
    ReserveInfo usdz;
  }

  struct BorrowTestData {
    uint256 daiReserveId;
    uint256 wethReserveId;
    uint256 usdxReserveId;
    uint256 wbtcReserveId;
    UserActionData daiAlice;
    UserActionData wethAlice;
    UserActionData usdxAlice;
    UserActionData wbtcAlice;
    UserActionData daiBob;
    UserActionData wethBob;
    UserActionData usdxBob;
    UserActionData wbtcBob;
  }

  struct ReserveIds {
    uint256 dai;
    uint256 weth;
    uint256 usdx;
    uint256 wbtc;
  }

  struct Decimals {
    uint8 usdx;
    uint8 dai;
    uint8 wbtc;
    uint8 usdy;
    uint8 weth;
    uint8 usdz;
  }

  struct FixtureAssetList {
    IERC20Metadata underlying;
    uint16 liquidityFee;
    address reinvestmentController;
    bytes irData;
  }

  uint256 public constant MAX_SKIP_TIME = 10_000 days;

  uint256 internal MAX_SUPPLY_AMOUNT_USDX;
  uint256 internal MAX_SUPPLY_AMOUNT_DAI;
  uint256 internal MAX_SUPPLY_AMOUNT_WBTC;
  uint256 internal MAX_SUPPLY_AMOUNT_WETH;
  uint256 internal MAX_SUPPLY_AMOUNT_USDY;
  uint256 internal MAX_SUPPLY_AMOUNT_USDZ;
  uint256 internal constant MAX_SUPPLY_IN_BASE_CURRENCY = 1e39;
  uint256 internal constant MAX_SUPPLY_PRICE = 100;
  uint256 internal constant MAX_DRAWN_INDEX = 100 * WadRayMath.RAY;
  uint128 internal constant MAX_TARGET_HEALTH_FACTOR = 2e18;
  uint256 internal constant MAX_ASSET_PRICE = 1e8 * 1e8;
  /// @dev ERC-7201 slot of OpenZeppelin's ReentrancyGuard, derived here rather than read from src.
  bytes32 internal constant REENTRANCY_GUARD_SLOT =
    keccak256(abi.encode(uint256(keccak256('openzeppelin.storage.ReentrancyGuard')) - 1)) &
      ~bytes32(uint256(0xff));
  bytes32 internal constant REENTRANCY_GUARD_ENTERED = bytes32(uint256(1));
  IHubBase.PremiumDelta internal ZERO_PREMIUM_DELTA;

  IHub[] internal _hubs;
  ISpoke[] internal _spokes;
  IAaveOracle[] internal _oracles;
  IAssetInterestRateStrategy[] internal _irStrategies;

  IAaveOracle internal oracle1;
  IAaveOracle internal oracle2;
  IAaveOracle internal oracle3;
  IHub internal hub1;
  ITreasurySpoke internal treasurySpoke;
  ISpoke internal spoke1;
  ISpoke internal spoke2;
  ISpoke internal spoke3;
  IAssetInterestRateStrategy internal irStrategy;
  IAccessManager internal accessManager;
  IHubConfigurator internal hubConfigurator;
  ISpokeConfigurator internal spokeConfigurator;

  string internal constant ALICE = 'alice';
  string internal constant BOB = 'bob';
  string internal constant CAROL = 'carol';
  string internal constant DERL = 'derl';

  address internal alice = makeAddr(ALICE);
  uint256 internal alicePk = _makeKey(ALICE);
  address internal bob = makeAddr(BOB);
  uint256 internal bobPk = _makeKey(BOB);
  address internal carol = makeAddr(CAROL);
  address internal derl = makeAddr(DERL);

  address internal ADMIN = makeAddr('ADMIN');
  address internal HUB_ADMIN = makeAddr('HUB_ADMIN');
  address internal SPOKE_ADMIN = makeAddr('SPOKE_ADMIN');
  address internal USER_POSITION_UPDATER = makeAddr('USER_POSITION_UPDATER');
  address internal DEFICIT_ELIMINATOR = makeAddr('DEFICIT_ELIMINATOR');
  address internal TREASURY_ADMIN = makeAddr('TREASURY_ADMIN');
  address internal LIQUIDATOR = makeAddr('LIQUIDATOR');
  address internal POSITION_MANAGER = makeAddr('POSITION_MANAGER');
  address internal HUB_CONFIGURATOR_ADMIN = makeAddr('HUB_CONFIGURATOR_ADMIN');
  address internal SPOKE_CONFIGURATOR_ADMIN = makeAddr('SPOKE_CONFIGURATOR_ADMIN');

  TestTypes.TokenList internal tokenList;
  uint256 internal wethAssetId = 0;
  uint256 internal usdxAssetId = 1;
  uint256 internal daiAssetId = 2;
  uint256 internal wbtcAssetId = 3;
  uint256 internal usdyAssetId = 4;
  uint256 internal usdzAssetId = 5;

  uint256 internal mintAmount_WETH = MAX_SUPPLY_AMOUNT;
  uint256 internal mintAmount_USDX = MAX_SUPPLY_AMOUNT;
  uint256 internal mintAmount_DAI = MAX_SUPPLY_AMOUNT;
  uint256 internal mintAmount_WBTC = MAX_SUPPLY_AMOUNT;
  uint256 internal mintAmount_USDY = MAX_SUPPLY_AMOUNT;
  uint256 internal mintAmount_USDZ = MAX_SUPPLY_AMOUNT;

  Decimals internal _decimals = Decimals({usdx: 6, usdy: 18, dai: 18, wbtc: 8, weth: 18, usdz: 18});

  IAssetInterestRateStrategy.InterestRateData internal _defaultIrData =
    IAssetInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 90_00,
      baseDrawnRate: 5_00,
      rateGrowthBeforeOptimal: 5_00,
      rateGrowthAfterOptimal: 5_00
    });

  mapping(ISpoke => SpokeInfo) internal spokeInfo;

  function _defaultUsers() internal view returns (address[] memory users) {
    users = new address[](4);
    users[0] = alice;
    users[1] = bob;
    users[2] = carol;
    users[3] = derl;
  }

  function _assumeValidSupplier(address user) internal view {
    vm.assume(
      user != address(0) &&
        user != address(hub1) &&
        user != address(spoke1) &&
        user != address(spoke2) &&
        user != address(spoke3) &&
        user != _getProxyAdminAddress(address(hub1)) &&
        user != _getProxyAdminAddress(address(spoke1)) &&
        user != _getProxyAdminAddress(address(spoke2)) &&
        user != _getProxyAdminAddress(address(spoke3))
    );
  }
}
