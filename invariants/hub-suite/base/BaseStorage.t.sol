// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Contracts
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {HubConfigurator} from 'src/hub/HubConfigurator.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

// Utils
import {Actor} from '../../shared/utils/Actor.sol';

/// @notice BaseStorage contract for hub-focused test suite
abstract contract BaseStorage {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       CONSTANTS                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  uint256 constant MAX_TOKEN_AMOUNT = 1e29;

  uint256 constant ONE_DAY = 1 days;
  uint256 constant ONE_MONTH = ONE_YEAR / 12;
  uint256 constant ONE_YEAR = 365 days;

  uint256 internal constant NUMBER_OF_ACTORS = 3;
  uint256 internal constant INITIAL_ETH_BALANCE = 1e26;
  uint256 internal constant INITIAL_COLL_BALANCE = 1e21;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          ACTORS                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice The address of the admin, the tester itself
  address internal admin = address(this);

  /// @notice Stores the actor during a handler call
  Actor internal actor;

  /// @notice Mapping of fuzzer user addresses to actors
  mapping(address => Actor) internal userToActor;

  /// @notice Array of all actor addresses (simulating spokes)
  address[] internal actors;

  /// @notice The signature of the action that is being executed
  bytes4 internal currentActionSignature;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       ASSETS STORAGE                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice The USDC token
  TestnetERC20 internal usdc;
  /// @notice The WETH token
  TestnetERC20 internal weth;
  /// @notice The WBTC token
  TestnetERC20 internal wbtc;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       HUB STORAGE                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Single Hub instance
  IHub internal hub;

  /// @notice Interest rate strategy for the hub
  AssetInterestRateStrategy internal irStrategy;

  /// @notice Hub Configurator
  HubConfigurator internal hubConfigurator;

  /// @notice Access Manager
  AccessManager internal accessManager;

  // PRICE FEEDS
  address[] internal priceFeeds;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       ASSET CONFIG                                        //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Asset info struct
  struct AssetInfo {
    address underlying;
    uint8 decimals;
  }

  /// @notice Array of base assets for the hub
  AssetInfo[] internal baseAssets;

  /// @notice Hub asset IDs
  uint256 internal wethAssetId;
  uint256 internal usdcAssetId;
  uint256 internal wbtcAssetId;
  uint256[] internal hubAssetIds;
  mapping(uint256 => address) internal assetIdToUnderlying;
  mapping(address => uint256) internal underlyingToAssetId;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       SPOKE CONFIG                                        //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Array of spoke addresses (actors acting as spokes)
  address[] internal spokeAddresses;
}
