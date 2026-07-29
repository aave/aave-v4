// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dev Test stand-in for the ether.fi EtherFiDataProvider, etched at the address hardcoded in
/// EtherFiSpokeInstance. `allSafe` makes the borrow gate transparent (every account recognized),
/// which is the mode used to re-run the stock Spoke suite; per-account overrides via `setSafe`
/// support the restricted-borrow scenarios.
contract MockEtherFiDataProvider {
  bool public allSafe;
  mapping(address account => bool) public safes;

  function setAllSafe(bool allSafe_) external {
    allSafe = allSafe_;
  }

  function setSafe(address account, bool isSafe) external {
    safes[account] = isSafe;
  }

  function isEtherFiSafe(address account) external view returns (bool) {
    return allSafe || safes[account];
  }
}
