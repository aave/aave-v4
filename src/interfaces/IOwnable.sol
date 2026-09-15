// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

/// @title IOwnable
/// @notice interface for Ownable to support integrations
interface IOwnable {
    ///@notice function that returns owner address
    function owner() external view returns(address);
}