// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {console2 as console} from 'forge-std/console2.sol';

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Ownable2Step} from 'src/dependencies/openzeppelin/Ownable2Step.sol';

import {
  ChainConfig,
  PositionManagersUpdateUtils
} from 'scripts/utils/PositionManagersUpdateUtils.sol';

/// @title PositionManagersUpdateTestBase
/// @author Aave Labs
/// @notice Simulates the Position Managers update batch on a mainnet fork, BEFORE it is signed.
///
/// @dev Executes exactly the action list that `PositionManagersUpdateJson.s.sol` emits, pranked as
///      the Protocol Security Council Safe, and asserts the resulting handshake flags. The two
///      artifacts share `PositionManagersUpdateUtils.buildActions`, so the file that gets signed
///      is the one these tests exercised.
abstract contract PositionManagersUpdateTestBase is Test {
  /// @dev `ISpokeConfigurator.updatePositionManager(address,address,bool)`.
  bytes4 internal constant UPDATE_PM_SELECTOR = 0x152ef832;

  address internal user = makeAddr('USER');
  address internal attacker = makeAddr('ATTACKER');

  /// @dev Resolved new Position Manager addresses: the real ones if set, otherwise the mocks.
  address[] internal newPms;

  // ─────────────────────── Per-chain hooks ───────────────────────

  function _chainConfig() internal pure virtual returns (ChainConfig memory);

  /// @dev `rpc_endpoints` alias in foundry.toml.
  function _rpcAlias() internal pure virtual returns (string memory);

  /// @dev All five currently deployed Position Managers.
  function _allCurrentPms() internal pure virtual returns (address[] memory);

  /// @dev The Aave Labs Executor on this chain.
  function _labsExecutor() internal pure virtual returns (address);

  /// @dev Uses mocks for the PMs if the new addresses are not yet included in the PositonManagersUpdateUtils config.
  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl(_rpcAlias()));

    ChainConfig memory cfg = _chainConfig();
    for (uint256 i; i < cfg.newPms.length; ++i) {
      if (cfg.newPms[i] == address(0)) {
        address mock = makeAddr(string.concat('NEW_PM_', vm.toString(i)));
        _installMockPositionManager({target: mock, template: cfg.oldPms[i]});
        newPms.push(mock);
      } else {
        newPms.push(cfg.newPms[i]);
      }
    }
  }

  /// @notice Used to mock the new PMs when not deployed yet using forge cheatcode `vm.etch` and `vm.store`.
  function _installMockPositionManager(address target, address template) internal {
    vm.etch(target, template.code);
    vm.store(
      target,
      bytes32(0),
      bytes32(uint256(uint160(PositionManagersUpdateUtils.PROTOCOL_SECURITY_COUNCIL)))
    );
    assertEq(
      Ownable2Step(target).owner(),
      PositionManagersUpdateUtils.PROTOCOL_SECURITY_COUNCIL,
      'mock position manager: owner not set'
    );
  }

  /// @dev The chain config with the resolved (real or mocked) new addresses.
  function _cfg() internal view returns (ChainConfig memory cfg) {
    cfg = _chainConfig();
    cfg.newPms = newPms;
  }

  /// @dev Runs the batch exactly as the Safe will: sequential calls, one sender, one transaction.
  function _executeBatch() internal {
    PositionManagersUpdateUtils.Action[] memory actions = PositionManagersUpdateUtils.buildActions(
      _cfg()
    );

    vm.startPrank(PositionManagersUpdateUtils.PROTOCOL_SECURITY_COUNCIL);
    for (uint256 i; i < actions.length; ++i) {
      (bool ok, bytes memory ret) = actions[i].to.call(actions[i].data);
      if (!ok) {
        console.log('batch failed at action [%s], target %s', i, actions[i].to);
        revert(string(ret));
      }
    }
    vm.stopPrank();
  }

  // ───────────────── Preconditions: no batch executed ─────────────────

  /// @notice Nobody but the Safe can run either half of the batch.
  function test_batch_revertsForUnauthorizedCaller() public {
    ChainConfig memory cfg = _cfg();

    vm.prank(attacker);
    vm.expectRevert();
    IPositionManagerBase(cfg.newPms[0]).registerSpoke(cfg.spokes[0], true);

    vm.prank(attacker);
    vm.expectRevert();
    ISpokeConfigurator(cfg.spokeConfigurator).updatePositionManager(
      cfg.spokes[0],
      cfg.newPms[0],
      true
    );
  }

  /// @notice The Safe owns every Position Manager, so it can do the `registerSpoke` half.
  function test_preconditions_safeOwnsPositionManagers() public view {
    address[] memory pms = _allCurrentPms();
    for (uint256 i; i < pms.length; ++i) {
      assertEq(
        Ownable2Step(pms[i]).owner(),
        PositionManagersUpdateUtils.PROTOCOL_SECURITY_COUNCIL,
        'position manager owner is not the Safe'
      );
      assertEq(Ownable2Step(pms[i]).pendingOwner(), address(0), 'an ownership transfer is pending');
    }
  }

  /// @notice Demonstrate why we need to run the batch in the Safe's context and not use the Labs Executor.
  /// @dev The Labs Executor holds role 400 but is not the Position Manager owner, so a payload
  ///      running in the Executor's context would revert on every `registerSpoke`.
  function test_preconditions_executorCannotRegisterSpokes() public view {
    ChainConfig memory cfg = _chainConfig();
    for (uint256 i; i < cfg.oldPms.length; ++i) {
      assertNotEq(
        Ownable2Step(cfg.oldPms[i]).owner(),
        _labsExecutor(),
        'the Executor owns the position managers: reconsider the payload route'
      );
    }
  }

  /// @notice The Safe can reach the Spoke side, either already or via the grant in the batch.
  function test_preconditions_safeCanConfigureSpokes() public view {
    ChainConfig memory cfg = _chainConfig();
    IAccessManager am = IAccessManager(cfg.accessManager);

    (bool canCall, uint32 delay) = am.canCall(
      PositionManagersUpdateUtils.PROTOCOL_SECURITY_COUNCIL,
      cfg.spokeConfigurator,
      UPDATE_PM_SELECTOR
    );

    if (cfg.grantRole400ToSafe) {
      // The batch grants the role to itself as action [0]. That only works because the role's
      // grant delay is zero, so the membership is live for the calls that follow in the same
      // transaction. If someone sets a delay later, this assert goes red instead of the batch
      // reverting on-chain with signatures already collected.
      assertFalse(canCall, 'grantRole400ToSafe is set but the Safe already has the role');
      assertEq(
        am.getRoleGrantDelay(PositionManagersUpdateUtils.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE),
        0,
        'role 400 has a grant delay: the batch cannot be atomic'
      );
      (bool isAdmin, uint32 adminDelay) = am.hasRole(
        0,
        PositionManagersUpdateUtils.PROTOCOL_SECURITY_COUNCIL
      );
      assertTrue(isAdmin, 'the Safe cannot grant itself role 400');
      assertEq(adminDelay, 0, 'the Safe has an execution delay on the admin role');
      assertEq(
        am.getRoleAdmin(PositionManagersUpdateUtils.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE),
        0,
        'role 400 is not administered by the admin role'
      );
    } else {
      assertTrue(canCall, 'the Safe cannot call SpokeConfigurator.updatePositionManager');
      assertEq(delay, 0, 'the Safe has an execution delay: the batch would not be immediate');
    }
  }

  /// @notice Baseline to preserve: every current Position Manager is wired on every Spoke.
  function test_preconditions_currentWiringIsSymmetric() public view {
    ChainConfig memory cfg = _chainConfig();
    address[] memory pms = _allCurrentPms();

    for (uint256 s; s < cfg.spokes.length; ++s) {
      for (uint256 p; p < pms.length; ++p) {
        assertTrue(
          ISpoke(cfg.spokes[s]).isPositionManagerActive(pms[p]),
          string.concat('Spoke side not active on ', cfg.spokeNames[s])
        );
        assertTrue(
          IPositionManagerBase(pms[p]).isSpokeRegistered(cfg.spokes[s]),
          string.concat('PM side not registered on ', cfg.spokeNames[s])
        );
      }
    }
  }

  /// @notice The new Position Managers start completely unwired.
  function test_preconditions_newPositionManagersAreUnwired() public view {
    ChainConfig memory cfg = _cfg();
    for (uint256 s; s < cfg.spokes.length; ++s) {
      for (uint256 p; p < cfg.newPms.length; ++p) {
        assertFalse(ISpoke(cfg.spokes[s]).isPositionManagerActive(cfg.newPms[p]));
        assertFalse(IPositionManagerBase(cfg.newPms[p]).isSpokeRegistered(cfg.spokes[s]));
      }
    }
  }

  // ───────────────────────── After the batch ─────────────────────────

  /// @notice Both sides of the handshake are set for every new Position Manager on every Spoke.
  function test_batch_handshakeIsComplete() public {
    _executeBatch();

    ChainConfig memory cfg = _cfg();
    uint256 pairs;
    for (uint256 s; s < cfg.spokes.length; ++s) {
      for (uint256 p; p < cfg.newPms.length; ++p) {
        assertTrue(
          ISpoke(cfg.spokes[s]).isPositionManagerActive(cfg.newPms[p]),
          string.concat('new PM inactive on ', cfg.spokeNames[s])
        );
        assertTrue(
          IPositionManagerBase(cfg.newPms[p]).isSpokeRegistered(cfg.spokes[s]),
          string.concat('new PM unregistered on ', cfg.spokeNames[s])
        );
        ++pairs;
      }
    }
    assertEq(pairs, cfg.spokes.length * cfg.newPms.length, 'unexpected pair count');
  }

  /// @notice The two replaced Position Managers are off on both sides.
  function test_batch_replacedPositionManagersAreOff() public {
    _executeBatch();

    ChainConfig memory cfg = _cfg();
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

  /// @notice The three Position Managers that do not change are untouched.
  /// @dev Giver, NativeTokenGateway and SignatureGateway are byte-identical between v0.5.11 and
  ///      main, so they keep their CREATE2 address and must not appear in the batch at all.
  function test_batch_unchangedPositionManagersAreUntouched() public {
    _executeBatch();

    ChainConfig memory cfg = _cfg();
    address[] memory all = _allCurrentPms();

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

  /// @notice On chains that need it, the batch leaves the Safe holding role 400.
  function test_batch_roleGrantOutcome() public {
    ChainConfig memory cfg = _chainConfig();
    _executeBatch();

    (bool canCall, ) = IAccessManager(cfg.accessManager).canCall(
      PositionManagersUpdateUtils.PROTOCOL_SECURITY_COUNCIL,
      cfg.spokeConfigurator,
      UPDATE_PM_SELECTOR
    );
    assertTrue(canCall, 'the Safe should be able to configure spokes after the batch');
  }

  /// @notice Re-running the batch changes nothing.
  /// @dev Matters because a Safe transaction can be re-proposed or retried.
  function test_batch_isIdempotent() public {
    _executeBatch();
    _executeBatch();

    ChainConfig memory cfg = _cfg();
    assertTrue(ISpoke(cfg.spokes[0]).isPositionManagerActive(cfg.newPms[0]));
    assertTrue(IPositionManagerBase(cfg.newPms[0]).isSpokeRegistered(cfg.spokes[0]));
    assertFalse(ISpoke(cfg.spokes[0]).isPositionManagerActive(cfg.oldPms[0]));
  }

  /// @notice Prints the batch for eyeball review.
  function test_logBatch() public view {
    PositionManagersUpdateUtils.Action[] memory actions = PositionManagersUpdateUtils.buildActions(
      _cfg()
    );
    console.log('chain %s: %s actions', block.chainid, actions.length);
    for (uint256 i; i < actions.length; ++i) {
      console.log('  [%s] target %s', i, actions[i].to);
    }
  }

  function _contains(address[] memory haystack, address needle) private pure returns (bool) {
    for (uint256 i; i < haystack.length; ++i) if (haystack[i] == needle) return true;
    return false;
  }
}

/// @notice Ethereum. 10 Spokes x 2 Position Managers x 4 changes = 80 actions, no role grant.
/// @dev forge test --match-contract PositionManagersUpdateEthereumTest -vv
contract PositionManagersUpdateEthereumTest is PositionManagersUpdateTestBase {
  function _chainConfig() internal pure override returns (ChainConfig memory) {
    return PositionManagersUpdateUtils.ethereum();
  }

  function _rpcAlias() internal pure override returns (string memory) {
    return 'mainnet';
  }

  function _allCurrentPms() internal pure override returns (address[] memory pms) {
    pms = new address[](5);
    pms[0] = 0x17A54b8d6D9C68e7fa1C7112AC998EA1BA51d11e; // GIVER_POSITION_MANAGER
    pms[1] = 0x6c044c0D3801499bCAbfAd458B70880bc518e9F7; // TAKER_POSITION_MANAGER
    pms[2] = 0x51305839CE822a7b4b12AA7D86eA7005052d575c; // CONFIG_POSITION_MANAGER
    pms[3] = 0xe68ab4F90Fe026B9873F5F276eD2d7efBbbE42Be; // NATIVE_TOKEN_GATEWAY
    pms[4] = 0xfbC184337Dc6595D8bf62968Bda46e7De7AF9c3d; // SIGNATURE_GATEWAY
  }

  function _labsExecutor() internal pure override returns (address) {
    return 0x14339e2178A954d5FB839D5Ff31644fE0F25F517;
  }
}

/// @notice Avalanche. 1 role grant + 3 Spokes x 2 Position Managers x 4 changes = 25 actions.
/// @dev forge test --match-contract PositionManagersUpdateAvalancheTest -vv
contract PositionManagersUpdateAvalancheTest is PositionManagersUpdateTestBase {
  function _chainConfig() internal pure override returns (ChainConfig memory) {
    return PositionManagersUpdateUtils.avalanche();
  }

  function _rpcAlias() internal pure override returns (string memory) {
    return 'avalanche';
  }

  function _allCurrentPms() internal pure override returns (address[] memory pms) {
    pms = new address[](5);
    pms[0] = 0x50c4C40aB6BaE46B372a251BEacE388439aa96b4; // GIVER_POSITION_MANAGER
    pms[1] = 0x5A5A711560eb9293Ef6F4bc33CD8589b4A603D10; // TAKER_POSITION_MANAGER
    pms[2] = 0x50BE00C5EbF6CC230B8970f4205Cd0B5A70EaEB1; // CONFIG_POSITION_MANAGER
    pms[3] = 0xE4C7183A5f22c365140F41d733d8A8baD5A1a6bA; // NATIVE_TOKEN_GATEWAY
    pms[4] = 0x6E3B91A951DA9b515a5E98F0c7D210a697382e7F; // SIGNATURE_GATEWAY
  }

  function _labsExecutor() internal pure override returns (address) {
    return 0xb619fA61e795D47f517702e63ce50292370561F1;
  }
}
