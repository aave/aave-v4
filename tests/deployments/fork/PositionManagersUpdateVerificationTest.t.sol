// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Ownable2Step} from 'src/dependencies/openzeppelin/Ownable2Step.sol';

import {
  ChainConfig,
  PositionManagersUpdateUtils
} from 'scripts/utils/PositionManagersUpdateUtils.sol';

/// @title PositionManagersUpdateVerificationTestBase
/// @author Aave Labs
/// @notice Verifies the post-state of a devnet where the Protocol Security Council Safe has
///         ALREADY executed the Position Managers update batch.
/// @dev Skipped unless the devnet RPC is set, so it never breaks CI for anyone without one.
abstract contract PositionManagersUpdateVerificationTestBase is Test {
  /// @dev `ISpokeConfigurator.updatePositionManager(address,address,bool)`.
  bytes4 internal constant UPDATE_PM_SELECTOR = 0x152ef832;

  bool internal devnetAvailable;

  modifier onlyDevnet() {
    vm.skip(!devnetAvailable, string.concat(_devnetEnvVar(), ' not set'));
    _;
  }

  // ─────────────────────── Per-chain hooks ───────────────────────

  function _chainConfig() internal pure virtual returns (ChainConfig memory);

  /// @dev Env var holding the Tenderly devnet RPC for this chain. One devnet per chain.
  function _devnetEnvVar() internal pure virtual returns (string memory);

  /// @dev All five currently deployed Position Managers.
  function _allPreviousPms() internal pure virtual returns (address[] memory);

  function setUp() public virtual {
    string memory rpc = vm.envOr(_devnetEnvVar(), string(''));
    if (bytes(rpc).length == 0) return;

    vm.createSelectFork(rpc);
    devnetAvailable = true;

    // Guards against pointing at the wrong devnet.
    assertEq(block.chainid, _chainConfig().chainId, 'devnet is on the wrong chain');
  }

  // ─────────────────────── Batch preconditions ───────────────────────

  /// @notice The deployed Position Managers are owned by the Safe.
  function test_newPositionManagers_ownedBySafe() public onlyDevnet {
    ChainConfig memory cfg = _chainConfig();
    address[] memory newPms = cfg.newPms;

    for (uint256 i; i < newPms.length; ++i) {
      assertGt(newPms[i].code.length, 0, 'new position manager has no code');
      assertEq(
        Ownable2Step(newPms[i]).owner(),
        PositionManagersUpdateUtils.PROTOCOL_SECURITY_COUNCIL,
        'new position manager is not owned by the Safe'
      );
      assertEq(
        Ownable2Step(newPms[i]).pendingOwner(),
        address(0),
        'an ownership transfer is pending on a new position manager'
      );
      assertNotEq(newPms[i], cfg.oldPms[i], 'new address equals the old one');
    }
  }

  /// @notice On Avalanche the batch grants the Safe role 400, as it needs it to configure the Spokes. We test that after the batch in all the chains the Safe have the 400 role.
  function test_batchWasExecuted_safeCanConfigureSpokes() public onlyDevnet {
    ChainConfig memory cfg = _chainConfig();
    IAccessManager am = IAccessManager(cfg.accessManager);

    (bool canCall, uint32 delay) = am.canCall(
      PositionManagersUpdateUtils.PROTOCOL_SECURITY_COUNCIL,
      cfg.spokeConfigurator,
      UPDATE_PM_SELECTOR
    );
    assertTrue(canCall, 'the Safe cannot configure spokes after the batch');
    assertEq(delay, 0, 'the Safe ended up with an execution delay');

    (bool isMember, uint32 memberDelay) = am.hasRole(
      PositionManagersUpdateUtils.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      PositionManagersUpdateUtils.PROTOCOL_SECURITY_COUNCIL
    );
    assertTrue(isMember, 'the Safe does not hold role 400');
    assertEq(memberDelay, 0, 'role 400 carries an execution delay');
  }

  function _contains(address[] memory haystack, address needle) private pure returns (bool) {
    for (uint256 i; i < haystack.length; ++i) if (haystack[i] == needle) return true;
    return false;
  }

  // ─────────────────────── Batch outcome ───────────────────────

  /// @notice Both sides of the handshake are set for the new Position Managers on every Spoke.
  function test_batchWasExecuted_handshakeIsComplete() public onlyDevnet {
    ChainConfig memory cfg = _chainConfig();
    address[] memory newPms = cfg.newPms;

    for (uint256 s; s < cfg.spokes.length; ++s) {
      for (uint256 p; p < newPms.length; ++p) {
        assertTrue(
          ISpoke(cfg.spokes[s]).isPositionManagerActive(newPms[p]),
          string.concat('new PM not active on ', cfg.spokeNames[s])
        );
        assertTrue(
          IPositionManagerBase(newPms[p]).isSpokeRegistered(cfg.spokes[s]),
          string.concat('new PM not registered on ', cfg.spokeNames[s])
        );
      }
    }
  }

  /// @notice The two replaced Position Managers are off on both sides.
  /// @dev Their per-user approvals survive in the Spoke's storage but are inert while `active` is
  ///      false. Clearing those would need `renouncePositionManagerRole` per user, which does not
  ///      scale and is out of scope here.
  function test_batchWasExecuted_replacedPositionManagersAreOff() public onlyDevnet {
    ChainConfig memory cfg = _chainConfig();

    for (uint256 s; s < cfg.spokes.length; ++s) {
      for (uint256 p; p < cfg.oldPms.length; ++p) {
        assertFalse(
          ISpoke(cfg.spokes[s]).isPositionManagerActive(cfg.oldPms[p]),
          string.concat('old PM still active on ', cfg.spokeNames[s])
        );
        assertFalse(
          IPositionManagerBase(cfg.oldPms[p]).isSpokeRegistered(cfg.spokes[s]),
          string.concat('old PM still registered on ', cfg.spokeNames[s])
        );
      }
    }
  }

  /// @notice The three Position Managers that keep their address are untouched.
  /// @dev Giver, NativeTokenGateway and SignatureGateway are byte-identical between v0.5.11 and
  ///      main, so they must not appear in the batch at all. This is the scope check.
  function test_batchWasExecuted_unchangedPositionManagersAreUntouched() public onlyDevnet {
    ChainConfig memory cfg = _chainConfig();
    address[] memory all = _allPreviousPms();

    for (uint256 s; s < cfg.spokes.length; ++s) {
      for (uint256 a; a < all.length; ++a) {
        if (_contains(cfg.oldPms, all[a])) continue;
        assertTrue(
          ISpoke(cfg.spokes[s]).isPositionManagerActive(all[a]),
          string.concat('an unchanged PM was deactivated on ', cfg.spokeNames[s])
        );
        assertTrue(
          IPositionManagerBase(all[a]).isSpokeRegistered(cfg.spokes[s]),
          string.concat('an unchanged PM was deregistered on ', cfg.spokeNames[s])
        );
      }
    }
  }
}

