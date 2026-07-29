// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @dev The ether.fi data provider used to recognize Cash Safes (a proxy; address is stable).
interface IEtherFiDataProvider {
  function isEtherFiSafe(address account) external view returns (bool);
}
