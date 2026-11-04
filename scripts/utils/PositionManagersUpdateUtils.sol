// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';

/// @notice Per-chain inputs for the Position Managers update batch.
/// @notice We only need to update TAKER_POSITION_MANAGER and CONFIG_POSITION_MANAGER across all the spokes in Ethereum and Avalanche.
/// @dev chainId Expected chain, asserted before emitting or executing anything.
/// @dev accessManager The AccessManager governing the SpokeConfigurator.
/// @dev spokeConfigurator Entry point for the Spoke side of the handshake.
/// @dev spokes The Spokes that carry position managers.
/// @dev spokeNames Labels parallel to `spokes`, used only for logs and for JSON review.
/// @dev oldPms The Position Managers being replaced.
/// @dev newPms Their replacements, in the SAME order as `oldPms`.
/// @dev grantRole400ToSafe Whether the batch must first grant the Safe the
///      SpokeConfigurator domain admin role. Needed in the case of avalanche and the Safe not having the 400 role`.
struct ChainConfig {
  uint256 chainId;
  address accessManager;
  address spokeConfigurator;
  address[] spokes;
  string[] spokeNames;
  address[] oldPms;
  address[] newPms;
  bool grantRole400ToSafe;
}

/// @title PositionManagersUpdateUtils
/// @author Aave Labs
/// @notice The single source of truth for the Position Managers update batch, executed
///         directly by the Protocol Security Council Safe.
///
/// @dev There is no payload and no Executor involved. `registerSpoke` is `onlyOwner` on the
///      Position Manager and the Safe is that owner, while the Labs Executor is not — so the
///      PM half of the handshake cannot be routed through a payload. The Safe does the whole
///      batch itself in one MultiSend.
///
/// @dev The same `buildActions` output feeds two consumers:
///        1. the tests, which execute it with `vm.prank(PROTOCOL_SECURITY_COUNCIL)` and assert the resulting flags
///        2. the JSON generator, which emits it for the Safe Transaction Builder
///      Managing to test exactly the same paylaod that is generated and imported into the Safe.
library PositionManagersUpdateUtils {
  /// @notice Thrown when two arrays that have to line up by index do not.
  error LengthMismatch(uint256 expected, uint256 actual);

  address internal constant PROTOCOL_SECURITY_COUNCIL = 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9;

  uint64 internal constant SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE = 400;

  /// @param to Target contract of the call.
  /// @param data Calldata. The only description of the action there is: the JSON generator
  ///        decodes it to render the human-readable form, so nothing can drift out of sync.
  struct Action {
    address to;
    bytes data;
  }

  // ───────────────────────────── Ethereum ───────────────────────────── //

  /// @dev The Safe already holds role 400 here (canCall == true, delay 0), so no grant is
  ///      needed. 10 Spokes x 2 Position Managers x 4 changes = 80 actions.
  function ethereum() internal pure returns (ChainConfig memory cfg) {
    address[] memory spokes = new address[](10);
    string[] memory names = new string[](10);

    spokes[0] = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
    names[0] = 'MAIN_SPOKE';

    spokes[1] = 0x973a023A77420ba610f06b3858aD991Df6d85A08;
    names[1] = 'BLUECHIP_SPOKE';

    spokes[2] = 0x58131E79531caB1d52301228d1f7b842F26B9649;
    names[2] = 'ETHENA_CORRELATED_SPOKE';

    spokes[3] = 0xba1B3D55D249692b669A164024A838309B7508AF;
    names[3] = 'ETHENA_ECOSYSTEM_SPOKE';

    spokes[4] = 0xD8B93635b8C6d0fF98CbE90b5988E3F2d1Cd9da1;
    names[4] = 'FOREX_SPOKE';

    spokes[5] = 0x65407b940966954b23dfA3caA5C0702bB42984DC;
    names[5] = 'GOLD_SPOKE';

    spokes[6] = 0x7EC68b5695e803e98a21a9A05d744F28b0a7753D;
    names[6] = 'LOMBARD_BTC_SPOKE';

    spokes[7] = 0xbF10BDfE177dE0336aFD7fcCF80A904E15386219;
    names[7] = 'ETHERFI_ESPOKE';

    spokes[8] = 0x3131FE68C4722e726fe6B2819ED68e514395B9a4;
    names[8] = 'KELP_ESPOKE';

    spokes[9] = 0xe1900480ac69f0B296841Cd01cC37546d92F35Cd;
    names[9] = 'LIDO_ESPOKE';

    address[] memory oldPms = new address[](2);
    oldPms[0] = 0x6c044c0D3801499bCAbfAd458B70880bc518e9F7; // TAKER_POSITION_MANAGER
    oldPms[1] = 0x51305839CE822a7b4b12AA7D86eA7005052d575c; // CONFIG_POSITION_MANAGER

    // TODO: fill in once the new Position Managers
    address[] memory newPms = new address[](2);
    newPms[0] = address(0); // NEW_TAKER_POSITION_MANAGER
    newPms[1] = address(0); // NEW_CONFIG_POSITION_MANAGER

    return
      ChainConfig({
        chainId: 1,
        accessManager: 0x08aE3BE30958cDd1847ec58fFfd4C451a87fDF01,
        spokeConfigurator: 0x9BFFf48BFb5A7AE70c348d4d4cb97E8DEFa5389a,
        spokes: spokes,
        spokeNames: names,
        oldPms: oldPms,
        newPms: newPms,
        grantRole400ToSafe: false
      });
  }

  // ──────────────────────────── Avalanche ────────────────────────────

  /// @dev The Safe does hold role 0 but not role 400.
  ///      Role 0 gives the hability to grant the role to itself as the first
  ///      action of the very same batch and the following calls already see it.
  ///      3 Spokes x 2 Position Managers x 4 changes + 1 grant = 25 actions.
  function avalanche() internal pure returns (ChainConfig memory cfg) {
    address[] memory spokes = new address[](3);
    string[] memory names = new string[](3);

    spokes[0] = 0x435272CefF93a1E657E8ABfdf0A13e95900A3a56;
    names[0] = 'MAIN_SPOKE';

    spokes[1] = 0x6a37776B5E026dBdF043b4F933c323C84DD1B514;
    names[1] = 'FOREX_SPOKE';

    spokes[2] = 0x3b517594277c67307CF2d7CBE6FE1D4399B68c41;
    names[2] = 'AVAX_CORRELATED_SPOKE';

    address[] memory oldPms = new address[](2);
    oldPms[0] = 0x5A5A711560eb9293Ef6F4bc33CD8589b4A603D10; // TAKER_POSITION_MANAGER
    oldPms[1] = 0x50BE00C5EbF6CC230B8970f4205Cd0B5A70EaEB1; // CONFIG_POSITION_MANAGER

    // TODO: fill in once the new Position Managers
    address[] memory newPms = new address[](2);
    newPms[0] = address(0); // NEW_TAKER_POSITION_MANAGER
    newPms[1] = address(0); // NEW_CONFIG_POSITION_MANAGER

    return
      ChainConfig({
        chainId: 43114,
        accessManager: 0xe069096bDAfF9bAD15b2f1079EaF0f1685a24522,
        spokeConfigurator: 0x8F72573F1Aa0A1e39fFD2a2A69e9EDAa8B982642,
        spokes: spokes,
        spokeNames: names,
        oldPms: oldPms,
        newPms: newPms,
        grantRole400ToSafe: true
      });
  }

  // ───────────────────────────── The batch ─────────────────────────────

  /// @notice Builds the full batch for a chain.
  /// @dev Four changes, in this order:
  ///        1. Spoke side  — deactivate the old  (`updatePositionManager(spoke, old, false)`)
  ///        2. PM side     — deregister the old  (`old.registerSpoke(spoke, false)`)
  ///        3. Spoke side  — activate the new    (`updatePositionManager(spoke, new, true)`)
  ///        4. PM side     — register the new    (`new.registerSpoke(spoke, true)`)
  /// @param cfg The chain to build for.
  /// @return actions The ordered action list.
  function buildActions(ChainConfig memory cfg) internal pure returns (Action[] memory actions) {
    require(
      cfg.spokes.length == cfg.spokeNames.length,
      LengthMismatch(cfg.spokes.length, cfg.spokeNames.length)
    );
    require(
      cfg.oldPms.length == cfg.newPms.length,
      LengthMismatch(cfg.oldPms.length, cfg.newPms.length)
    );

    uint256 grantCount = cfg.grantRole400ToSafe ? 1 : 0;
    actions = new Action[](grantCount + cfg.spokes.length * cfg.oldPms.length * 4);
    uint256 i;

    // Must come first: every `updatePositionManager` below is `restricted` and would revert
    // without the role. Safe inside the same transaction because the role's grant delay is
    // zero, so the membership is effective immediately for the following calls.
    if (cfg.grantRole400ToSafe) {
      actions[i++] = Action({
        to: cfg.accessManager,
        data: abi.encodeCall(
          IAccessManager.grantRole,
          (SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, PROTOCOL_SECURITY_COUNCIL, 0)
        )
      });
    }

    for (uint256 s; s < cfg.spokes.length; ++s) {
      for (uint256 p; p < cfg.oldPms.length; ++p) {
        actions[i++] = Action({
          to: cfg.spokeConfigurator,
          data: abi.encodeCall(
            ISpokeConfigurator.updatePositionManager,
            (cfg.spokes[s], cfg.oldPms[p], false)
          )
        });

        actions[i++] = Action({
          to: cfg.oldPms[p],
          data: abi.encodeCall(IPositionManagerBase.registerSpoke, (cfg.spokes[s], false))
        });

        actions[i++] = Action({
          to: cfg.spokeConfigurator,
          data: abi.encodeCall(
            ISpokeConfigurator.updatePositionManager,
            (cfg.spokes[s], cfg.newPms[p], true)
          )
        });

        actions[i++] = Action({
          to: cfg.newPms[p],
          data: abi.encodeCall(IPositionManagerBase.registerSpoke, (cfg.spokes[s], true))
        });
      }
    }
  }
}
