// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {AssetLogic} from 'src/hub/libraries/AssetLogic.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {IBasicInterestRateStrategy} from 'src/hub/interfaces/IBasicInterestRateStrategy.sol';
import {IHubBase, IHub} from 'src/hub/interfaces/IHub.sol';

/// @title Hub
/// @author Aave Labs
/// @notice A liquidity hub that manages assets and spokes.
contract Hub is IHub, AccessManaged {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeERC20 for IERC20;
  using SafeCast for uint256;
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using AssetLogic for Asset;
  using MathUtils for *;

  /// @inheritdoc IHub
  uint8 public constant MAX_ALLOWED_UNDERLYING_DECIMALS = 18;

  /// @inheritdoc IHub
  uint8 public constant MIN_ALLOWED_UNDERLYING_DECIMALS = 6;

  /// @inheritdoc IHub
  uint56 public constant MAX_ALLOWED_SPOKE_CAP = type(uint56).max;

  uint256 internal _assetCount;
  mapping(uint256 assetId => Asset) internal _assets;
  mapping(uint256 assetId => mapping(address spoke => SpokeData)) internal _spokes;
  mapping(uint256 assetId => EnumerableSet.AddressSet) internal _assetToSpokes;

  /// @dev Constructor.
  /// @dev The authority contract must implement the `AccessManaged` interface for access control.
  /// @param authority_ The address of the authority contract which manages permissions.
  constructor(address authority_) AccessManaged(authority_) {
    require(authority_ != address(0), InvalidAddress());
  }

  /// @inheritdoc IHub
  function addAsset(
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address irStrategy,
    bytes calldata irData
  ) external restricted returns (uint256) {
    require(
      underlying != address(0) && feeReceiver != address(0) && irStrategy != address(0),
      InvalidAddress()
    );
    require(
      MIN_ALLOWED_UNDERLYING_DECIMALS <= decimals && decimals <= MAX_ALLOWED_UNDERLYING_DECIMALS,
      InvalidAssetDecimals()
    );

    uint256 assetId = _assetCount++;
    IBasicInterestRateStrategy(irStrategy).setInterestRateData(assetId, irData);
    uint256 drawnRate = IBasicInterestRateStrategy(irStrategy).calculateInterestRate({
      assetId: assetId,
      liquidity: 0,
      drawn: 0,
      deficit: 0,
      swept: 0
    });

    uint256 drawnIndex = WadRayMath.RAY;
    uint256 lastUpdateTimestamp = block.timestamp;
    _assets[assetId] = Asset({
      liquidity: 0,
      deficit: 0,
      swept: 0,
      addedShares: 0,
      drawnShares: 0,
      premiumShares: 0,
      premiumOffset: 0,
      drawnIndex: drawnIndex.toUint128(),
      realizedPremium: 0,
      underlying: underlying,
      lastUpdateTimestamp: lastUpdateTimestamp.toUint32(),
      decimals: decimals,
      drawnRate: drawnRate.toUint96(),
      irStrategy: irStrategy,
      reinvestmentController: address(0),
      feeReceiver: feeReceiver,
      liquidityFee: 0
    });
    _addFeeReceiver(assetId, feeReceiver);

    emit AddAsset(assetId, underlying, decimals);
    emit UpdateAssetConfig(
      assetId,
      AssetConfig({
        feeReceiver: feeReceiver,
        liquidityFee: 0,
        irStrategy: irStrategy,
        reinvestmentController: address(0)
      })
    );
    emit UpdateAsset(assetId, drawnIndex, drawnRate);

    return assetId;
  }

  /// @inheritdoc IHub
  function updateAssetConfig(
    uint256 assetId,
    AssetConfig calldata config,
    bytes calldata irData
  ) external restricted {
    require(assetId < _assetCount, AssetNotListed());
    Asset storage asset = _assets[assetId];
    asset.accrue(_spokes, assetId);

    require(config.liquidityFee <= PercentageMath.PERCENTAGE_FACTOR, InvalidLiquidityFee());
    require(config.feeReceiver != address(0) && config.irStrategy != address(0), InvalidAddress());
    require(
      config.reinvestmentController != address(0) || asset.swept == 0,
      InvalidReinvestmentController()
    );

    if (config.irStrategy != asset.irStrategy) {
      asset.irStrategy = config.irStrategy;
      IBasicInterestRateStrategy(config.irStrategy).setInterestRateData(assetId, irData);
    } else {
      require(irData.length == 0, InvalidInterestRateStrategy());
    }

    if (asset.feeReceiver != config.feeReceiver) {
      _updateSpokeConfig(assetId, asset.feeReceiver, SpokeConfig(true, 0, 0));
      asset.feeReceiver = config.feeReceiver;
      _addFeeReceiver(assetId, config.feeReceiver);
    }

    asset.liquidityFee = config.liquidityFee;
    asset.reinvestmentController = config.reinvestmentController;

    asset.updateDrawnRate(assetId);

    emit UpdateAssetConfig(assetId, config);
  }

  /// @inheritdoc IHub
  function addSpoke(
    uint256 assetId,
    address spoke,
    SpokeConfig calldata config
  ) external restricted {
    require(assetId < _assetCount, AssetNotListed());
    require(spoke != address(0), InvalidAddress());
    _addSpoke(assetId, spoke);
    _updateSpokeConfig(assetId, spoke, config);
  }

  /// @inheritdoc IHub
  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    SpokeConfig calldata config
  ) external restricted {
    require(assetId < _assetCount, AssetNotListed());
    require(_assetToSpokes[assetId].contains(spoke), SpokeNotListed());
    _updateSpokeConfig(assetId, spoke, config);
  }

  /// @inheritdoc IHub
  function setInterestRateData(uint256 assetId, bytes calldata irData) external restricted {
    require(assetId < _assetCount, AssetNotListed());
    Asset storage asset = _assets[assetId];
    asset.accrue(_spokes, assetId);
    IBasicInterestRateStrategy(asset.irStrategy).setInterestRateData(assetId, irData);
    asset.updateDrawnRate(assetId);
  }

  /// @inheritdoc IHubBase
  function add(uint256 assetId, uint256 amount, address from) external returns (uint256) {
    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(_spokes, assetId);
    _validateAdd(asset, spoke, amount, from);

    uint128 shares = asset.toAddedSharesDown(amount).toUint128();
    require(shares > 0, InvalidShares());
    asset.addedShares += shares;
    spoke.addedShares += shares;
    asset.liquidity += amount.toUint128();

    asset.updateDrawnRate(assetId);

    IERC20(asset.underlying).safeTransferFrom(from, address(this), amount);

    emit Add(assetId, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc IHubBase
  function remove(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(_spokes, assetId);
    _validateRemove(asset, spoke, amount, to);
    uint256 liquidity = asset.liquidity;
    require(amount <= liquidity, InsufficientLiquidity(liquidity));

    uint128 shares = asset.toAddedSharesUp(amount).toUint128();
    asset.addedShares -= shares;
    spoke.addedShares -= shares;
    asset.liquidity = liquidity.uncheckedSub(amount).toUint128();

    asset.updateDrawnRate(assetId);

    IERC20(asset.underlying).safeTransfer(to, amount);

    emit Remove(assetId, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc IHubBase
  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(_spokes, assetId);
    _validateDraw(asset, spoke, amount, to);
    uint256 liquidity = asset.liquidity;
    require(amount <= liquidity, InsufficientLiquidity(liquidity));

    uint128 drawnShares = asset.toDrawnSharesUp(amount).toUint128();
    asset.drawnShares += drawnShares;
    spoke.drawnShares += drawnShares;
    asset.liquidity = liquidity.uncheckedSub(amount).toUint128();

    asset.updateDrawnRate(assetId);

    IERC20(asset.underlying).safeTransfer(to, amount);

    emit Draw(assetId, msg.sender, drawnShares, amount);

    return drawnShares;
  }

  /// @inheritdoc IHubBase
  function restore(
    uint256 assetId,
    uint256 drawnAmount,
    uint256 premiumAmount,
    PremiumDelta calldata premiumDelta,
    address from
  ) external returns (uint256) {
    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(_spokes, assetId);
    _validateRestore(asset, spoke, drawnAmount, premiumAmount, from);

    uint128 drawnShares = asset.toDrawnSharesDown(drawnAmount).toUint128();
    asset.drawnShares -= drawnShares;
    spoke.drawnShares -= drawnShares;
    _applyPremiumDelta(asset, spoke, premiumDelta, premiumAmount);
    uint256 totalAmount = drawnAmount + premiumAmount;
    asset.liquidity += totalAmount.toUint128();

    asset.updateDrawnRate(assetId);

    IERC20(asset.underlying).safeTransferFrom(from, address(this), totalAmount);

    emit Restore(assetId, msg.sender, drawnShares, premiumDelta, drawnAmount, premiumAmount);

    return drawnShares;
  }

  /// @inheritdoc IHubBase
  function reportDeficit(
    uint256 assetId,
    uint256 drawnAmount,
    uint256 premiumAmount,
    PremiumDelta calldata premiumDelta
  ) external returns (uint256) {
    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(_spokes, assetId);
    _validateReportDeficit(asset, spoke, drawnAmount, premiumAmount);

    uint128 drawnShares = asset.toDrawnSharesDown(drawnAmount).toUint128();
    asset.drawnShares -= drawnShares;
    spoke.drawnShares -= drawnShares;
    _applyPremiumDelta(asset, spoke, premiumDelta, premiumAmount);
    uint128 deficitAmount = (drawnAmount + premiumAmount).toUint128();
    asset.deficit += deficitAmount;
    spoke.deficit += deficitAmount;

    asset.updateDrawnRate(assetId);

    emit ReportDeficit(assetId, msg.sender, drawnShares, premiumDelta, drawnAmount, premiumAmount);

    return drawnShares;
  }

  /// @inheritdoc IHub
  function eliminateDeficit(
    uint256 assetId,
    uint256 amount,
    address spoke
  ) external returns (uint256) {
    Asset storage asset = _assets[assetId];
    SpokeData storage callerSpoke = _spokes[assetId][msg.sender];
    SpokeData storage coveredSpoke = _spokes[assetId][spoke];

    asset.accrue(_spokes, assetId);
    _validateEliminateDeficit(callerSpoke, amount);
    uint256 deficit = coveredSpoke.deficit;
    require(amount <= deficit, InvalidAmount());

    uint128 shares = asset.toAddedSharesUp(amount).toUint128();
    asset.addedShares -= shares;
    callerSpoke.addedShares -= shares;
    asset.deficit -= amount.toUint128();
    coveredSpoke.deficit = deficit.uncheckedSub(amount).toUint128();

    asset.updateDrawnRate(assetId);

    emit EliminateDeficit(assetId, msg.sender, spoke, shares, amount);

    return shares;
  }

  /// @inheritdoc IHubBase
  function refreshPremium(uint256 assetId, PremiumDelta calldata premiumDelta) external {
    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(_spokes, assetId);
    require(spoke.active, SpokeNotActive());
    // no premium change allowed
    _applyPremiumDelta(asset, spoke, premiumDelta, 0);
    asset.updateDrawnRate(assetId);

    emit RefreshPremium(assetId, msg.sender, premiumDelta);
  }

  /// @inheritdoc IHubBase
  function payFeeShares(uint256 assetId, uint256 shares) external {
    Asset storage asset = _assets[assetId];
    address feeReceiver = _assets[assetId].feeReceiver;
    SpokeData storage receiver = _spokes[assetId][feeReceiver];
    SpokeData storage sender = _spokes[assetId][msg.sender];

    asset.accrue(_spokes, assetId);
    _validatePayFeeShares(sender, shares);
    _transferShares(sender, receiver, shares);
    asset.updateDrawnRate(assetId);

    emit TransferShares(assetId, msg.sender, feeReceiver, shares);
  }

  /// @inheritdoc IHub
  function transferShares(uint256 assetId, uint256 shares, address toSpoke) external {
    Asset storage asset = _assets[assetId];
    SpokeData storage sender = _spokes[assetId][msg.sender];
    SpokeData storage receiver = _spokes[assetId][toSpoke];

    asset.accrue(_spokes, assetId);
    _validateTransferShares(asset, sender, receiver, shares);
    _transferShares(sender, receiver, shares);
    asset.updateDrawnRate(assetId);

    emit TransferShares(assetId, msg.sender, toSpoke, shares);
  }

  /// @inheritdoc IHub
  function sweep(uint256 assetId, uint256 amount) external {
    require(assetId < _assetCount, AssetNotListed());
    Asset storage asset = _assets[assetId];

    asset.accrue(_spokes, assetId);
    _validateSweep(asset, msg.sender, amount);

    asset.liquidity -= amount.toUint128();
    asset.swept += amount.toUint128();
    asset.updateDrawnRate(assetId);

    IERC20(asset.underlying).safeTransfer(msg.sender, amount);

    emit Sweep(assetId, msg.sender, amount);
  }

  /// @inheritdoc IHub
  function reclaim(uint256 assetId, uint256 amount) external {
    require(assetId < _assetCount, AssetNotListed());
    Asset storage asset = _assets[assetId];

    asset.accrue(_spokes, assetId);
    _validateReclaim(asset, msg.sender, amount);

    asset.liquidity += amount.toUint128();
    asset.swept -= amount.toUint128();
    asset.updateDrawnRate(assetId);

    IERC20(asset.underlying).safeTransferFrom(msg.sender, address(this), amount);

    emit Reclaim(assetId, msg.sender, amount);
  }

  /// @inheritdoc IHub
  function getAssetCount() external view returns (uint256) {
    return _assetCount;
  }

  /// @inheritdoc IHubBase
  function previewAddByAssets(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].toAddedSharesDown(assets);
  }

  /// @inheritdoc IHubBase
  function previewAddByShares(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toAddedAssetsUp(shares);
  }

  /// @inheritdoc IHubBase
  function previewRemoveByAssets(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].toAddedSharesUp(assets);
  }

  /// @inheritdoc IHubBase
  function previewRemoveByShares(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toAddedAssetsDown(shares);
  }

  /// @inheritdoc IHubBase
  function previewDrawByAssets(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].toDrawnSharesUp(assets);
  }

  /// @inheritdoc IHubBase
  function previewDrawByShares(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toDrawnAssetsDown(shares);
  }

  /// @inheritdoc IHubBase
  function previewRestoreByAssets(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].toDrawnSharesDown(assets);
  }

  /// @inheritdoc IHubBase
  function previewRestoreByShares(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toDrawnAssetsUp(shares);
  }

  /// @inheritdoc IHub
  function convertToAddedAssets(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toAddedAssetsDown(shares);
  }

  /// @inheritdoc IHub
  function convertToAddedShares(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].toAddedSharesDown(assets);
  }

  /// @inheritdoc IHub
  function convertToDrawnAssets(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toDrawnAssetsUp(shares);
  }

  /// @inheritdoc IHub
  function convertToDrawnShares(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].toDrawnSharesUp(assets);
  }

  /// @inheritdoc IHubBase
  function getAssetUnderlyingAndDecimals(uint256 assetId) external view returns (address, uint8) {
    Asset storage asset = _assets[assetId];
    return (asset.underlying, asset.decimals);
  }

  /// @inheritdoc IHubBase
  function getAddedAssets(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].totalAddedAssets();
  }

  /// @inheritdoc IHubBase
  function getAddedShares(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].totalAddedShares();
  }

  /// @inheritdoc IHubBase
  function getAssetOwed(uint256 assetId) external view returns (uint256, uint256) {
    Asset storage asset = _assets[assetId];
    return (asset.drawn(), asset.premium());
  }

  /// @inheritdoc IHubBase
  function getAssetTotalOwed(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].totalOwed();
  }

  /// @inheritdoc IHubBase
  function getAssetDrawnShares(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].drawnShares;
  }

  /// @inheritdoc IHubBase
  function getAssetPremiumData(uint256 assetId) external view returns (uint256, uint256, uint256) {
    Asset storage asset = _assets[assetId];
    return (asset.premiumShares, asset.premiumOffset, asset.realizedPremium);
  }

  /// @inheritdoc IHubBase
  function getAssetLiquidity(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].liquidity;
  }

  /// @inheritdoc IHubBase
  function getAssetDeficit(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].deficit;
  }

  /// @inheritdoc IHub
  function getAsset(uint256 assetId) external view returns (Asset memory) {
    return _assets[assetId];
  }

  /// @inheritdoc IHub
  function getAssetConfig(uint256 assetId) external view returns (AssetConfig memory) {
    Asset storage asset = _assets[assetId];
    return
      AssetConfig({
        feeReceiver: asset.feeReceiver,
        liquidityFee: asset.liquidityFee,
        irStrategy: asset.irStrategy,
        reinvestmentController: asset.reinvestmentController
      });
  }

  /// @inheritdoc IHub
  function getAssetSwept(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].swept;
  }

  /// @inheritdoc IHub
  function getAssetDrawnIndex(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].getDrawnIndex();
  }

  /// @inheritdoc IHub
  function getAssetDrawnRate(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].drawnRate;
  }

  /// @inheritdoc IHub
  function getSpokeCount(uint256 assetId) external view returns (uint256) {
    return _assetToSpokes[assetId].length();
  }

  /// @inheritdoc IHubBase
  function getSpokeAddedAssets(uint256 assetId, address spoke) external view returns (uint256) {
    Asset storage asset = _assets[assetId];
    uint256 unrealized = spoke == asset.feeReceiver ? asset.unrealizedFeeShares() : 0;
    return asset.toAddedAssetsDown(_spokes[assetId][spoke].addedShares + unrealized);
  }

  /// @inheritdoc IHubBase
  function getSpokeAddedShares(uint256 assetId, address spoke) external view returns (uint256) {
    Asset storage asset = _assets[assetId];
    uint256 unrealized = spoke == asset.feeReceiver ? asset.unrealizedFeeShares() : 0;
    return _spokes[assetId][spoke].addedShares + unrealized;
  }

  /// @inheritdoc IHubBase
  function getSpokeOwed(uint256 assetId, address spoke) external view returns (uint256, uint256) {
    Asset storage asset = _assets[assetId];
    SpokeData storage spokeData = _spokes[assetId][spoke];
    return (_getSpokeDrawn(asset, spokeData), _getSpokePremium(asset, spokeData));
  }

  /// @inheritdoc IHubBase
  function getSpokeTotalOwed(uint256 assetId, address spoke) external view returns (uint256) {
    Asset storage asset = _assets[assetId];
    SpokeData storage spokeData = _spokes[assetId][spoke];
    return _getSpokeDrawn(asset, spokeData) + _getSpokePremium(asset, spokeData);
  }

  /// @inheritdoc IHubBase
  function getSpokeDrawnShares(uint256 assetId, address spoke) external view returns (uint256) {
    return _spokes[assetId][spoke].drawnShares;
  }

  /// @inheritdoc IHubBase
  function getSpokePremiumData(
    uint256 assetId,
    address spoke
  ) external view returns (uint256, uint256, uint256) {
    SpokeData storage spokeData = _spokes[assetId][spoke];
    return (spokeData.premiumShares, spokeData.premiumOffset, spokeData.realizedPremium);
  }

  /// @inheritdoc IHubBase
  function getSpokeDeficit(uint256 assetId, address spoke) external view returns (uint256) {
    return _spokes[assetId][spoke].deficit;
  }

  /// @inheritdoc IHub
  function isSpokeListed(uint256 assetId, address spoke) external view returns (bool) {
    return _assetToSpokes[assetId].contains(spoke);
  }

  /// @inheritdoc IHub
  function getSpokeAddress(uint256 assetId, uint256 index) external view returns (address) {
    return _assetToSpokes[assetId].at(index);
  }

  /// @inheritdoc IHub
  function getSpoke(uint256 assetId, address spoke) external view returns (SpokeData memory) {
    return _spokes[assetId][spoke];
  }

  /// @inheritdoc IHub
  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (SpokeConfig memory) {
    SpokeData storage spokeData = _spokes[assetId][spoke];
    return SpokeConfig(spokeData.active, spokeData.addCap, spokeData.drawCap);
  }

  /// @notice Adds a new spoke to an asset with default feeReceiver configuration (maximum add cap, zero draw cap).
  /// @dev Emits `AddSpoke` and `UpdateSpokeConfig` events.
  function _addFeeReceiver(uint256 assetId, address feeReceiver) internal {
    _addSpoke(assetId, feeReceiver);
    _updateSpokeConfig(
      assetId,
      feeReceiver,
      SpokeConfig({addCap: MAX_ALLOWED_SPOKE_CAP, drawCap: 0, active: true})
    );
  }

  /// @notice Adds a spoke to an asset.
  /// @dev Reverts with `SpokeAlreadyListed` if spoke is already listed for the given asset.
  function _addSpoke(uint256 assetId, address spoke) internal {
    require(_assetToSpokes[assetId].add(spoke), SpokeAlreadyListed());
    emit AddSpoke(assetId, spoke);
  }

  function _updateSpokeConfig(uint256 assetId, address spoke, SpokeConfig memory config) internal {
    SpokeData storage spokeData = _spokes[assetId][spoke];
    spokeData.active = config.active;
    spokeData.addCap = config.addCap;
    spokeData.drawCap = config.drawCap;
    emit UpdateSpokeConfig(assetId, spoke, config);
  }

  /// @dev Receiver `addCap` is validated in `_validateTransferShares`.
  function _transferShares(
    SpokeData storage sender,
    SpokeData storage receiver,
    uint256 shares
  ) internal {
    uint256 addedShares = sender.addedShares;
    require(shares <= addedShares, AddedSharesExceeded(addedShares));

    sender.addedShares = addedShares.uncheckedSub(shares).toUint128();
    receiver.addedShares += shares.toUint128();
  }

  /// @dev Applies premium deltas on asset & spoke premium owed, also checks premium
  /// does not increase by more than `premiumAmount`.
  function _applyPremiumDelta(
    Asset storage asset,
    SpokeData storage spoke,
    PremiumDelta calldata premium,
    uint256 premiumAmount
  ) internal {
    uint256 drawnIndex = asset.getDrawnIndex();
    // asset premium change
    (asset.premiumShares, asset.premiumOffset, asset.realizedPremium) = _validateApplyPremiumDelta(
      drawnIndex,
      asset.premiumShares,
      asset.premiumOffset,
      asset.realizedPremium,
      premium,
      premiumAmount
    );

    // spoke premium change
    (spoke.premiumShares, spoke.premiumOffset, spoke.realizedPremium) = _validateApplyPremiumDelta(
      drawnIndex,
      spoke.premiumShares,
      spoke.premiumOffset,
      spoke.realizedPremium,
      premium,
      premiumAmount
    );
  }

  /// @dev Validates applied premium delta for given premium data and returns updated premium data.
  function _validateApplyPremiumDelta(
    uint256 drawnIndex,
    uint256 premiumShares,
    uint256 premiumOffset,
    uint256 realizedPremium,
    PremiumDelta calldata premium,
    uint256 premiumAmount
  ) internal pure returns (uint128, uint128, uint128) {
    uint256 premiumBefore = premiumShares.rayMulUp(drawnIndex) - premiumOffset;
    premiumBefore += realizedPremium;

    premiumShares = premiumShares.add(premium.sharesDelta);
    premiumOffset = premiumOffset.add(premium.offsetDelta);
    realizedPremium = realizedPremium.add(premium.realizedDelta);

    uint256 premiumAfter = premiumShares.rayMulUp(drawnIndex) - premiumOffset;
    premiumAfter += realizedPremium;
    // can increase due to precision loss on premium (drawn unchanged)
    require(premiumAfter + premiumAmount - premiumBefore <= 2, InvalidPremiumChange());
    return (premiumShares.toUint128(), premiumOffset.toUint128(), realizedPremium.toUint128());
  }

  /// @dev Returns the spoke's drawn amount for a specified asset.
  function _getSpokeDrawn(
    Asset storage asset,
    SpokeData storage spoke
  ) internal view returns (uint256) {
    return asset.toDrawnAssetsUp(spoke.drawnShares);
  }

  /// @dev Returns the spoke's premium amount for a specified asset.
  function _getSpokePremium(
    Asset storage asset,
    SpokeData storage spoke
  ) internal view returns (uint256) {
    uint256 accruedPremium = asset.toDrawnAssetsUp(spoke.premiumShares) - spoke.premiumOffset;
    return spoke.realizedPremium + accruedPremium;
  }

  /// @dev Spoke with maximum cap have unlimited add capacity.
  function _validateAdd(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 amount,
    address from
  ) internal view {
    require(from != address(this), InvalidAddress());
    require(amount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    uint256 addCap = spoke.addCap;
    require(
      addCap == MAX_ALLOWED_SPOKE_CAP ||
        addCap * MathUtils.uncheckedExp(10, asset.decimals) >=
        asset.toAddedAssetsUp(spoke.addedShares) + amount,
      AddCapExceeded(addCap)
    );
  }

  function _validateRemove(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 amount,
    address to
  ) internal view {
    require(to != address(this), InvalidAddress());
    require(amount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    uint256 removable = asset.toAddedAssetsDown(spoke.addedShares);
    require(amount <= removable, AddedAmountExceeded(removable));
  }

  /// @dev Spoke with maximum cap have unlimited draw capacity.
  function _validateDraw(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 amount,
    address to
  ) internal view {
    require(to != address(this), InvalidAddress());
    require(amount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    uint256 drawCap = spoke.drawCap;
    uint256 owed = _getSpokeDrawn(asset, spoke) + _getSpokePremium(asset, spoke);
    require(
      drawCap == MAX_ALLOWED_SPOKE_CAP ||
        drawCap * MathUtils.uncheckedExp(10, asset.decimals) >= owed + amount + spoke.deficit,
      DrawCapExceeded(drawCap)
    );
  }

  function _validateRestore(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 drawnAmount,
    uint256 premiumAmount,
    address from
  ) internal view {
    require(from != address(this), InvalidAddress());
    require(drawnAmount + premiumAmount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    uint256 drawn = _getSpokeDrawn(asset, spoke);
    uint256 premium = _getSpokePremium(asset, spoke);
    require(drawnAmount <= drawn, SurplusAmountRestored(drawn));
    require(premiumAmount <= premium, SurplusAmountRestored(premium));
  }

  function _validateReportDeficit(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 drawnAmount,
    uint256 premiumAmount
  ) internal view {
    require(spoke.active, SpokeNotActive());
    require(drawnAmount + premiumAmount > 0, InvalidAmount());
    uint256 drawn = _getSpokeDrawn(asset, spoke);
    uint256 premium = _getSpokePremium(asset, spoke);
    require(drawnAmount <= drawn, SurplusDeficitReported(drawn));
    require(premiumAmount <= premium, SurplusDeficitReported(premium));
  }

  function _validateEliminateDeficit(SpokeData storage spoke, uint256 amount) internal view {
    require(spoke.active, SpokeNotActive());
    require(amount > 0, InvalidAmount());
  }

  function _validatePayFeeShares(SpokeData storage senderSpoke, uint256 feeShares) internal view {
    require(senderSpoke.active, SpokeNotActive());
    require(feeShares > 0, InvalidShares());
  }

  function _validateTransferShares(
    Asset storage asset,
    SpokeData storage sender,
    SpokeData storage receiver,
    uint256 shares
  ) internal view {
    require(sender.active && receiver.active, SpokeNotActive());
    require(shares > 0, InvalidShares());
    uint256 addCap = receiver.addCap;
    require(
      addCap == MAX_ALLOWED_SPOKE_CAP ||
        addCap * MathUtils.uncheckedExp(10, asset.decimals) >=
        asset.toAddedAssetsUp(receiver.addedShares + shares),
      AddCapExceeded(addCap)
    );
  }

  function _validateSweep(Asset storage asset, address caller, uint256 amount) internal view {
    // sufficient check to disallow when controller unset
    require(caller == asset.reinvestmentController, OnlyReinvestmentController());
    require(amount > 0 && amount <= asset.liquidity, InvalidAmount());
  }

  function _validateReclaim(Asset storage asset, address caller, uint256 amount) internal view {
    // sufficient check to disallow when controller unset
    require(caller == asset.reinvestmentController, OnlyReinvestmentController());
    require(amount > 0 && amount <= asset.swept, InvalidAmount());
  }
}
