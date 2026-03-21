// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Libraries
import {Vm} from 'forge-std/Base.sol';
import {StdUtils} from 'forge-std/StdUtils.sol';
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {Constants} from 'tests/Constants.sol';

// Interfaces
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

// Utils
import {Actor} from '../../shared/utils/Actor.sol';
import {PropertiesConstants} from '../../shared/utils/PropertiesConstants.sol';
import {StdAsserts} from '../../shared/utils/StdAsserts.sol';

// Base
import {BaseStorage} from './BaseStorage.t.sol';

/// @notice Base contract for all test contracts extends BaseStorage
/// @dev Provides setup modifier and cheat code setup
/// @dev inherits Storage, Testing constants assertions and utils needed for testing
abstract contract BaseTest is BaseStorage, PropertiesConstants, StdAsserts, StdUtils {
  using EnumerableSet for EnumerableSet.AddressSet;

  bool public IS_TEST = true;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   ACTOR PROXY MECHANISM                                   //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @dev Actor proxy mechanism
  modifier setup() virtual {
    actor = userToActor[msg.sender];
    _;
    delete actor;
  }

  /// @dev Solves medusa backward time warp issue
  modifier monotonicTimestamp() virtual {
    /// @dev Implement monotonic timestamp if needed
    _;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          CALLBACKS                                        //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  receive() external payable {}

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     CHEAT CODE SETUP                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @dev Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.
  address internal constant VM_ADDRESS = address(uint160(uint256(keccak256('hevm cheat code'))));

  /// @dev Virtual machine instance
  Vm internal constant vm = Vm(VM_ADDRESS);

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   HELPERS: RANDOM GETTERS                                 //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Get a random actor proxy address
  function _getRandomActor(uint256 _i) internal view returns (address) {
    uint256 _actorIndex = _i % actors.length();
    return actors.at(_actorIndex);
  }

  /// @notice Helper function to get a random base asset
  function _getRandomBaseAsset(uint256 i) internal view returns (address) {
    uint256 _assetIndex = i % baseAssets.length;
    return baseAssets[_assetIndex].underlying;
  }

  /// @notice Helper function to get random base asset full info
  function _getRandomBaseAssetFullInfo(uint256 i) internal view returns (AssetInfo memory) {
    uint256 _assetIndex = i % baseAssets.length;
    return baseAssets[_assetIndex];
  }

  /// @notice Helper function to get a random hub asset id
  function _getRandomHubAssetId(address hub, uint256 i) internal view returns (uint256) {
    uint256 _assetIndex = i % hubAssetIds[hub].length;
    return hubAssetIds[hub][_assetIndex];
  }

  /// @notice Helper function to get a random spoke address
  function _getRandomSpoke(uint256 i) internal view returns (address) {
    uint256 _spokeIndex = i % spokes.length();
    return spokes.at(_spokeIndex);
  }

  /// @notice Helper function to get a random reserve id from a spoke
  function _getRandomReserveId(address spoke, uint256 i) internal view returns (uint256) {
    return i % ISpoke(spoke).getReserveCount();
  }

  /// @notice Helper function to get a random price feed address
  function _getRandomPriceFeed(uint256 i) internal view returns (address) {
    uint256 _priceFeedIndex = i % priceFeeds.length;
    return priceFeeds[_priceFeedIndex];
  }

  /// @notice Helper function to get a random hub address
  function _getRandomHub(uint256 i) internal view returns (address) {
    uint256 _hubIndex = i % hubs.length();
    return hubs.at(_hubIndex);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      HELPERS: GETTERS                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _getAssetId(address spoke, uint256 reserveId) internal view returns (uint256) {
    return reserveIdToAssetId[spoke][reserveId];
  }

  function _getReserveId(address spoke, uint256 assetId) internal view returns (uint256) {
    return assetIdToReserveId[spoke][assetId];
  }

  function _getHubAddress(address spoke, uint256 reserveId) internal view returns (address) {
    return reserveIdToHubAddress[spoke][reserveId];
  }

  function _isHealthy(address spoke, address user) internal view returns (bool) {
    return
      ISpoke(spoke).getUserAccountData(user).healthFactor >=
      Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
  }

  /// @notice Returns true if the reserve/spoke is admin-blocked for the given action
  function _isReserveActionBlocked(
    address spoke,
    uint256 reserveId,
    bool checkFrozen,
    bool checkBorrowable
  ) internal view returns (bool) {
    ISpoke.ReserveConfig memory config = ISpoke(spoke).getReserveConfig(reserveId);
    if (config.paused) return true;
    if (checkFrozen && config.frozen) return true;
    if (checkBorrowable && !config.borrowable) return true;
    address hubAddress = _getHubAddress(spoke, reserveId);
    uint256 assetId = _getAssetId(spoke, reserveId);
    IHub.SpokeData memory spokeData = IHub(hubAddress).getSpoke(assetId, spoke);
    if (!spokeData.active || spokeData.halted) return true;
    return false;
  }

  /// @notice Returns true if the current actor can act on behalf of `onBehalfOf` on the spoke
  function _isAuthorized(address spoke, address onBehalfOf) internal view returns (bool) {
    return ISpoke(spoke).isPositionManager(onBehalfOf, address(actor));
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          HELPERS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Get a random address
  function _makeAddr(string memory name) internal pure returns (address addr) {
    uint256 privateKey = uint256(keccak256(abi.encodePacked(name)));
    addr = vm.addr(privateKey);
  }

  /// @notice Helper function to transfer tokens by actor
  function _transferByActor(address token, address to, uint256 amount) internal {
    (bool ok, bytes memory ret) = actor.proxy(token, abi.encodeCall(IERC20.transfer, (to, amount)));
    require(ok, string(ret));
  }

  /// @notice Helper function to approve tokens by actor
  function _approveByActor(address token, address spender, uint256 amount) internal {
    (bool ok, bytes memory ret) = actor.proxy(
      token,
      abi.encodeCall(IERC20.approve, (spender, amount))
    );
    require(ok, string(ret));
  }

  /// @notice Helper function to calculate burnt interest in assets terms (originating from virtual shares)
  function _calculateBurntInterest(IHub hub_, uint256 assetId_) internal view returns (uint256) {
    uint256 totalAssets = hub_.getAddedAssets(assetId_);
    uint256 totalShares = hub_.getAddedShares(assetId_);
    return totalAssets - hub_.previewRemoveByShares(assetId_, totalShares);
  }

  function _underlying(ISpoke spoke, uint256 reserveId) internal view returns (address) {
    return spoke.getReserve(reserveId).underlying;
  }

  function _underlying(address spoke, uint256 reserveId) internal view returns (address) {
    return _underlying(ISpoke(spoke), reserveId);
  }
}
