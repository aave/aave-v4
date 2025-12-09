pragma solidity ^0.8.0;

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {Hub} from 'src/hub/Hub.sol';
import {TreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';
import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';
import {
  TransparentUpgradeableProxy
} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {Spoke} from 'src/spoke/Spoke.sol';
import {PropertiesLibString} from 'tests/tob/PropertiesLibString.sol';

import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';
import {Constants} from 'tests/Constants.sol';

interface StdCheats {
  function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);

  // Set block.timestamp
  function warp(uint256) external;

  // Set block.number
  function roll(uint256) external;

  // Set block.basefee
  function fee(uint256) external;

  // Set block.difficulty (deprecated in `medusa`)
  function difficulty(uint256) external;

  // Set block.prevrandao
  function prevrandao(bytes32) external;

  // Set block.chainid
  function chainId(uint256) external;

  // Sets the block.coinbase
  function coinbase(address) external;

  // Loads a storage slot from an address
  function load(address account, bytes32 slot) external returns (bytes32);

  // Stores a value to an address' storage slot
  function store(address account, bytes32 slot, bytes32 value) external;

  // Sets the *next* call's msg.sender to be the input address
  function prank(address) external;

  // Sets all subsequent call's msg.sender (until stopPrank is called) to be the input address
  function startPrank(address) external;

  // Stops a previously called startPrank
  function stopPrank() external;

  // Set msg.sender to the input address until the current call exits
  function prankHere(address) external;

  // Sets an address' balance
  function deal(address who, uint256 newBalance) external;

  // Sets an address' code
  function etch(address who, bytes calldata code) external;

  // Signs data
  function sign(
    uint256 privateKey,
    bytes32 digest
  ) external returns (uint8 v, bytes32 r, bytes32 s);

  // Computes address for a given private key
  function addr(uint256 privateKey) external returns (address);

  // Gets the creation bytecode of a contract
  function getCode(string calldata) external returns (bytes memory);

  // Gets the nonce of an account
  function getNonce(address account) external returns (uint64);

  // Sets the nonce of an account
  // The new nonce must be higher than the current nonce of the account
  function setNonce(address account, uint64 nonce) external;

  // Performs a foreign function call via terminal
  function ffi(string[] calldata) external returns (bytes memory);

  // Take a snapshot of the current state of the EVM
  function snapshot() external returns (uint256);

  // Revert state back to a snapshot
  function revertTo(uint256) external returns (bool);

  // Convert Solidity types to strings
  function toString(address) external returns (string memory);
  function toString(bytes calldata) external returns (string memory);
  function toString(bytes32) external returns (string memory);
  function toString(bool) external returns (string memory);
  function toString(uint256) external returns (string memory);
  function toString(int256) external returns (string memory);

  // Convert strings into Solidity types
  function parseBytes(string memory) external returns (bytes memory);
  function parseBytes32(string memory) external returns (bytes32);
  function parseAddress(string memory) external returns (address);
  function parseUint(string memory) external returns (uint256);
  function parseInt(string memory) external returns (int256);
  function parseBool(string memory) external returns (bool);
}
abstract contract PropertiesConstants {
  // Constant echidna addresses
  address constant USER1 = address(0x10000);
  address constant USER2 = address(0x20000);
  address constant USER3 = address(0x30000);
  address[3] USERS = [USER1, USER2, USER3];
  uint256 constant INITIAL_BALANCE = 1000e18;

  // Constant specific to Aave
  address constant ADMIN = address(0x40000);
  address constant DEPLOYER = address(0x50000);
}
abstract contract PropertiesAsserts {
  event LogUint256(string, uint256);
  event LogAddress(string, address);
  event LogString(string);
  event LogBytes(bytes);
  event AssertFail(string);
  event AssertEqFail(string);
  event AssertNeqFail(string);
  event AssertGteFail(string);
  event AssertGtFail(string);
  event AssertLteFail(string);
  event AssertLtFail(string);

  function assertWithMsg(bool b, string memory reason) internal {
    if (!b) {
      emit AssertFail(reason);
      assert(false);
    }
  }

  /// @notice asserts that a is equal to b. Violations are logged using reason.
  function assertEq(uint256 a, uint256 b, string memory reason) internal {
    if (a != b) {
      string memory aStr = PropertiesLibString.toString(a);
      string memory bStr = PropertiesLibString.toString(b);
      bytes memory assertMsg = abi.encodePacked(
        'Invalid: ',
        aStr,
        '!=',
        bStr,
        ', reason: ',
        reason
      );
      emit AssertEqFail(string(assertMsg));
      assert(false);
    }
  }

  /// @notice int256 version of assertEq
  function assertEq(int256 a, int256 b, string memory reason) internal {
    if (a != b) {
      string memory aStr = PropertiesLibString.toString(a);
      string memory bStr = PropertiesLibString.toString(b);
      bytes memory assertMsg = abi.encodePacked(
        'Invalid: ',
        aStr,
        '!=',
        bStr,
        ', reason: ',
        reason
      );
      emit AssertEqFail(string(assertMsg));
      assert(false);
    }
  }

  /// @notice asserts that a is not equal to b. Violations are logged using reason.
  function assertNeq(uint256 a, uint256 b, string memory reason) internal {
    if (a == b) {
      string memory aStr = PropertiesLibString.toString(a);
      string memory bStr = PropertiesLibString.toString(b);
      bytes memory assertMsg = abi.encodePacked(
        'Invalid: ',
        aStr,
        '==',
        bStr,
        ', reason: ',
        reason
      );
      emit AssertNeqFail(string(assertMsg));
      assert(false);
    }
  }

  /// @notice int256 version of assertNeq
  function assertNeq(int256 a, int256 b, string memory reason) internal {
    if (a == b) {
      string memory aStr = PropertiesLibString.toString(a);
      string memory bStr = PropertiesLibString.toString(b);
      bytes memory assertMsg = abi.encodePacked(
        'Invalid: ',
        aStr,
        '==',
        bStr,
        ', reason: ',
        reason
      );
      emit AssertNeqFail(string(assertMsg));
      assert(false);
    }
  }

  /// @notice asserts that a is greater than or equal to b. Violations are logged using reason.
  function assertGte(uint256 a, uint256 b, string memory reason) internal {
    if (!(a >= b)) {
      string memory aStr = PropertiesLibString.toString(a);
      string memory bStr = PropertiesLibString.toString(b);
      bytes memory assertMsg = abi.encodePacked(
        'Invalid: ',
        aStr,
        '<',
        bStr,
        ' failed, reason: ',
        reason
      );
      emit AssertGteFail(string(assertMsg));
      assert(false);
    }
  }

  /// @notice int256 version of assertGte
  function assertGte(int256 a, int256 b, string memory reason) internal {
    if (!(a >= b)) {
      string memory aStr = PropertiesLibString.toString(a);
      string memory bStr = PropertiesLibString.toString(b);
      bytes memory assertMsg = abi.encodePacked(
        'Invalid: ',
        aStr,
        '<',
        bStr,
        ' failed, reason: ',
        reason
      );
      emit AssertGteFail(string(assertMsg));
      assert(false);
    }
  }

  /// @notice asserts that a is greater than b. Violations are logged using reason.
  function assertGt(uint256 a, uint256 b, string memory reason) internal {
    if (!(a > b)) {
      string memory aStr = PropertiesLibString.toString(a);
      string memory bStr = PropertiesLibString.toString(b);
      bytes memory assertMsg = abi.encodePacked(
        'Invalid: ',
        aStr,
        '<=',
        bStr,
        ' failed, reason: ',
        reason
      );
      emit AssertGtFail(string(assertMsg));
      assert(false);
    }
  }

  /// @notice int256 version of assertGt
  function assertGt(int256 a, int256 b, string memory reason) internal {
    if (!(a > b)) {
      string memory aStr = PropertiesLibString.toString(a);
      string memory bStr = PropertiesLibString.toString(b);
      bytes memory assertMsg = abi.encodePacked(
        'Invalid: ',
        aStr,
        '<=',
        bStr,
        ' failed, reason: ',
        reason
      );
      emit AssertGtFail(string(assertMsg));
      assert(false);
    }
  }

  /// @notice asserts that a is less than or equal to b. Violations are logged using reason.
  function assertLte(uint256 a, uint256 b, string memory reason) internal {
    if (!(a <= b)) {
      string memory aStr = PropertiesLibString.toString(a);
      string memory bStr = PropertiesLibString.toString(b);
      bytes memory assertMsg = abi.encodePacked(
        'Invalid: ',
        aStr,
        '>',
        bStr,
        ' failed, reason: ',
        reason
      );
      emit AssertLteFail(string(assertMsg));
      assert(false);
    }
  }

  /// @notice int256 version of assertLte
  function assertLte(int256 a, int256 b, string memory reason) internal {
    if (!(a <= b)) {
      string memory aStr = PropertiesLibString.toString(a);
      string memory bStr = PropertiesLibString.toString(b);
      bytes memory assertMsg = abi.encodePacked(
        'Invalid: ',
        aStr,
        '>',
        bStr,
        ' failed, reason: ',
        reason
      );
      emit AssertLteFail(string(assertMsg));
      assert(false);
    }
  }

  /// @notice asserts that a is less than b. Violations are logged using reason.
  function assertLt(uint256 a, uint256 b, string memory reason) internal {
    if (!(a < b)) {
      string memory aStr = PropertiesLibString.toString(a);
      string memory bStr = PropertiesLibString.toString(b);
      bytes memory assertMsg = abi.encodePacked(
        'Invalid: ',
        aStr,
        '>=',
        bStr,
        ' failed, reason: ',
        reason
      );
      emit AssertLtFail(string(assertMsg));
      assert(false);
    }
  }

  /// @notice int256 version of assertLt
  function assertLt(int256 a, int256 b, string memory reason) internal {
    if (!(a < b)) {
      string memory aStr = PropertiesLibString.toString(a);
      string memory bStr = PropertiesLibString.toString(b);
      bytes memory assertMsg = abi.encodePacked(
        'Invalid: ',
        aStr,
        '>=',
        bStr,
        ' failed, reason: ',
        reason
      );
      emit AssertLtFail(string(assertMsg));
      assert(false);
    }
  }

  /// @notice Clamps value to be between low and high, both inclusive
  function clampBetween(uint256 value, uint256 low, uint256 high) internal returns (uint256) {
    if (value < low || value > high) {
      uint256 ans = low + (value % (high - low + 1));
      string memory valueStr = PropertiesLibString.toString(value);
      string memory ansStr = PropertiesLibString.toString(ans);
      bytes memory message = abi.encodePacked('Clamping value ', valueStr, ' to ', ansStr);
      emit LogString(string(message));
      return ans;
    }
    return value;
  }

  /// @notice int256 version of clampBetween
  function clampBetween(int256 value, int256 low, int256 high) internal returns (int256) {
    if (value < low || value > high) {
      int256 range = high - low + 1;
      int256 clamped = (value - low) % (range);
      if (clamped < 0) clamped += range;
      int256 ans = low + clamped;
      string memory valueStr = PropertiesLibString.toString(value);
      string memory ansStr = PropertiesLibString.toString(ans);
      bytes memory message = abi.encodePacked('Clamping value ', valueStr, ' to ', ansStr);
      emit LogString(string(message));
      return ans;
    }
    return value;
  }

  /// @notice clamps a to be less than b
  function clampLt(uint256 a, uint256 b) internal returns (uint256) {
    if (!(a < b)) {
      assertNeq(
        b,
        0,
        'clampLt cannot clamp value a to be less than zero. Check your inputs/assumptions.'
      );
      uint256 value = a % b;
      string memory aStr = PropertiesLibString.toString(a);
      string memory valueStr = PropertiesLibString.toString(value);
      bytes memory message = abi.encodePacked('Clamping value ', aStr, ' to ', valueStr);
      emit LogString(string(message));
      return value;
    }
    return a;
  }

  /// @notice int256 version of clampLt
  function clampLt(int256 a, int256 b) internal returns (int256) {
    if (!(a < b)) {
      int256 value = b - 1;
      string memory aStr = PropertiesLibString.toString(a);
      string memory valueStr = PropertiesLibString.toString(value);
      bytes memory message = abi.encodePacked('Clamping value ', aStr, ' to ', valueStr);
      emit LogString(string(message));
      return value;
    }
    return a;
  }

  /// @notice clamps a to be less than or equal to b
  function clampLte(uint256 a, uint256 b) internal returns (uint256) {
    if (!(a <= b)) {
      uint256 value = a % (b + 1);
      string memory aStr = PropertiesLibString.toString(a);
      string memory valueStr = PropertiesLibString.toString(value);
      bytes memory message = abi.encodePacked('Clamping value ', aStr, ' to ', valueStr);
      emit LogString(string(message));
      return value;
    }
    return a;
  }

  /// @notice int256 version of clampLte
  function clampLte(int256 a, int256 b) internal returns (int256) {
    if (!(a <= b)) {
      int256 value = b;
      string memory aStr = PropertiesLibString.toString(a);
      string memory valueStr = PropertiesLibString.toString(value);
      bytes memory message = abi.encodePacked('Clamping value ', aStr, ' to ', valueStr);
      emit LogString(string(message));
      return value;
    }
    return a;
  }

  /// @notice clamps a to be greater than b
  function clampGt(uint256 a, uint256 b) internal returns (uint256) {
    if (!(a > b)) {
      assertNeq(
        b,
        type(uint256).max,
        'clampGt cannot clamp value a to be larger than uint256.max. Check your inputs/assumptions.'
      );
      uint256 value = b + 1;
      string memory aStr = PropertiesLibString.toString(a);
      string memory valueStr = PropertiesLibString.toString(value);
      bytes memory message = abi.encodePacked('Clamping value ', aStr, ' to ', valueStr);
      emit LogString(string(message));
      return value;
    } else {
      return a;
    }
  }

  /// @notice int256 version of clampGt
  function clampGt(int256 a, int256 b) internal returns (int256) {
    if (!(a > b)) {
      int256 value = b + 1;
      string memory aStr = PropertiesLibString.toString(a);
      string memory valueStr = PropertiesLibString.toString(value);
      bytes memory message = abi.encodePacked('Clamping value ', aStr, ' to ', valueStr);
      emit LogString(string(message));
      return value;
    } else {
      return a;
    }
  }

  /// @notice clamps a to be greater than or equal to b
  function clampGte(uint256 a, uint256 b) internal returns (uint256) {
    if (!(a > b)) {
      uint256 value = b;
      string memory aStr = PropertiesLibString.toString(a);
      string memory valueStr = PropertiesLibString.toString(value);
      bytes memory message = abi.encodePacked('Clamping value ', aStr, ' to ', valueStr);
      emit LogString(string(message));
      return value;
    }
    return a;
  }

  /// @notice int256 version of clampGte
  function clampGte(int256 a, int256 b) internal returns (int256) {
    if (!(a > b)) {
      int256 value = b;
      string memory aStr = PropertiesLibString.toString(a);
      string memory valueStr = PropertiesLibString.toString(value);
      bytes memory message = abi.encodePacked('Clamping value ', aStr, ' to ', valueStr);
      emit LogString(string(message));
      return value;
    }
    return a;
  }

  function extractErrorSelector(bytes memory revertData) internal returns (uint256) {
    if (revertData.length < 4) {
      emit LogString('Return data too short.');
      return 0;
    }

    uint256 errorSelector = uint256(
      (uint256(uint8(revertData[0])) << 24) |
        (uint256(uint8(revertData[1])) << 16) |
        (uint256(uint8(revertData[2])) << 8) |
        uint256(uint8(revertData[3]))
    );

    return errorSelector;
  }
}
contract FuzzingBase is PropertiesConstants, PropertiesAsserts {
  using WadRayMath for uint256;

  bool public constant IS_TEST = true;

  StdCheats constant vm = StdCheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
  AccessManager internal accessManager;
  // Note: we start with a single hub, it can be extended to multiple hubs in the future
  IHub internal hub1;
  ITreasurySpoke internal treasurySpoke;
  AssetInterestRateStrategy internal irStrategy;
  IAaveOracle internal oracle1;
  IAaveOracle internal oracle2;
  IAaveOracle internal oracle3;
  ISpoke internal spoke1;
  ISpoke internal spoke2;
  ISpoke internal spoke3;
  IERC20 internal dai;
  IERC20 internal wbtc;
  IERC20 internal usdx;

  uint256 internal usdxAssetId = 0;
  uint256 internal daiAssetId = 1;
  uint256 internal wbtcAssetId = 2;

  struct Decimals {
    uint8 usdx;
    uint8 dai;
    uint8 wbtc;
  }

  struct SpokeInfo {
    ReserveInfo wbtc;
    ReserveInfo dai;
    ReserveInfo usdx;
    uint256 MAX_ALLOWED_ASSET_ID;
    uint256[] reserveIds;
  }

  struct ReserveInfo {
    uint256 reserveId;
    ISpoke.ReserveConfig reserveConfig;
    ISpoke.DynamicReserveConfig dynReserveConfig;
  }

  struct OldBalances {
    uint256 hubUnderlying;
    uint256 userUnderlying;
  }

  struct TokenList {
    TestnetERC20 usdx;
    TestnetERC20 dai;
    TestnetERC20 wbtc;
  }

  Decimals decimals = Decimals({usdx: 6, dai: 18, wbtc: 8});

  mapping(ISpoke => SpokeInfo) internal spokeInfo;
  ISpoke[] internal spokes;
  IERC20[] internal tokens;
  // Used in global invariants checks
  address[] internal spokes_with_feeReceiver;

  constructor() {
    accessManager = new AccessManager(ADMIN);
    hub1 = new Hub(address(accessManager));
    irStrategy = new AssetInterestRateStrategy(address(hub1));
    (spoke1, oracle1) = _deploySpokeWithOracle(ADMIN, address(accessManager), 'Spoke 1 (USD)', 6);
    (spoke2, oracle2) = _deploySpokeWithOracle(ADMIN, address(accessManager), 'Spoke 2 (USD)', 9);
    (spoke3, oracle3) = _deploySpokeWithOracle(ADMIN, address(accessManager), 'Spoke 3 (USD)', 12);
    treasurySpoke = ITreasurySpoke(new TreasurySpoke(ADMIN, address(hub1)));
    spokes_with_feeReceiver.push(address(treasurySpoke));
    dai = new TestnetERC20('DAI', 'DAI', decimals.dai);
    wbtc = new TestnetERC20('WBTC', 'WBTC', decimals.wbtc);
    usdx = new TestnetERC20('USDX', 'USDX', decimals.usdx);
    tokens.push(dai);
    tokens.push(wbtc);
    tokens.push(usdx);
    configureTokenList();
  }

  function _deploySpokeWithOracle(
    address proxyAdminOwner,
    address _accessManager,
    string memory _oracleDesc,
    uint256 _nonce
  ) internal returns (ISpoke, IAaveOracle) {
    address predictedSpoke = _createAddressFrom(address(this), _nonce);
    IAaveOracle oracle = new AaveOracle(predictedSpoke, 8, _oracleDesc);
    address spokeImpl = address(new SpokeInstance(address(oracle)));
    ISpoke spoke = ISpoke(
      _proxify(
        address(this),
        spokeImpl,
        proxyAdminOwner,
        abi.encodeCall(Spoke.initialize, (_accessManager))
      )
    );
    spokes.push(spoke);
    spokes_with_feeReceiver.push(address(spoke));
    return (spoke, oracle);
  }

  function _proxify(
    address deployer,
    address impl,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (address) {
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      impl,
      proxyAdminOwner,
      initData
    );
    return address(proxy);
  }

  function _createAddressFrom(
    address origin,
    uint256 nonce
  ) internal pure returns (address _address) {
    bytes memory data;
    if (nonce == 0x00) {
      data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), origin, bytes1(0x80));
    } else if (nonce <= 0x7f) {
      data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), origin, uint8(nonce));
    } else if (nonce <= 0xff) {
      data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), origin, bytes1(0x81), uint8(nonce));
    } else if (nonce <= 0xffff) {
      data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), origin, bytes1(0x82), uint16(nonce));
    } else if (nonce <= 0xffffff) {
      data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), origin, bytes1(0x83), uint24(nonce));
    } else {
      data = abi.encodePacked(bytes1(0xda), bytes1(0x94), origin, bytes1(0x84), uint32(nonce));
    }
    bytes32 hash = keccak256(data);
    assembly {
      mstore(0, hash)
      _address := mload(0)
    }
  }

  function configureTokenList() internal {
    TokenList memory tokenList;
    tokenList = TokenList(
      new TestnetERC20('USDX', 'USDX', 6),
      new TestnetERC20('DAI', 'DAI', decimals.dai),
      new TestnetERC20('WBTC', 'WBTC', decimals.wbtc)
    );

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
    });

    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );

    // Add all assets to the Hub
    vm.startPrank(ADMIN);
    // add USDX
    hub1.addAsset(
      address(tokenList.usdx),
      tokenList.usdx.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.updateAssetConfig(
      usdxAssetId,
      IHub.AssetConfig({
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      }),
      new bytes(0)
    );
    // add DAI
    hub1.addAsset(
      address(tokenList.dai),
      tokenList.dai.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.updateAssetConfig(
      daiAssetId,
      IHub.AssetConfig({
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      }),
      new bytes(0)
    );
    // add WBTC
    hub1.addAsset(
      address(tokenList.wbtc),
      tokenList.wbtc.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.updateAssetConfig(
      wbtcAssetId,
      IHub.AssetConfig({
        liquidityFee: 10_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      }),
      new bytes(0)
    );

    // Liquidation configs
    spoke1.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: 0.7e18,
        liquidationBonusFactor: 20_00
      })
    );
    spoke2.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.04e18,
        healthFactorForMaxBonus: 0.8e18,
        liquidationBonusFactor: 15_00
      })
    );
    spoke3.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.03e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 10_00
      })
    );

    // Spoke 1 reserve configs
    spokeInfo[spoke1].wbtc.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 15_00,
      liquidatable: true,
      receiveSharesEnabled: true
    });
    spokeInfo[spoke1].wbtc.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 75_00,
      maxLiquidationBonus: 103_00,
      liquidationFee: 15_00
    });
    spokeInfo[spoke1].dai.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 20_00,
      liquidatable: true,
      receiveSharesEnabled: true
    });
    spokeInfo[spoke1].dai.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 78_00,
      maxLiquidationBonus: 102_00,
      liquidationFee: 10_00
    });
    spokeInfo[spoke1].usdx.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 50_00,
      liquidatable: true,
      receiveSharesEnabled: true
    });
    spokeInfo[spoke1].usdx.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 78_00,
      maxLiquidationBonus: 101_00,
      liquidationFee: 12_00
    });

    spokeInfo[spoke1].wbtc.reserveId = spoke1.addReserve(
      address(hub1),
      wbtcAssetId,
      _deployMockPriceFeed(spoke1, 50_000e8),
      spokeInfo[spoke1].wbtc.reserveConfig,
      spokeInfo[spoke1].wbtc.dynReserveConfig
    );
    spokeInfo[spoke1].reserveIds.push(spokeInfo[spoke1].wbtc.reserveId);
    spokeInfo[spoke1].dai.reserveId = spoke1.addReserve(
      address(hub1),
      daiAssetId,
      _deployMockPriceFeed(spoke1, 1e8),
      spokeInfo[spoke1].dai.reserveConfig,
      spokeInfo[spoke1].dai.dynReserveConfig
    );
    spokeInfo[spoke1].reserveIds.push(spokeInfo[spoke1].dai.reserveId);
    spokeInfo[spoke1].usdx.reserveId = spoke1.addReserve(
      address(hub1),
      usdxAssetId,
      _deployMockPriceFeed(spoke1, 1e8),
      spokeInfo[spoke1].usdx.reserveConfig,
      spokeInfo[spoke1].usdx.dynReserveConfig
    );
    spokeInfo[spoke1].reserveIds.push(spokeInfo[spoke1].usdx.reserveId);

    hub1.addSpoke(wbtcAssetId, address(spoke1), spokeConfig);
    hub1.addSpoke(daiAssetId, address(spoke1), spokeConfig);
    hub1.addSpoke(usdxAssetId, address(spoke1), spokeConfig);

    // Spoke 2 reserve configs
    spokeInfo[spoke2].wbtc.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 0,
      liquidatable: true,
      receiveSharesEnabled: true
    });
    spokeInfo[spoke2].wbtc.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 80_00,
      maxLiquidationBonus: 105_00,
      liquidationFee: 10_00
    });
    spokeInfo[spoke2].dai.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 20_00,
      liquidatable: true,
      receiveSharesEnabled: true
    });
    spokeInfo[spoke2].dai.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 72_00,
      maxLiquidationBonus: 102_00,
      liquidationFee: 10_00
    });
    spokeInfo[spoke2].usdx.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 50_00,
      liquidatable: true,
      receiveSharesEnabled: true
    });
    spokeInfo[spoke2].usdx.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 72_00,
      maxLiquidationBonus: 101_00,
      liquidationFee: 12_00
    });

    spokeInfo[spoke2].wbtc.reserveId = spoke2.addReserve(
      address(hub1),
      wbtcAssetId,
      _deployMockPriceFeed(spoke2, 50_000e8),
      spokeInfo[spoke2].wbtc.reserveConfig,
      spokeInfo[spoke2].wbtc.dynReserveConfig
    );
    spokeInfo[spoke2].reserveIds.push(spokeInfo[spoke2].wbtc.reserveId);
    spokeInfo[spoke2].dai.reserveId = spoke2.addReserve(
      address(hub1),
      daiAssetId,
      _deployMockPriceFeed(spoke2, 1e8),
      spokeInfo[spoke2].dai.reserveConfig,
      spokeInfo[spoke2].dai.dynReserveConfig
    );
    spokeInfo[spoke2].reserveIds.push(spokeInfo[spoke2].dai.reserveId);
    spokeInfo[spoke2].usdx.reserveId = spoke2.addReserve(
      address(hub1),
      usdxAssetId,
      _deployMockPriceFeed(spoke2, 1e8),
      spokeInfo[spoke2].usdx.reserveConfig,
      spokeInfo[spoke2].usdx.dynReserveConfig
    );
    spokeInfo[spoke2].reserveIds.push(spokeInfo[spoke2].usdx.reserveId);

    hub1.addSpoke(wbtcAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(daiAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(usdxAssetId, address(spoke2), spokeConfig);

    // Spoke 3 reserve configs
    spokeInfo[spoke3].dai.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 0,
      liquidatable: true,
      receiveSharesEnabled: true
    });
    spokeInfo[spoke3].dai.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 75_00,
      maxLiquidationBonus: 104_00,
      liquidationFee: 11_00
    });
    spokeInfo[spoke3].usdx.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 10_00,
      liquidatable: true,
      receiveSharesEnabled: true
    });
    spokeInfo[spoke3].usdx.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 75_00,
      maxLiquidationBonus: 103_00,
      liquidationFee: 15_00
    });
    spokeInfo[spoke3].wbtc.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 50_00,
      liquidatable: true,
      receiveSharesEnabled: true
    });
    spokeInfo[spoke3].wbtc.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 77_00,
      maxLiquidationBonus: 101_00,
      liquidationFee: 12_00
    });

    spokeInfo[spoke3].dai.reserveId = spoke3.addReserve(
      address(hub1),
      daiAssetId,
      _deployMockPriceFeed(spoke3, 1e8),
      spokeInfo[spoke3].dai.reserveConfig,
      spokeInfo[spoke3].dai.dynReserveConfig
    );
    spokeInfo[spoke3].reserveIds.push(spokeInfo[spoke3].dai.reserveId);
    spokeInfo[spoke3].usdx.reserveId = spoke3.addReserve(
      address(hub1),
      usdxAssetId,
      _deployMockPriceFeed(spoke3, 1e8),
      spokeInfo[spoke3].usdx.reserveConfig,
      spokeInfo[spoke3].usdx.dynReserveConfig
    );
    spokeInfo[spoke3].reserveIds.push(spokeInfo[spoke3].usdx.reserveId);
    spokeInfo[spoke3].wbtc.reserveId = spoke3.addReserve(
      address(hub1),
      wbtcAssetId,
      _deployMockPriceFeed(spoke3, 50_000e8),
      spokeInfo[spoke3].wbtc.reserveConfig,
      spokeInfo[spoke3].wbtc.dynReserveConfig
    );
    spokeInfo[spoke3].reserveIds.push(spokeInfo[spoke3].wbtc.reserveId);

    hub1.addSpoke(daiAssetId, address(spoke3), spokeConfig);
    hub1.addSpoke(usdxAssetId, address(spoke3), spokeConfig);
    hub1.addSpoke(wbtcAssetId, address(spoke3), spokeConfig);

    vm.stopPrank();
  }

  function _deployMockPriceFeed(ISpoke spoke, uint256 price) internal returns (address) {
    AaveOracle oracle = AaveOracle(spoke.ORACLE());
    return address(new MockPriceFeed(oracle.DECIMALS(), oracle.DESCRIPTION(), price));
  }

  function _min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  function _calculateExactRestoreAmount(
    uint256 drawn,
    uint256 premium,
    uint256 restoreAmount,
    uint256 assetId
  ) internal view returns (uint256, uint256, uint256) {
    if (restoreAmount <= premium) {
      return (0, restoreAmount, restoreAmount);
    }
    uint256 drawnRestored = _min(drawn, restoreAmount - premium);
    // round drawn debt to nearest whole share
    drawnRestored = hub1.previewRestoreByShares(
      assetId,
      hub1.previewRestoreByAssets(assetId, drawnRestored)
    );
    return (drawnRestored, premium, restoreAmount);
  }

  function _calculateExactRestoreAmount(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 repayAmount,
    uint256 assetId
  ) internal returns (uint256 baseRestored, uint256 premiumRestored, uint256 restoreAmount) {
    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke.getUserDebt(reserveId, user);
    require(userDrawnDebt + userPremiumDebt > 0);
    repayAmount = clampBetween(repayAmount, 1, ((userDrawnDebt + userPremiumDebt) * 11) / 10);
    return _calculateExactRestoreAmount(userDrawnDebt, userPremiumDebt, repayAmount, assetId);
  }

  function _convertValueToAmount(
    ISpoke spoke,
    uint256 reserveId,
    uint256 valueAmount,
    uint8 underlyingDecimals
  ) internal view returns (uint256) {
    return
      _convertValueToAmount(
        valueAmount,
        IPriceOracle(spoke.ORACLE()).getReservePrice(reserveId),
        10 ** underlyingDecimals
      );
  }

  function _convertValueToAmount(
    uint256 valueAmount,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal pure returns (uint256) {
    return ((valueAmount * assetUnit) / assetPrice).fromWadDown();
  }
}
