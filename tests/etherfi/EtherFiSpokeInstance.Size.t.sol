// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

/// @dev EIP-170 size gate for EtherFiSpokeInstance (review: the contract sits close to the
/// limit at the shared spoke compiler profile — 750 optimizer runs, via_ir). A dedicated
/// lower-runs profile was considered and rejected: the file shares SpokeInstance's compilation
/// unit, so a separate profile would silently recompile the stock spoke. This gate makes the
/// remaining margin visible on every test run and fails loudly if an upstream Spoke change or
/// compiler bump eats it.
contract EtherFiSpokeInstanceSizeTest is Test {
  uint256 internal constant EIP170_LIMIT = 24_576;
  /// @dev Alarm threshold: fail while there is still room to react, not at 0.
  uint256 internal constant MIN_MARGIN = 10;

  function test_runtimeSize_underEip170_withMargin() public {
    uint256 size = vm
      .getDeployedCode('src/etherfi/EtherFiSpokeInstance.sol:EtherFiSpokeInstance')
      .length;
    emit log_named_uint('EtherFiSpokeInstance runtime size', size);
    emit log_named_uint('EIP-170 margin (bytes)', EIP170_LIMIT - size);

    assertLe(size, EIP170_LIMIT, 'EtherFiSpokeInstance exceeds EIP-170');
    assertGe(
      EIP170_LIMIT - size,
      MIN_MARGIN,
      'EtherFiSpokeInstance margin below alarm threshold - revisit compiler settings'
    );
  }
}
