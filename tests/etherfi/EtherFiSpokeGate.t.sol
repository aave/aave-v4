// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {EtherFiSpokeInstance} from 'src/etherfi/EtherFiSpokeInstance.sol';

contract MockOracle {
  function decimals() external pure returns (uint8) {
    return 8;
  }
}

/// @dev Verifies the borrow gate against the LIVE EtherFiDataProvider on an OP Mainnet fork: a
/// non-safe onBehalfOf is rejected with OnlyEtherFiSafe BEFORE any Spoke logic runs; a recognized
/// safe passes the gate and proceeds into the parent borrow (which then reverts Unauthorized for
/// lack of a position manager — proving the gate is pass-through, not a wall). Skips itself unless
/// running against chainid 10:
///   forge test --match-path tests/etherfi/EtherFiSpokeGate.t.sol --fork-url <op-rpc> -vv
contract EtherFiSpokeGateTest is Test {
  function test_fork_borrowGate() public {
    if (block.chainid != 10) {
      vm.skip(true);
    }

    EtherFiSpokeInstance spoke = new EtherFiSpokeInstance(address(new MockOracle()), 64);
    address notASafe = address(0xBEEF);
    address fakeSafe = address(0xCAFE);

    // live data provider says no -> gated
    vm.expectRevert(abi.encodeWithSelector(EtherFiSpokeInstance.OnlyEtherFiSafe.selector, notASafe));
    spoke.borrow(0, 1, notASafe);

    // data provider says yes -> gate passes, parent borrow takes over (Unauthorized: no position manager)
    vm.mockCall(
      spoke.ETHERFI_DATA_PROVIDER(),
      abi.encodeWithSignature('isEtherFiSafe(address)', fakeSafe),
      abi.encode(true)
    );
    vm.expectRevert(); // parent's Unauthorized (onlyPositionManager), NOT OnlyEtherFiSafe
    spoke.borrow(0, 1, fakeSafe);

    assertEq(spoke.ETHERFI_DATA_PROVIDER(), 0xDC515Cb479a64552c5A11a57109C314E40A1A778);
  }
}
