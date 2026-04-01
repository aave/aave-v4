// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpokeHelpers} from 'tests/helpers/spoke/SpokeHelpers.sol';
import {HubActions} from 'tests/helpers/hub/HubActions.sol';
import {DeployUtils} from 'tests/helpers/deploy/DeployUtils.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {ITreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {ITokenizationSpoke} from 'src/spoke/TokenizationSpoke.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';
import {TestnetERC20} from 'tests/helpers/mocks/TestnetERC20.sol';
import {EIP712Types} from 'tests/helpers/mocks/EIP712Types.sol';

/// @title SetupHelpers
/// @notice Deploy, register, data-builder, and scenario-setup utilities for tokenization spoke tests.
abstract contract SetupHelpers is SpokeHelpers {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  DEPLOY & REGISTER                                        //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _deployTokenizationSpoke(
    IHub hub,
    address underlying,
    string memory shareName,
    string memory shareSymbol,
    address proxyAdminOwner
  ) internal pausePrank returns (ITokenizationSpoke) {
    address tokenizationSpokeImpl = address(
      new TokenizationSpokeInstance(address(hub), underlying)
    );
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

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  DATA BUILDERS                                            //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _depositData(
    ITokenizationSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (ITokenizationSpoke.TokenizedDeposit memory) {
    return
      ITokenizationSpoke.TokenizedDeposit({
        depositor: who,
        assets: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        receiver: vm.randomAddress(),
        nonce: vault.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _mintData(
    ITokenizationSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (ITokenizationSpoke.TokenizedMint memory) {
    return
      ITokenizationSpoke.TokenizedMint({
        depositor: who,
        shares: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        receiver: vm.randomAddress(),
        nonce: vault.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _withdrawData(
    ITokenizationSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (ITokenizationSpoke.TokenizedWithdraw memory) {
    return
      ITokenizationSpoke.TokenizedWithdraw({
        owner: who,
        assets: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        receiver: vm.randomAddress(),
        nonce: vault.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _redeemData(
    ITokenizationSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (ITokenizationSpoke.TokenizedRedeem memory) {
    return
      ITokenizationSpoke.TokenizedRedeem({
        owner: who,
        shares: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        receiver: vm.randomAddress(),
        nonce: vault.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _permitData(
    ITokenizationSpoke vault,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.Permit memory) {
    return
      EIP712Types.Permit({
        owner: who,
        spender: address(vault),
        value: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        deadline: deadline,
        nonce: vault.nonces(who, vault.PERMIT_NONCE_NAMESPACE()) // can only use permit nonce key namespace
      });
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  SETUP HELPERS                                            //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _simulateYield(
    ITokenizationSpoke vault,
    uint256 amount,
    address spoke,
    address irStrategy_
  ) internal {
    IHub hub = IHub(vault.hub());
    TestnetERC20 asset = TestnetERC20(vault.asset());
    uint256 assetId = vault.assetId();

    asset.mint(address(hub), amount);
    vm.startPrank(spoke);
    hub.add(assetId, amount);
    _mockDrawnRateBps(irStrategy_, 100_00);
    hub.draw(assetId, amount, spoke);
    skip(365 days);
    asset.mint(address(hub), amount);
    hub.restore(assetId, amount, IHubBase.PremiumDelta(0, 0, 0));
    vm.stopPrank();
  }
}
