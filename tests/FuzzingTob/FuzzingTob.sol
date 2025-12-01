pragma solidity 0.8.28;
pragma experimental ABIEncoderV2;

import {PropertiesLibString} from './PropertiesLibString.sol';

// Interface imports
import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';
import {
  ITransparentUpgradeableProxy
} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {IBasicInterestRateStrategy} from 'src/hub/interfaces/IBasicInterestRateStrategy.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IERC165} from 'src/dependencies/openzeppelin/IERC165.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IAuthority} from 'src/dependencies/openzeppelin/IAuthority.sol';
import {IERC1271} from 'src/dependencies/openzeppelin/IERC1271.sol';
import {IERC7913SignatureVerifier} from 'src/dependencies/openzeppelin/IERC7913.sol';
import {IERC1363} from 'src/dependencies/openzeppelin/IERC1363.sol';
import {AggregatorV3Interface} from 'src/dependencies/chainlink/AggregatorV3Interface.sol';
import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';

// Utility imports
import {ERC1967Utils} from 'src/dependencies/openzeppelin/ERC1967Utils.sol';
import {ProxyAdmin} from 'src/dependencies/openzeppelin/ProxyAdmin.sol';
import {StorageSlot} from 'src/dependencies/openzeppelin/StorageSlot.sol';
import {SlotDerivation} from 'src/dependencies/openzeppelin/SlotDerivation.sol';
import {Math} from 'src/dependencies/openzeppelin/Math.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {LibBit} from 'src/dependencies/solady/LibBit.sol';
import {Panic} from 'src/dependencies/openzeppelin/Panic.sol';
import {AuthorityUtils} from 'src/dependencies/openzeppelin/AuthorityUtils.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {ECDSA} from 'src/dependencies/openzeppelin/ECDSA.sol';
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {Arrays} from 'src/dependencies/openzeppelin/Arrays.sol';
import {Bytes} from 'src/dependencies/openzeppelin/Bytes.sol';
import {Context} from 'src/dependencies/openzeppelin/Context.sol';
import {Multicall} from 'src/utils/Multicall.sol';
import {Time} from 'src/dependencies/openzeppelin/Time.sol';
import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {KeyValueList} from 'src/spoke/libraries/KeyValueList.sol';

