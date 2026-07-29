// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @dev Minimal view onto the gate-specific surface of EtherFiSpokeInstance. Kept as a standalone
/// interface (rather than importing EtherFiSpokeInstance.sol) so consumers are not dragged into
/// the via_ir compiler job that file's foundry.toml profile requires (see EtherFiSpokeTestBase
/// for the same pattern).
interface IEtherFiSpokeInstance {
  function ETHERFI_DATA_PROVIDER() external view returns (address);
}
