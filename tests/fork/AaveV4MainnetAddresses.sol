// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title AaveV4MainnetAddresses
/// @notice Ethereum mainnet addresses of the live Aave V4 deployment.
/// @dev Copied from `aave-dao/aave-address-book` (`src/AaveV4Ethereum.sol`) to avoid pulling the whole
///      registry as a dependency. Only the values exercised by the fork suite are mirrored here.
///      `TreasurySpoke` / `TokenizationSpoke` are intentionally omitted: they are different
///      implementations from `Spoke.sol` and are out of scope for this upgrade.
library AaveV4MainnetAddresses {
  address internal constant ACCESS_MANAGER = 0x08aE3BE30958cDd1847ec58fFfd4C451a87fDF01;

  // AaveV4EthereumHubs
  address internal constant CORE_HUB = 0xCca852Bc40e560adC3b1Cc58CA5b55638ce826c9;
  address internal constant PLUS_HUB = 0x06002e9c4412CB7814a791eA3666D905871E536A;
  address internal constant PRIME_HUB = 0x943827DCA022D0F354a8a8c332dA1e5Eb9f9F931;

  // AaveV4EthereumSpokes (generic `SpokeInstance`-based spokes only)
  address internal constant MAIN_SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
  address internal constant BLUECHIP_SPOKE = 0x973a023A77420ba610f06b3858aD991Df6d85A08;
}