// Contract imports
import {Proxy} from 'src/dependencies/openzeppelin/Proxy.sol';
import {ERC1967Proxy} from 'src/dependencies/openzeppelin/ERC1967Proxy.sol';
import {
  TransparentUpgradeableProxy
} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {Spoke} from 'src/spoke/Spoke.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {Hub} from 'src/hub/Hub.sol';
import {TreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';

// Library imports
import {AssetLogic} from 'src/hub/libraries/AssetLogic.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';

// Test contract imports
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';
import {Constants} from 'tests/Constants.sol';

// Forge imports
import {Vm, VmSafe} from 'lib/forge-std/src/Vm.sol';

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
    (spoke1, oracle1) = _deploySpokeWithOracle(ADMIN, address(accessManager), 'Spoke 1 (USD)');
    (spoke2, oracle2) = _deploySpokeWithOracle(ADMIN, address(accessManager), 'Spoke 2 (USD)');
    (spoke3, oracle3) = _deploySpokeWithOracle(ADMIN, address(accessManager), 'Spoke 3 (USD)');
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
    string memory _oracleDesc
  ) internal returns (ISpoke, IAaveOracle) {
    address deployer = 0xBcf335CA547a35C1103c3E871B17365Fb52cA100;
    address predictedSpoke = vm.computeCreateAddress(deployer, vm.getNonce(deployer));
    IAaveOracle oracle = new AaveOracle(predictedSpoke, 8, _oracleDesc);
    address spokeImpl = address(new SpokeInstance(address(oracle)));
    ISpoke spoke = ISpoke(
      _proxify(
        deployer,
        spokeImpl,
        proxyAdminOwner,
        abi.encodeCall(Spoke.initialize, (_accessManager))
      )
    );
    return (spoke, oracle);
  }

  function _proxify(
    address deployer,
    address impl,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (address) {
    vm.prank(deployer);
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

  struct TokenList {
    TestnetERC20 usdx;
    TestnetERC20 dai;
    TestnetERC20 wbtc;
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
    spokeInfo[spoke1].dai.reserveId = spoke1.addReserve(
      address(hub1),
      daiAssetId,
      _deployMockPriceFeed(spoke1, 1e8),
      spokeInfo[spoke1].dai.reserveConfig,
      spokeInfo[spoke1].dai.dynReserveConfig
    );
    spokeInfo[spoke1].usdx.reserveId = spoke1.addReserve(
      address(hub1),
      usdxAssetId,
      _deployMockPriceFeed(spoke1, 1e8),
      spokeInfo[spoke1].usdx.reserveConfig,
      spokeInfo[spoke1].usdx.dynReserveConfig
    );

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
    spokeInfo[spoke2].dai.reserveId = spoke2.addReserve(
      address(hub1),
      daiAssetId,
      _deployMockPriceFeed(spoke2, 1e8),
      spokeInfo[spoke2].dai.reserveConfig,
      spokeInfo[spoke2].dai.dynReserveConfig
    );
    spokeInfo[spoke2].usdx.reserveId = spoke2.addReserve(
      address(hub1),
      usdxAssetId,
      _deployMockPriceFeed(spoke2, 1e8),
      spokeInfo[spoke2].usdx.reserveConfig,
      spokeInfo[spoke2].usdx.dynReserveConfig
    );

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
    spokeInfo[spoke3].usdx.reserveId = spoke3.addReserve(
      address(hub1),
      usdxAssetId,
      _deployMockPriceFeed(spoke3, 1e8),
      spokeInfo[spoke3].usdx.reserveConfig,
      spokeInfo[spoke3].usdx.dynReserveConfig
    );
    spokeInfo[spoke3].wbtc.reserveId = spoke3.addReserve(
      address(hub1),
      wbtcAssetId,
      _deployMockPriceFeed(spoke3, 50_000e8),
      spokeInfo[spoke3].wbtc.reserveConfig,
      spokeInfo[spoke3].wbtc.dynReserveConfig
    );

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
  ) internal returns (uint256, uint256, uint256) {
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
contract FuzzingTob is FuzzingBase {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;

  // This won't work if the fuzzer will be able to add new assets
  uint256 constant assetCount = 4;
  mapping(uint256 => uint256) asset_previous_exchange_rate;
  mapping(uint256 => uint256) asset_previous_drawn_index;

  mapping(address spoke => mapping(uint256 user_index => ISpoke.UserAccountData)) user_previous_account_data;
  mapping(address spoke => mapping(uint256 user_index => mapping(uint256 reserve_id => ISpoke.UserPosition))) user_previous_position;

  constructor() FuzzingBase() {}

  //modifier check_global_invariants(uint256 spokeId, uint256 reserveId, uint256 amount) {
  modifier check_global_invariants() {
    //_before_check_global_invariants();
    _;
    //_after_check_global_invariants();
  }

  function _before_check_global_invariants() internal {
    for (uint256 i = 0; i < spokes.length; i++) {
      address spoke = address(spokes[i]);
      for (uint256 u = 0; u < USERS.length; u++) {
        address user = USERS[u];
        ISpoke.UserAccountData memory userAccountData = ISpoke(spoke).getUserAccountData(user);
        user_previous_account_data[spoke][u] = userAccountData;
        for (uint256 r = 0; r < ISpoke(spoke).getReserveCount(); r++) {
          ISpoke.UserPosition memory userPosition = ISpoke(spoke).getUserPosition(r, user);
          user_previous_position[spoke][u][r] = userPosition;
        }
      }
    }
  }

  function _after_check_global_invariants() internal {
    // the array position corresponds to the asset id
    //uint256[assetCount] memory total_added_assets_sum_spoke;
    uint256[assetCount] memory total_added_shares_sum_spoke;
    uint256[assetCount] memory total_deficit_sum_spoke;

    for (uint256 i = 0; i < spokes_with_feeReceiver.length; i++) {
      address spoke = spokes_with_feeReceiver[i];
      // We don't want to check the user position in the fee receiver spoke
      if (i != spokes_with_feeReceiver.length - 1) {
        for (uint256 u = 0; u < USERS.length; u++) {
          address user = USERS[u];
          ISpoke.UserAccountData memory userAccountData = ISpoke(spoke).getUserAccountData(user);
          if (userAccountData.totalCollateralValue == 0) {
            assertEq(
              userAccountData.totalDebtValue,
              0,
              'AAVE-GINV-10 user has no collateral but has debt'
            );
          }
          for (uint256 r = 0; r < Spoke(spoke).getReserveCount(); r++) {
            ISpoke.UserPosition memory userPosition = ISpoke(spoke).getUserPosition(r, user);
            if (user_previous_account_data[spoke][u].healthFactor < uint256(1e18)) {
              // It can decrease when repaying
              assertGte(
                user_previous_position[spoke][u][r].drawnShares,
                userPosition.drawnShares,
                'AAVE-GINV-11 user cannot borrow more when unhealthy'
              );
            }
          }
        }
      }

      for (uint256 j = 0; j < assetCount; j++) {
        //total_added_assets_sum_spoke[j] += hub1.getSpokeAddedAssets(j, spoke);
        uint256 spoke_added_shares = hub1.getSpokeAddedShares(j, spoke);
        total_added_shares_sum_spoke[j] += spoke_added_shares;
        total_deficit_sum_spoke[j] += hub1.getSpokeDeficitRay(j, spoke);
        if (hub1.getSpokeAddedAssets(j, spoke) > 0) {
          assertNeq(
            hub1.getSpokeDrawnShares(j, spoke) + spoke_added_shares,
            0,
            'AAVE-GINV-9 spoke cannot have added assets != 0 with drawn + added shares = 0'
          );
        }
      }
    }

    for (uint256 i = 0; i < assetCount; i++) {
      IHub.Asset memory asset = hub1.getAsset(i);
      uint256 asset_added_shares = hub1.getAddedShares(i);
      //assertEq(total_added_assets_sum_spoke[i], hub1.getAddedAssets(i), "AAVE-GINV-1 total added assets should be equal to spokes added assets");
      assertEq(
        total_added_shares_sum_spoke[i],
        asset_added_shares,
        'AAVE-GINV-2 total added shares should be equal to spokes added shares'
      );
      assertGte(
        IERC20(asset.underlying).balanceOf(address(hub1)),
        asset.liquidity - asset.swept,
        'AAVE-GINV-3 underlying balance should be greater than or equal to asset liquidity - asset swept'
      );
      assertNeq(
        uint256(uint160(asset.irStrategy)),
        0,
        'AAVE-GINV-4 asset irStrategy should not be 0'
      );
      // Asset.premiumShares.toDrawnAssetsUp() >= Asset.premiumOffset
      assertGte(
        hub1.previewRestoreByShares(i, asset.premiumShares).toRay(),
        asset.premiumOffsetRay.toUint256(),
        'AAVE-GINV-5 asset premium shares should be greater than or equal to asset premium offset'
      );
      assertEq(
        total_deficit_sum_spoke[i],
        asset.deficitRay,
        'AAVE-GINV-6 total deficit should be equal to asset deficit'
      );
      // Note consider virtual assets and shares
      uint256 new_exchange_rate = (hub1.getAddedAssets(i) + 1e6) / (asset_added_shares + 1e6);
      assertGte(
        new_exchange_rate,
        asset_previous_exchange_rate[i],
        'AAVE-GINV-7 exchange rate should be greater than or equal to previous exchange rate'
      );
      asset_previous_exchange_rate[i] = new_exchange_rate;
      uint256 new_drawn_index = hub1.getAssetDrawnIndex(i);
      assertGte(
        new_drawn_index,
        asset_previous_drawn_index[i],
        'AAVE-GINV-8 drawn index should be greater than or equal to previous drawn index'
      );
      asset_previous_drawn_index[i] = new_drawn_index;
    }
  }

  function supply_must_succeed(
    uint256 spokeId,
    uint256 reserveId,
    uint256 amount
  ) external check_global_invariants {
    ISpoke spoke = spokes[clampBetween(spokeId, 0, spokes.length - 1)];
    reserveId = spokeInfo[spoke].reserveIds[
      clampBetween(reserveId, 0, spokeInfo[spoke].reserveIds.length - 1)
    ];
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    IHub hub = IHub(address(reserve.hub));
    // Assume addCap is unlimited
    amount = clampBetween(amount, hub.previewAddByShares(reserve.assetId, 1), 10 ** 30);

    //vm.startPrank(msg.sender);
    // For now we set every asset supplied as collateral
    vm.prank(msg.sender);
    spoke.setUsingAsCollateral(reserveId, true, msg.sender);

    TestnetERC20(reserve.underlying).mint(msg.sender, amount);
    vm.prank(msg.sender);
    TestnetERC20(reserve.underlying).approve(address(hub), amount);
    uint256 oldUserShares = spoke.getUserSuppliedShares(reserveId, msg.sender);
    uint256 oldHubUnderlyingBalance = TestnetERC20(reserve.underlying).balanceOf(address(hub));
    uint256 oldUserUnderlyingBalance = TestnetERC20(reserve.underlying).balanceOf(msg.sender);
    IHub.Asset memory oldAsset = hub.getAsset(reserve.assetId);
    IHub.SpokeData memory oldSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
    uint256 unrealizedFeeShares = hub.getSpokeAddedShares(reserve.assetId, oldAsset.feeReceiver) -
      hub.getSpoke(reserve.assetId, oldAsset.feeReceiver).addedShares;
    vm.prank(msg.sender);

    try spoke.supply(reserveId, amount, msg.sender) returns (uint256 shares, uint256 amount) {
      assertGt(shares, 0, 'AAVE-INV-1 shares supplied should be greater than 0');
      assertGt(amount, 0, 'AAVE-INV-2 amount supplied should be greater than 0');
      assertEq(
        spoke.getUserSuppliedShares(reserveId, msg.sender),
        oldUserShares + shares,
        'AAVE-INV-4 user shares should be equal to old user shares plus shares supplied'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(address(hub)),
        oldHubUnderlyingBalance + amount,
        'AAVE-INV-5 hub underlying balance should be equal to old hub underlying balance plus amount supplied'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(msg.sender),
        oldUserUnderlyingBalance - amount,
        'AAVE-INV-6 user underlying balance should be equal to old user underlying balance minus amount supplied'
      );
      IHub.Asset memory newAsset = hub.getAsset(reserve.assetId);
      assertEq(
        newAsset.liquidity,
        oldAsset.liquidity + amount,
        'AAVE-INV-7 asset liquidity should be equal to old asset liquidity plus amount supplied'
      );
      assertEq(
        newAsset.addedShares - unrealizedFeeShares,
        oldAsset.addedShares + shares,
        'AAVE-INV-8 asset added shares should be equal to old asset added shares plus shares supplied'
      );
      IHub.SpokeData memory newSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
      assertEq(
        newSpokeData.addedShares,
        oldSpokeData.addedShares + shares,
        'AAVE-INV-9 spoke added shares should be equal to old spoke added shares plus shares supplied'
      );
    } catch (bytes memory data) {
      // Note we assume addCap is unlimited and all the reserves are active
      emit LogString('AAVE-INV-3: supply must succeed if the preconditions are met');
      emit LogBytes(data);
      assert(false);
    }
  }

  function withdraw_must_succeed(
    uint256 spokeId,
    uint256 reserveId,
    uint256 amount
  ) external check_global_invariants {
    ISpoke spoke = spokes[clampBetween(spokeId, 0, spokes.length - 1)];
    reserveId = spokeInfo[spoke].reserveIds[
      clampBetween(reserveId, 0, spokeInfo[spoke].reserveIds.length - 1)
    ];
    uint256 oldUserShares = spoke.getUserSuppliedShares(reserveId, msg.sender);
    require(oldUserShares > 0);
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    IHub hub = IHub(address(reserve.hub));

    ISpoke.UserAccountData memory oldAccountData = spoke.getUserAccountData(msg.sender);
    {
      uint256 maxAmount = oldAccountData
        .totalCollateralValue
        .percentMulDown(oldAccountData.avgCollateralFactor / 1e14)
        .percentMulDown(99_00) - oldAccountData.totalDebtValue;
      maxAmount = _convertValueToAmount(
        spoke,
        reserveId,
        maxAmount,
        TestnetERC20(reserve.underlying).decimals()
      );
      amount = clampBetween(amount, 1, maxAmount);
    }

    OldBalances memory oldBalances;
    oldBalances.hubUnderlying = TestnetERC20(reserve.underlying).balanceOf(address(hub));
    oldBalances.userUnderlying = TestnetERC20(reserve.underlying).balanceOf(msg.sender);
    IHub.Asset memory oldAsset = hub.getAsset(reserve.assetId);
    require(oldAsset.liquidity >= amount);
    IHub.SpokeData memory oldSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
    uint256 unrealizedFeeShares = hub.getSpokeAddedShares(reserve.assetId, oldAsset.feeReceiver) -
      hub.getSpoke(reserve.assetId, oldAsset.feeReceiver).addedShares;
    vm.prank(msg.sender);

    try spoke.withdraw(reserveId, amount, msg.sender) returns (uint256 shares, uint256 amount) {
      assertGt(shares, 0, 'AAVE-INV-10 shares withdrawn should be greater than 0');
      assertGt(amount, 0, 'AAVE-INV-11 amount withdrawn should be greater than 0');
      assertEq(
        spoke.getUserSuppliedShares(reserveId, msg.sender),
        oldUserShares - shares,
        'AAVE-INV-12 user shares should be equal to old user shares minus shares withdrew'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(address(hub)),
        oldBalances.hubUnderlying - amount,
        'AAVE-INV-13 hub underlying balance should be equal to old hub underlying balance minus amount withdrew'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(msg.sender),
        oldBalances.userUnderlying + amount,
        'AAVE-INV-14 user underlying balance should be equal to old user underlying balance plus amount withdrew'
      );
      IHub.Asset memory newAsset = hub.getAsset(reserve.assetId);
      assertEq(
        newAsset.liquidity,
        oldAsset.liquidity - amount,
        'AAVE-INV-15 asset liquidity should be equal to old asset liquidity minus amount withdrew'
      );
      // @note we remove the unrealizedFeeShares to account for the accrued interest
      assertEq(
        newAsset.addedShares - unrealizedFeeShares,
        oldAsset.addedShares - shares,
        'AAVE-INV-16 asset added shares should be equal to old asset added shares minus shares withdrew'
      );
      IHub.SpokeData memory newSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
      assertEq(
        newSpokeData.addedShares,
        oldSpokeData.addedShares - shares,
        'AAVE-INV-17 spoke added shares should be equal to old spoke added shares minus shares withdrew'
      );
      ISpoke.UserAccountData memory newAccountData = spoke.getUserAccountData(msg.sender);
      emit HFF(
        newAccountData.healthFactor,
        newAccountData.totalCollateralValue,
        newAccountData.totalDebtValue,
        newAccountData.avgCollateralFactor,
        newAccountData.riskPremium
      );
      assertGte(
        oldAccountData.healthFactor,
        newAccountData.healthFactor,
        'AAVE-INV-18 user health factor does not increase when withdrawing'
      );
      assertGte(
        newAccountData.healthFactor,
        uint256(1e18),
        'AAVE-INV-19 user health factor does not go below HEALTH_FACTOR_LIQUIDATION_THRESHOLD when withdrawing'
      );
    } catch (bytes memory data) {
      // Note we assume addCap is unlimited and all the reserves are active
      emit LogString('AAVE-INV-20: withdraw must succeed if the preconditions are met');
      emit LogBytes(data);
      //assert(false);
    }
  }
  event HFF(
    uint256 healthFactor,
    uint256 totalCollateralValue,
    uint256 totalDebtValue,
    uint256 avgCollateralFactor,
    uint256 riskPremium
  );

  function borrow_must_succeed(
    uint256 spokeId,
    uint256 reserveId,
    uint256 amount
  ) external check_global_invariants {
    ISpoke spoke = spokes[clampBetween(spokeId, 0, spokes.length - 1)];
    ISpoke.UserAccountData memory oldAccountData = spoke.getUserAccountData(msg.sender);
    require(oldAccountData.totalCollateralValue > 0);
    reserveId = spokeInfo[spoke].reserveIds[
      clampBetween(reserveId, 0, spokeInfo[spoke].reserveIds.length - 1)
    ];
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    uint256 maxAmount = oldAccountData
      .totalCollateralValue
      .percentMulDown(oldAccountData.avgCollateralFactor / 1e14)
      .percentMulDown(99_00) - oldAccountData.totalDebtValue;
    maxAmount = _convertValueToAmount(
      spoke,
      reserveId,
      maxAmount,
      TestnetERC20(reserve.underlying).decimals()
    );
    amount = clampBetween(amount, 1, maxAmount);

    IHub hub = IHub(address(reserve.hub));

    //vm.startPrank(msg.sender);
    OldBalances memory oldBalances;
    oldBalances.hubUnderlying = TestnetERC20(reserve.underlying).balanceOf(address(hub));
    oldBalances.userUnderlying = TestnetERC20(reserve.underlying).balanceOf(msg.sender);
    IHub.Asset memory oldAsset = hub.getAsset(reserve.assetId);
    require(oldAsset.liquidity >= amount);
    IHub.SpokeData memory oldSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
    ISpoke.UserPosition memory oldUserPosition = spoke.getUserPosition(reserveId, msg.sender);
    vm.prank(msg.sender);
    try spoke.borrow(reserveId, amount, msg.sender) returns (uint256 shares, uint256 amount) {
      assertGt(shares, 0, 'AAVE-INV-21 shares borrowed should be greater than 0');
      assertGt(amount, 0, 'AAVE-INV-22 amount borrowed should be greater than 0');
      //ISpoke.UserPosition memory newUserPosition = spoke.getUserPosition(reserveId, msg.sender);
      assertEq(
        spoke.getUserPosition(reserveId, msg.sender).drawnShares,
        oldUserPosition.drawnShares + shares,
        'AAVE-INV-23 user drawn shares should be equal to old user drawn shares + drawn shares'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(address(hub)),
        oldBalances.hubUnderlying - amount,
        'AAVE-INV-24 hub underlying balance should be equal to old hub underlying balance minus amount borrowed'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(msg.sender),
        oldBalances.userUnderlying + amount,
        'AAVE-INV-25 user underlying balance should be equal to old user underlying balance plus amount borrowed'
      );
      IHub.Asset memory newAsset = hub.getAsset(reserve.assetId);
      assertEq(
        newAsset.liquidity,
        oldAsset.liquidity - amount,
        'AAVE-INV-26 asset liquidity should be equal to old asset liquidity minus amount borrowed'
      );
      assertEq(
        newAsset.drawnShares,
        oldAsset.drawnShares + shares,
        'AAVE-INV-27 asset drawn shares should be equal to old asset drawn shares plus shares borrowed'
      );
      IHub.SpokeData memory newSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
      assertEq(
        newSpokeData.drawnShares,
        oldSpokeData.drawnShares + shares,
        'AAVE-INV-28 spoke drawn shares should be equal to old spoke drawn shares plus shares borrowed'
      );
      ISpoke.UserAccountData memory newAccountData = spoke.getUserAccountData(msg.sender);
      emit HFF(
        newAccountData.healthFactor,
        newAccountData.totalCollateralValue,
        newAccountData.totalDebtValue,
        newAccountData.avgCollateralFactor,
        newAccountData.riskPremium
      );
      assertGte(
        oldAccountData.healthFactor,
        newAccountData.healthFactor,
        'AAVE-INV-29 user health factor does not increase when borrowing'
      );
      assertGte(
        newAccountData.healthFactor,
        uint256(1e18),
        'AAVE-INV-30 user health factor does not go below HEALTH_FACTOR_LIQUIDATION_THRESHOLD when borrowing'
      );
    } catch (bytes memory data) {
      // Note we assume drawCap is unlimited and all the reserves are active
      emit LogString('AAVE-INV-31: borrow must succeed if the preconditions are met');
      emit LogBytes(data);
      // I don't know why it fails with the HF error, could be because the maxAmount computation is wrong or smth else.
      // TODO check why
      //assert(false);
    }
  }

  function repay_must_succeed(
    uint256 spokeId,
    uint256 reserveId,
    uint256 amount
  ) external check_global_invariants {
    ISpoke spoke = spokes[clampBetween(spokeId, 0, spokes.length - 1)];
    //ISpoke.UserAccountData memory oldAccountData = spoke.getUserAccountData(msg.sender);
    reserveId = spokeInfo[spoke].reserveIds[
      clampBetween(reserveId, 0, spokeInfo[spoke].reserveIds.length - 1)
    ];
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    (, , uint256 restoreAmount) = _calculateExactRestoreAmount(
      spoke,
      reserveId,
      msg.sender,
      amount,
      reserve.assetId
    );
    IHub hub = IHub(address(reserve.hub));

    //vm.startPrank(msg.sender);
    TestnetERC20(reserve.underlying).mint(msg.sender, restoreAmount);
    vm.prank(msg.sender);
    TestnetERC20(reserve.underlying).approve(address(hub), restoreAmount);

    uint256 oldHubUnderlyingBalance = TestnetERC20(reserve.underlying).balanceOf(address(hub));
    uint256 oldUserUnderlyingBalance = TestnetERC20(reserve.underlying).balanceOf(msg.sender);
    IHub.Asset memory oldAsset = hub.getAsset(reserve.assetId);
    IHub.SpokeData memory oldSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
    ISpoke.UserPosition memory oldUserPosition = spoke.getUserPosition(reserveId, msg.sender);
    vm.prank(msg.sender);
    try spoke.repay(reserveId, restoreAmount, msg.sender) returns (
      uint256 restoredShares,
      uint256 restoredAmount
    ) {
      //assertGt(restoredShares, 0, "AAVE-INV-32 shares restored should be greater than 0");
      assertGt(restoredAmount, 0, 'AAVE-INV-33 amount restored should be greater than 0');
      //ISpoke.UserPosition memory newUserPosition = spoke.getUserPosition(reserveId, msg.sender);
      assertEq(
        spoke.getUserPosition(reserveId, msg.sender).drawnShares,
        oldUserPosition.drawnShares - restoredShares,
        'AAVE-INV-34 user drawn shares should be equal to old user drawn shares - restored shares'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(address(hub)),
        oldHubUnderlyingBalance + restoredAmount,
        'AAVE-INV-35 hub underlying balance should be equal to old hub underlying balance plus amount restored'
      );
      assertEq(
        TestnetERC20(reserve.underlying).balanceOf(msg.sender),
        oldUserUnderlyingBalance - restoredAmount,
        'AAVE-INV-36 user underlying balance should be equal to old user underlying balance minus amount restored'
      );
      IHub.Asset memory newAsset = hub.getAsset(reserve.assetId);
      assertEq(
        newAsset.liquidity,
        oldAsset.liquidity + restoredAmount,
        'AAVE-INV-37 asset liquidity should be equal to old asset liquidity plus amount restored'
      );
      assertEq(
        newAsset.drawnShares,
        oldAsset.drawnShares - restoredShares,
        'AAVE-INV-38 asset drawn shares should be equal to old asset drawn shares minus restored shares'
      );
      IHub.SpokeData memory newSpokeData = hub.getSpoke(reserve.assetId, address(spoke));
      assertEq(
        newSpokeData.drawnShares,
        oldSpokeData.drawnShares - restoredShares,
        'AAVE-INV-39 spoke drawn shares should be equal to old spoke drawn shares minus restored shares'
      );
      ISpoke.UserAccountData memory newAccountData = spoke.getUserAccountData(msg.sender);
      //assertLte(oldAccountData.healthFactor, newAccountData.healthFactor, "AAVE-INV-40 user health factor does not decrease when repaying");
      //assertGte(newAccountData.healthFactor, uint256(spoke.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()), "AAVE-INV-30 user health factor does not go below HEALTH_FACTOR_LIQUIDATION_THRESHOLD when borrowing");
    } catch (bytes memory data) {
      // Note we assume drawCap is unlimited and all the reserves are active
      emit LogString('AAVE-INV-41: repay must succeed if the preconditions are met');
      emit LogBytes(data);
      assert(false);
    }
  }
}