/// @notice Ethereum devnet.
/// @dev TENDERLY_DEVNET_RPC_MAINNET=… forge test --match-contract PositionManagersUpdateVerificationEthereumTest -vv
contract PositionManagersUpdateVerificationEthereumTest is
  PositionManagersUpdateVerificationTestBase
{
  function _chainConfig() internal pure override returns (ChainConfig memory) {
    return PositionManagersUpdateUtils.ethereum();
  }

  function _devnetEnvVar() internal pure override returns (string memory) {
    return 'TENDERLY_DEVNET_RPC_MAINNET';
  }

  function _allPreviousPms() internal pure override returns (address[] memory pms) {
    pms = new address[](5);
    pms[0] = 0x17A54b8d6D9C68e7fa1C7112AC998EA1BA51d11e; // GIVER_POSITION_MANAGER
    pms[1] = 0x6c044c0D3801499bCAbfAd458B70880bc518e9F7; // TAKER_POSITION_MANAGER
    pms[2] = 0x51305839CE822a7b4b12AA7D86eA7005052d575c; // CONFIG_POSITION_MANAGER
    pms[3] = 0xe68ab4F90Fe026B9873F5F276eD2d7efBbbE42Be; // NATIVE_TOKEN_GATEWAY
    pms[4] = 0xfbC184337Dc6595D8bf62968Bda46e7De7AF9c3d; // SIGNATURE_GATEWAY
  }
}

/// @notice Avalanche devnet. The batch here also grants the Safe role 400 as its first action.
/// @dev TENDERLY_DEVNET_RPC_AVALANCHE=… forge test --match-contract PositionManagersUpdateVerificationAvalancheTest -vv
contract PositionManagersUpdateVerificationAvalancheTest is
  PositionManagersUpdateVerificationTestBase
{
  function _chainConfig() internal pure override returns (ChainConfig memory) {
    return PositionManagersUpdateUtils.avalanche();
  }

  function _devnetEnvVar() internal pure override returns (string memory) {
    return 'TENDERLY_DEVNET_RPC_AVALANCHE';
  }

  function _allPreviousPms() internal pure override returns (address[] memory pms) {
    pms = new address[](5);
    pms[0] = 0x50c4C40aB6BaE46B372a251BEacE388439aa96b4; // GIVER_POSITION_MANAGER
    pms[1] = 0x5A5A711560eb9293Ef6F4bc33CD8589b4A603D10; // TAKER_POSITION_MANAGER
    pms[2] = 0x50BE00C5EbF6CC230B8970f4205Cd0B5A70EaEB1; // CONFIG_POSITION_MANAGER
    pms[3] = 0xE4C7183A5f22c365140F41d733d8A8baD5A1a6bA; // NATIVE_TOKEN_GATEWAY
    pms[4] = 0x6E3B91A951DA9b515a5E98F0c7D210a697382e7F; // SIGNATURE_GATEWAY
  }
}
