// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Test Contracts
import {Actor} from './Actor.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

library ActorsUtils {
  uint256 internal constant INITIAL_ETH_BALANCE = 1e26;
  uint256 constant INITIAL_BALANCE = 1e12;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           ACTORS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Deploy protocol actors and initialize their balances
  function setUpActors(
    address[] memory addresses,
    address[] memory tokens,
    address[] memory contracts
  ) internal returns (address[] memory actorAddresses) {
    actorAddresses = new address[](addresses.length);

    // Initialize the three actors of the fuzzers
    for (uint256 i; i < addresses.length; i++) {
      // Deploy actor proxies and approve system contracts
      address actor = setUpActor(tokens, contracts);

      // Mint initial balances to actors
      for (uint256 j = 0; j < tokens.length; j++) {
        TestnetERC20 token = TestnetERC20(tokens[j]);
        uint256 decimals = token.decimals();
        token.mint(actor, INITIAL_BALANCE * 10 ** decimals);
      }
      actorAddresses[i] = actor;
    }
  }

  /// @notice Deploy an actor proxy contract
  /// @param tokens Array of token addresses
  /// @param contracts Array of contract addresses to aprove tokens to
  /// @return Address of the deployed actor
  function setUpActor(
    address[] memory tokens,
    address[] memory contracts
  ) internal returns (address) {
    Actor actor = new Actor(tokens, contracts);
    (bool ok, ) = address(actor).call{value: INITIAL_ETH_BALANCE}('');
    assert(ok);
    return address(actor);
  }
}
