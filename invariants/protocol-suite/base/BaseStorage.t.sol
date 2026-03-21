// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ITreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IAssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

import {Actor} from '../../shared/utils/Actor.sol';

/// @notice BaseStorage contract for all test contracts, works in tandem with BaseTest
abstract contract BaseStorage {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       CONSTANTS                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  uint256 constant MAX_TOKEN_AMOUNT = 1e29;

  uint256 constant ONE_DAY = 1 days;
  uint256 constant ONE_YEAR = 365 days;
  uint256 constant ONE_MONTH = ONE_YEAR / 12;

  uint256 internal constant NUMBER_OF_ACTORS = 3;
  uint256 internal constant INITIAL_COLL_BALANCE = 1e21;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          ACTORS                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice The address of the admin, the tester itself
  address internal admin = address(this);

  /// @notice Stores the actor during a handler call
  Actor internal actor;

  /// @notice Mapping of fuzzer user addresses to actors
  mapping(address user => Actor) internal userToActor;

  /// @notice Array of all actor addresses
  EnumerableSet.AddressSet internal actors;

  /// @notice The address that is targeted when executing an action (OPTIONAL)
  address internal targetActor;

  /// @notice The signature of the action that is being executed
  bytes4 internal currentActionSignature;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       ASSETS STORAGE                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice The USDC token
  TestnetERC20 internal usdc;
  /// @notice The WETH token
  TestnetERC20 internal weth;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       SUITE STORAGE                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  // HUB CONTRACTS
  IHub internal hub1;
  IHub internal hub2;
  IAssetInterestRateStrategy internal irStrategy1;
  IAssetInterestRateStrategy internal irStrategy2;
  IHubConfigurator internal hubConfigurator;

  // SPOKE CONTRACTS
  ITreasurySpoke internal treasurySpoke1;
  ITreasurySpoke internal treasurySpoke2;
  ISpoke internal spoke1;
  ISpoke internal spoke2;
  ISpokeConfigurator internal spokeConfigurator;

  // ORACLES
  IAaveOracle internal oracle1;
  IAaveOracle internal oracle2;

  // CONFIGURATION
  IAccessManagerEnumerable internal accessManager;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       EXTRA VARIABLES                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  // ASSETS
  /// @notice Array of base assets for the suite
  AssetInfo[] internal baseAssets;

  // HUB
  uint256 internal hub1WethAssetId;
  uint256 internal hub1UsdcAssetId;
  uint256 internal hub2WethAssetId;
  uint256 internal hub2UsdcAssetId;

  /// @notice Array of hub addresses for the suite
  EnumerableSet.AddressSet internal hubs;
  /// @notice Spoke configurations
  mapping(address => HubInfo) internal hubInfo;
  /// @notice Hub assetIds
  mapping(address => uint256[]) internal hubAssetIds;

  // SPOKES
  /// @notice Array of spokes addresses for the suite
  EnumerableSet.AddressSet internal spokes;
  /// @notice Array of treasury spoke addresses
  EnumerableSet.AddressSet internal treasurySpokes;
  /// @notice spokesAddresses + treasurySpoke address
  address[] internal allSpokes;
  /// @notice Spoke configurations
  mapping(ISpoke => SpokeInfo) internal spokeInfo;
  /// @notice Spoke reserveIds to global assetIds
  mapping(address => mapping(uint256 => uint256)) internal reserveIdToAssetId;
  /// @notice Spoke assetIds to reserveIds info
  mapping(address => mapping(uint256 => uint256)) internal assetIdToReserveId;
  /// @notice Spoke reserveIds to hub addresses
  mapping(address => mapping(uint256 => address)) internal reserveIdToHubAddress;

  // PRICE FEEDS
  address[] internal priceFeeds;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          STRUCTS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  struct SpokeInfo {
    ReserveInfo weth;
    ReserveInfo usdc;
    ReserveInfo weth2;
    ReserveInfo usdc2;
    uint256 MAX_ALLOWED_ASSET_ID;
  }

  struct HubInfo {
    address treasurySpoke;
    address irStrategy;
  }

  struct ReserveInfo {
    uint256 reserveId;
    ISpoke.ReserveConfig reserveConfig;
    ISpoke.DynamicReserveConfig dynReserveConfig;
  }

  struct AssetInfo {
    address underlying;
    uint8 decimals;
  }
}
