// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SetupHelpers} from 'tests/helpers/commons/SetupHelpers.sol';
import {HubActions} from 'tests/helpers/hub/HubActions.sol';
import {DeployUtils} from 'tests/helpers/deploy/DeployUtils.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ITreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {ITokenizationSpoke} from 'src/spoke/TokenizationSpoke.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';

/// @title TokenizationSpokeSetupHelpers
/// @notice Setup utilities for tokenization spoke tests.
abstract contract TokenizationSpokeSetupHelpers is SetupHelpers {
  function _withdrawLiquidityFees(
    IHub hub,
    uint256 assetId,
    uint256 amount,
    ITreasurySpoke treasurySpoke_,
    address admin,
    address treasuryAdmin
  ) internal {
    HubActions.mintFeeShares(hub, assetId, admin);
    uint256 fees = hub.getSpokeAddedAssets(assetId, address(treasurySpoke_));

    if (amount > fees) {
      amount = fees;
    }
    if (amount == 0) {
      return; // nothing to withdraw
    }
    vm.prank(treasuryAdmin);
    treasurySpoke_.withdraw(assetId, amount, address(treasurySpoke_));
  }

  function _deployTokenizationSpoke(
    IHub hub,
    uint256 assetId,
    string memory shareName,
    string memory shareSymbol,
    address proxyAdminOwner
  ) internal pausePrank returns (ITokenizationSpoke) {
    address tokenizationSpokeImpl = address(new TokenizationSpokeInstance(address(hub), assetId));
    ITokenizationSpoke tokenizationSpoke = ITokenizationSpoke(
      DeployUtils.proxify(
        tokenizationSpokeImpl,
        proxyAdminOwner,
        abi.encodeCall(TokenizationSpokeInstance.initialize, (shareName, shareSymbol))
      )
    );
    return tokenizationSpoke;
  }

  function _registerTokenizationSpoke(
    IHub hub,
    uint256 assetId,
    ITokenizationSpoke tokenizationSpoke,
    address admin
  ) internal {
    _registerTokenizationSpoke(
      hub,
      assetId,
      tokenizationSpoke,
      IHub.SpokeConfig({
        addCap: type(uint40).max,
        drawCap: 0,
        riskPremiumThreshold: 0,
        active: true,
        halted: false
      }),
      admin
    );
  }

  function _registerTokenizationSpoke(
    IHub hub,
    uint256 assetId,
    ITokenizationSpoke tokenizationSpoke,
    IHub.SpokeConfig memory config,
    address admin
  ) internal pausePrank {
    vm.prank(admin);
    hub.addSpoke(assetId, address(tokenizationSpoke), config);
  }
}
