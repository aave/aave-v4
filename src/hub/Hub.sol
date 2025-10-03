// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

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
  uint56 public constant MAX_ALLOWED_SPOKE_CAP = type(uint56).max;

  uint256 internal _assetCount;
  mapping(uint256 assetId => Asset) internal _assets;
  mapping(uint256 assetId => mapping(address spoke => SpokeData)) internal _spokes;
  mapping(uint256 assetId => EnumerableSet.AddressSet) internal _assetToSpokes;

  /**
   * @dev Constructor.
   * @dev The authority contract must implement the AccessManaged interface for access control.
   * @param authority_ The address of the authority contract which manages permissions.
   */
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
    require(decimals <= MAX_ALLOWED_UNDERLYING_DECIMALS, InvalidAssetDecimals());

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
      lastUpdateTimestamp: lastUpdateTimestamp.toUint40(),
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
    emit UpdateAsset(assetId, drawnIndex, drawnRate, lastUpdateTimestamp);

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
    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);

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
      require(irData.length == 0, InvalidInterestRateStrategyUpdate());
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

  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    SpokeConfig calldata config
  ) external restricted {
    require(_assetToSpokes[assetId].contains(spoke), SpokeNotListed());
    _updateSpokeConfig(assetId, spoke, config);
  }

  /// @inheritdoc IHub
  function setInterestRateData(uint256 assetId, bytes calldata irData) external restricted {
    Asset storage asset = _assets[assetId];
    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    IBasicInterestRateStrategy(asset.irStrategy).setInterestRateData(assetId, irData);
    asset.updateDrawnRate(assetId);
  }

  /// @inheritdoc IHubBase
  function add(uint256 assetId, uint256 amount, address from) external returns (uint256) {
    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    _validateAdd(asset, spoke, assetId, amount, from);

    uint128 shares = previewAddByAssets(assetId, amount).toUint128();
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

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    _validateRemove(spoke, assetId, amount, to);
    uint256 liquidity = asset.liquidity;
    require(amount <= liquidity, InsufficientLiquidity(liquidity));

    uint128 shares = previewRemoveByAssets(assetId, amount).toUint128(); // non zero since we round up
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

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    _validateDraw(asset, spoke, assetId, amount, to);
    uint256 liquidity = asset.liquidity;
    require(amount <= liquidity, InsufficientLiquidity(liquidity));

    uint128 drawnShares = previewDrawByAssets(assetId, amount).toUint128(); // non zero since we round up
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

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    _validateRestore(spoke, assetId, drawnAmount, premiumAmount, from);

    uint128 drawnShares = previewRestoreByAssets(assetId, drawnAmount).toUint128();
    asset.drawnShares -= drawnShares;
    spoke.drawnShares -= drawnShares;
    _applyPremiumDelta(assetId, asset, spoke, premiumDelta, premiumAmount);
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

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);

    _validateReportDeficit(spoke, assetId, drawnAmount, premiumAmount);

    uint128 drawnShares = previewRestoreByAssets(assetId, drawnAmount).toUint128();
    asset.drawnShares -= drawnShares;
    spoke.drawnShares -= drawnShares;
    _applyPremiumDelta(assetId, asset, spoke, premiumDelta, premiumAmount);
    asset.deficit += (drawnAmount + premiumAmount).toUint128();

    asset.updateDrawnRate(assetId);

    emit ReportDeficit(assetId, msg.sender, drawnShares, premiumDelta, drawnAmount, premiumAmount);

    return drawnShares;
  }

  /// @inheritdoc IHub
  function eliminateDeficit(uint256 assetId, uint256 amount) external returns (uint256) {
    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    _validateEliminateDeficit(spoke, amount);
    uint256 deficit = asset.deficit;
    require(amount <= deficit, InvalidAmount());

    uint128 shares = previewRemoveByAssets(assetId, amount).toUint128();
    asset.addedShares -= shares;
    spoke.addedShares -= shares;
    asset.deficit = deficit.uncheckedSub(amount).toUint128();

    asset.updateDrawnRate(assetId);

    emit EliminateDeficit(assetId, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc IHubBase
  function refreshPremium(uint256 assetId, PremiumDelta calldata premiumDelta) external {
    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    require(spoke.active, SpokeNotActive());
    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    // no premium change allowed
    _applyPremiumDelta(assetId, asset, spoke, premiumDelta, 0);

    emit RefreshPremium(assetId, msg.sender, premiumDelta);
  }

  /// @inheritdoc IHubBase
  function payFeeShares(uint256 assetId, uint256 shares) external {
    SpokeData storage sender = _spokes[assetId][msg.sender];
    address feeReceiver = _assets[assetId].feeReceiver;
    Asset storage asset = _assets[assetId];
    SpokeData storage receiver = _spokes[assetId][feeReceiver];

    asset.accrue(assetId, receiver);
    _validatePayFeeShares(sender, shares);
    _transferShares(sender, receiver, shares);
    asset.updateDrawnRate(assetId);

    emit TransferShares(assetId, msg.sender, feeReceiver, shares);
  }

  /// @inheritdoc IHub
  function transferShares(uint256 assetId, uint256 shares, address toSpoke) external {
    SpokeData storage sender = _spokes[assetId][msg.sender];
    SpokeData storage receiver = _spokes[assetId][toSpoke];
    Asset storage asset = _assets[assetId];

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    _validateTransferShares(asset, sender, receiver, assetId, shares);
    _transferShares(sender, receiver, shares);
    asset.updateDrawnRate(assetId);

    emit TransferShares(assetId, msg.sender, toSpoke, shares);
  }

  /// @inheritdoc IHub
  function sweep(uint256 assetId, uint256 amount) external {
    Asset storage asset = _assets[assetId];

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    _validateSweep(asset, msg.sender, amount);

    asset.liquidity -= amount.toUint128();
    asset.swept += amount.toUint128();
    asset.updateDrawnRate(assetId);

    IERC20(asset.underlying).safeTransfer(msg.sender, amount);

    emit Sweep(assetId, msg.sender, amount);
  }

  /// @inheritdoc IHub
  function reclaim(uint256 assetId, uint256 amount) external {
    Asset storage asset = _assets[assetId];

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    _validateReclaim(asset, msg.sender, amount);

    asset.liquidity += amount.toUint128();
    asset.swept -= amount.toUint128();
    asset.updateDrawnRate(assetId);

    IERC20(asset.underlying).safeTransferFrom(msg.sender, address(this), amount);

    emit Reclaim(assetId, msg.sender, amount);
  }

  /// @inheritdoc IHub
  function getAssetCount() external view override returns (uint256) {
    return _assetCount;
  }

  /// @inheritdoc IHub
  function getAsset(uint256 assetId) external view returns (Asset memory) {
    return _assets[assetId];
  }

  /// @inheritdoc IHubBase
  function getAssetUnderlyingAndDecimals(uint256 assetId) external view returns (address, uint8) {
    Asset storage asset = _assets[assetId];
    return (asset.underlying, asset.decimals);
  }

  /// @inheritdoc IHub
  function getSpokeCount(uint256 assetId) external view returns (uint256) {
    return _assetToSpokes[assetId].length();
  }

  /// @inheritdoc IHub
  function getSpokeAddress(uint256 assetId, uint256 index) external view returns (address) {
    return _assetToSpokes[assetId].at(index);
  }

  /// @inheritdoc IHub
  function isSpokeListed(uint256 assetId, address spoke) external view returns (bool) {
    return _assetToSpokes[assetId].contains(spoke);
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

  /// @inheritdoc IHubBase
  function previewAddByAssets(uint256 assetId, uint256 assets) public view returns (uint256) {
    return _assets[assetId].toAddedSharesDown(assets);
  }

  /// @inheritdoc IHubBase
  function previewAddByShares(uint256 assetId, uint256 shares) public view returns (uint256) {
    return _assets[assetId].toAddedAssetsUp(shares);
  }

  /// @inheritdoc IHubBase
  function previewRemoveByAssets(uint256 assetId, uint256 assets) public view returns (uint256) {
    return _assets[assetId].toAddedSharesUp(assets);
  }

  /// @inheritdoc IHubBase
  function previewRemoveByShares(uint256 assetId, uint256 shares) public view returns (uint256) {
    return _assets[assetId].toAddedAssetsDown(shares);
  }

  /// @inheritdoc IHubBase
  function previewDrawByAssets(uint256 assetId, uint256 assets) public view returns (uint256) {
    return _assets[assetId].toDrawnSharesUp(assets);
  }

  /// @inheritdoc IHubBase
  function previewDrawByShares(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toDrawnAssetsDown(shares);
  }

  /// @inheritdoc IHubBase
  function previewRestoreByAssets(uint256 assetId, uint256 assets) public view returns (uint256) {
    return _assets[assetId].toDrawnSharesDown(assets);
  }

  /// @inheritdoc IHubBase
  function previewRestoreByShares(uint256 assetId, uint256 shares) public view returns (uint256) {
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
    return _assets[assetId].toDrawnSharesDown(assets);
  }

  /// @inheritdoc IHub
  function getAssetDrawnIndex(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].getDrawnIndex();
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
  function getSpokeOwed(uint256 assetId, address spoke) external view returns (uint256, uint256) {
    SpokeData storage spokeData = _spokes[assetId][spoke];
    return (_getSpokeDrawn(spokeData, assetId), _getSpokePremium(spokeData, assetId));
  }

  /// @inheritdoc IHubBase
  function getSpokeTotalOwed(uint256 assetId, address spoke) external view returns (uint256) {
    SpokeData storage spokeData = _spokes[assetId][spoke];
    return _getSpokeDrawn(spokeData, assetId) + _getSpokePremium(spokeData, assetId);
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

  function getAssetDrawnRate(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].drawnRate;
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
  function getSpokeAddedAssets(uint256 assetId, address spoke) external view returns (uint256) {
    Asset storage asset = _assets[assetId];
    uint256 unrealizedFeeShares;
    if (spoke == asset.feeReceiver) unrealizedFeeShares = asset.unrealizedFeeShares();
    return
      previewRemoveByShares(assetId, _spokes[assetId][spoke].addedShares + unrealizedFeeShares);
  }

  /// @inheritdoc IHubBase
  function getSpokeAddedShares(uint256 assetId, address spoke) external view returns (uint256) {
    Asset storage asset = _assets[assetId];
    if (spoke == asset.feeReceiver) {
      return _spokes[assetId][spoke].addedShares + asset.unrealizedFeeShares();
    }
    return _spokes[assetId][spoke].addedShares;
  }

  function getLiquidity(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].liquidity;
  }

  function getDeficit(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].deficit;
  }

  /// @inheritdoc IHub
  function getSwept(uint256 assetId) external view override returns (uint256) {
    return _assets[assetId].swept;
  }

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

  function _updateSpokeConfig(uint256 assetId, address spoke, SpokeConfig memory config) internal {
    SpokeData storage spokeData = _spokes[assetId][spoke];
    spokeData.active = config.active;
    spokeData.addCap = config.addCap;
    spokeData.drawCap = config.drawCap;
    emit UpdateSpokeConfig(assetId, spoke, config);
  }

  /**
   * @dev Applies premium deltas on asset and spoke owed, and validates that total premium
   * and spoke premium cannot decrease by more than `premiumAmount`.
   */
  function _applyPremiumDelta(
    uint256 assetId,
    Asset storage asset,
    SpokeData storage spoke,
    PremiumDelta calldata premium,
    uint256 premiumAmount
  ) internal {
    uint256 assetPremiumBefore = asset.premium();
    uint256 spokePremiumBefore = _getSpokePremium(spoke, assetId);

    asset.premiumShares = asset.premiumShares.add(premium.sharesDelta).toUint128();
    asset.premiumOffset = asset.premiumOffset.add(premium.offsetDelta).toUint128();
    asset.realizedPremium = asset.realizedPremium.add(premium.realizedDelta).toUint128();

    spoke.premiumShares = spoke.premiumShares.add(premium.sharesDelta).toUint128();
    spoke.premiumOffset = spoke.premiumOffset.add(premium.offsetDelta).toUint128();
    spoke.realizedPremium = spoke.realizedPremium.add(premium.realizedDelta).toUint128();

    // can increase due to precision loss on premium (drawn unchanged)
    require(asset.premium() + premiumAmount - assetPremiumBefore <= 2, InvalidPremiumChange());
    uint256 spokePremiumAfter = _getSpokePremium(spoke, assetId);
    require(spokePremiumAfter + premiumAmount - spokePremiumBefore <= 2, InvalidPremiumChange());
  }

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

  function _getSpokeDrawn(
    SpokeData storage spoke,
    uint256 assetId
  ) internal view returns (uint256) {
    return previewRestoreByShares(assetId, spoke.drawnShares);
  }

  function _getSpokePremium(
    SpokeData storage spoke,
    uint256 assetId
  ) internal view returns (uint256) {
    uint256 accruedPremium = previewRestoreByShares(assetId, spoke.premiumShares) -
      spoke.premiumOffset;
    return spoke.realizedPremium + accruedPremium;
  }

  function _validateAdd(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 assetId,
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
        previewAddByShares(assetId, spoke.addedShares) + amount,
      AddCapExceeded(addCap)
    );
  }

  function _validateRemove(
    SpokeData storage spoke,
    uint256 assetId,
    uint256 amount,
    address to
  ) internal view {
    require(to != address(this), InvalidAddress());
    require(amount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    uint256 removable = previewRemoveByShares(assetId, spoke.addedShares);
    require(amount <= removable, AddedAmountExceeded(removable));
  }

  function _validateDraw(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 assetId,
    uint256 amount,
    address to
  ) internal view {
    require(to != address(this), InvalidAddress());
    require(amount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    uint256 drawCap = spoke.drawCap;
    uint256 drawn = _getSpokeDrawn(spoke, assetId);
    uint256 premium = _getSpokePremium(spoke, assetId);
    require(
      drawCap == MAX_ALLOWED_SPOKE_CAP ||
        drawCap * MathUtils.uncheckedExp(10, asset.decimals) >= drawn + premium + amount,
      DrawCapExceeded(drawCap)
    );
  }

  function _validateRestore(
    SpokeData storage spoke,
    uint256 assetId,
    uint256 drawnAmount,
    uint256 premiumAmount,
    address from
  ) internal view {
    require(from != address(this), InvalidAddress());
    require(drawnAmount + premiumAmount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    uint256 drawn = _getSpokeDrawn(spoke, assetId);
    uint256 premium = _getSpokePremium(spoke, assetId);
    require(drawnAmount <= drawn, SurplusAmountRestored(drawn));
    require(premiumAmount <= premium, SurplusAmountRestored(premium));
  }

  function _validateReportDeficit(
    SpokeData storage spoke,
    uint256 assetId,
    uint256 drawnAmount,
    uint256 premiumAmount
  ) internal view {
    require(spoke.active, SpokeNotActive());
    require(drawnAmount + premiumAmount > 0, InvalidAmount());
    uint256 drawn = _getSpokeDrawn(spoke, assetId);
    uint256 premium = _getSpokePremium(spoke, assetId);
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
    uint256 assetId,
    uint256 shares
  ) internal view {
    require(sender.active && receiver.active, SpokeNotActive());
    require(shares > 0, InvalidShares());
    uint256 addCap = receiver.addCap;
    require(
      addCap == MAX_ALLOWED_SPOKE_CAP ||
        addCap * MathUtils.uncheckedExp(10, asset.decimals) >=
        previewAddByShares(assetId, receiver.addedShares + shares),
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

  function _addSpoke(uint256 assetId, address spoke) internal {
    require(_assetToSpokes[assetId].add(spoke), SpokeAlreadyListed());
    emit AddSpoke(assetId, spoke);
  }

  function _addFeeReceiver(uint256 assetId, address feeReceiver) internal {
    _addSpoke(assetId, feeReceiver);
    _updateSpokeConfig(
      assetId,
      feeReceiver,
      SpokeConfig({addCap: MAX_ALLOWED_SPOKE_CAP, drawCap: 0, active: true})
    );
  }
}
