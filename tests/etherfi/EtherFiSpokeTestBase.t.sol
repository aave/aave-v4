// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';

import 'tests/setup/Base.t.sol';

import {MockEtherFiDataProvider} from 'tests/helpers/mocks/MockEtherFiDataProvider.sol';

/// @dev Shared plumbing for re-targeting the standard test environment at EtherFiSpokeInstance:
/// deploys every spoke from the ether.fi bytecode and etches a MockEtherFiDataProvider at the
/// provider address hardcoded in the instance. The mock defaults to `allSafe = true`, which makes
/// the borrow gate transparent — so any existing Base-derived suite re-run through this hook must
/// pass unchanged, proving the gate does not alter the rest of the Spoke behavior. Gate-specific
/// (restricted) scenarios flip the mock to deny mode; see EtherFiSpokeGate.t.sol.
library EtherFiSpokeTestHelpers {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @dev Mirrors EtherFiSpokeInstance.ETHERFI_DATA_PROVIDER; the gate suite asserts they match.
  /// Kept as a local constant (and the instance loaded via vm.getCode) so this file does NOT
  /// import EtherFiSpokeInstance.sol: that file carries a via_ir compiler profile in foundry.toml,
  /// and importing it here would drag every re-run stock suite into the via_ir job (stack-too-deep
  /// on suites that only compile with the default pipeline).
  address internal constant ETHERFI_DATA_PROVIDER = 0xDC515Cb479a64552c5A11a57109C314E40A1A778;

  /// @dev Drop-in override body for Base._spokeBytecode().
  function spokeBytecode() internal returns (bytes memory) {
    if (ETHERFI_DATA_PROVIDER.code.length == 0) {
      vm.etch(ETHERFI_DATA_PROVIDER, address(new MockEtherFiDataProvider()).code);
      vm.label(ETHERFI_DATA_PROVIDER, 'etherFiDataProvider');
      MockEtherFiDataProvider(ETHERFI_DATA_PROVIDER).setAllSafe(true);
    }
    return BytecodeHelper.getEtherFiSpokeBytecode();
  }
}

/// @dev Base for ether.fi-specific suites (single inheritance chain on top of Base). Suite reruns
/// of existing Base-derived tests cannot use this mixin (diamond setUp conflicts) and instead
/// override `_spokeBytecode()` directly; see EtherFiSpokeSuiteRerun.t.sol.
abstract contract EtherFiSpokeTestBase is Base {
  MockEtherFiDataProvider internal etherFiDataProvider =
    MockEtherFiDataProvider(EtherFiSpokeTestHelpers.ETHERFI_DATA_PROVIDER);

  function _spokeBytecode() internal override returns (bytes memory) {
    return EtherFiSpokeTestHelpers.spokeBytecode();
  }
}
