// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {SafeTransferLib} from 'src/dependencies/solady/SafeTransferLib.sol';
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
  using SafeTransferLib for address;
  using SafeCast for uint256;
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using PercentageMath for *;
  using AssetLogic for Asset;
  using MathUtils for *;

  /// @inheritdoc IHub
  uint8 public constant MAX_ALLOWED_UNDERLYING_DECIMALS = 18;

  /// @inheritdoc IHub
  uint8 public constant MIN_ALLOWED_UNDERLYING_DECIMALS = 6;

  /// @inheritdoc IHub
  uint40 public constant MAX_ALLOWED_SPOKE_CAP = type(uint40).max;

  /// @inheritdoc IHub
  uint24 public constant MAX_RISK_PREMIUM_THRESHOLD = type(uint24).max;

  uint256 internal _assetCount;
  mapping(address asset => Asset) internal _assets;
  mapping(address asset => mapping(address spoke => SpokeData)) internal _spokes;
  mapping(address asset => EnumerableSet.AddressSet) internal _assetToSpokes;
  EnumerableSet.AddressSet internal _underlyingSet;

  /// @dev Constructor.
  /// @dev The authority contract must implement the `AccessManaged` interface for access control.
  /// @param authority_ The address of the authority contract which manages permissions.
  constructor(address authority_) AccessManaged(authority_) {
    require(authority_ != address(0), InvalidAddress());
  }

  /// @inheritdoc IHub
  function addAsset(
    address asset,
    uint8 decimals,
    address feeReceiver,
    address irStrategy,
    bytes calldata irData
  ) external restricted {
    require(
      asset != address(0) && feeReceiver != address(0) && irStrategy != address(0),
      InvalidAddress()
    );
    require(
      MIN_ALLOWED_UNDERLYING_DECIMALS <= decimals && decimals <= MAX_ALLOWED_UNDERLYING_DECIMALS,
      InvalidAssetDecimals()
    );
    require(!_underlyingSet.contains(asset), AssetAlreadyListed());

    IBasicInterestRateStrategy(irStrategy).setInterestRateData(asset, irData);
    uint256 drawnRate = IBasicInterestRateStrategy(irStrategy).calculateInterestRate({
      asset: asset,
      liquidity: 0,
      drawn: 0,
      deficit: 0,
      swept: 0
    });

    uint256 drawnIndex = WadRayMath.RAY;
    uint256 lastUpdateTimestamp = block.timestamp;
    _assets[asset] = Asset({
      liquidity: 0,
      deficit: 0,
      swept: 0,
      addedShares: 0,
      drawnShares: 0,
      premiumShares: 0,
      premiumOffset: 0,
      drawnIndex: drawnIndex.toUint120(),
      realizedPremium: 0,
      lastUpdateTimestamp: lastUpdateTimestamp.toUint40(),
      decimals: decimals,
      drawnRate: drawnRate.toUint96(),
      irStrategy: irStrategy,
      realizedFees: 0,
      reinvestmentController: address(0),
      feeReceiver: feeReceiver,
      liquidityFee: 0
    });
    _underlyingSet.add(asset);
    _addFeeReceiver(asset, feeReceiver);

    emit AddAsset(asset, decimals);
    emit UpdateAssetConfig(
      asset,
      AssetConfig({
        feeReceiver: feeReceiver,
        liquidityFee: 0,
        irStrategy: irStrategy,
        reinvestmentController: address(0)
      })
    );
    emit UpdateAsset(asset, drawnIndex, drawnRate, 0);
  }

  /// @inheritdoc IHub
  function updateAssetConfig(
    address asset,
    AssetConfig calldata config,
    bytes calldata irData
  ) external restricted {
    require(_underlyingSet.contains(asset), AssetNotListed());
    Asset storage assetData = _assets[asset];
    assetData.accrue();

    require(config.liquidityFee <= PercentageMath.PERCENTAGE_FACTOR, InvalidLiquidityFee());
    require(config.feeReceiver != address(0) && config.irStrategy != address(0), InvalidAddress());
    require(
      config.reinvestmentController != address(0) || assetData.swept == 0,
      InvalidReinvestmentController()
    );

    if (config.irStrategy != assetData.irStrategy) {
      assetData.irStrategy = config.irStrategy;
      IBasicInterestRateStrategy(config.irStrategy).setInterestRateData(asset, irData);
    } else {
      require(irData.length == 0, InvalidInterestRateStrategy());
    }

    address oldFeeReceiver = assetData.feeReceiver;
    if (oldFeeReceiver != config.feeReceiver) {
      _mintFeeShares(assetData, asset);
      IHub.SpokeConfig memory spokeConfig;
      spokeConfig.active = _spokes[asset][oldFeeReceiver].active;
      spokeConfig.paused = _spokes[asset][oldFeeReceiver].paused;
      _updateSpokeConfig(asset, oldFeeReceiver, spokeConfig);
      assetData.feeReceiver = config.feeReceiver;
      _addFeeReceiver(asset, config.feeReceiver);
    }

    assetData.liquidityFee = config.liquidityFee;
    assetData.reinvestmentController = config.reinvestmentController;

    assetData.updateDrawnRate(asset);

    emit UpdateAssetConfig(asset, config);
  }

  /// @inheritdoc IHub
  function addSpoke(address asset, address spoke, SpokeConfig calldata config) external restricted {
    require(_underlyingSet.contains(asset), AssetNotListed());
    require(spoke != address(0), InvalidAddress());
    _addSpoke(asset, spoke);
    _updateSpokeConfig(asset, spoke, config);
  }

  /// @inheritdoc IHub
  function updateSpokeConfig(
    address asset,
    address spoke,
    SpokeConfig calldata config
  ) external restricted {
    require(_underlyingSet.contains(asset), AssetNotListed());
    require(_assetToSpokes[asset].contains(spoke), SpokeNotListed());
    _updateSpokeConfig(asset, spoke, config);
  }

  /// @inheritdoc IHub
  function setInterestRateData(address asset, bytes calldata irData) external restricted {
    require(_underlyingSet.contains(asset), AssetNotListed());
    Asset storage assetData = _assets[asset];
    assetData.accrue();
    IBasicInterestRateStrategy(assetData.irStrategy).setInterestRateData(asset, irData);
    assetData.updateDrawnRate(asset);
  }

  /// @inheritdoc IHub
  function mintFeeShares(address asset) external restricted returns (uint256) {
    Asset storage assetData = _assets[asset];
    assetData.accrue();
    uint256 feeShares = _mintFeeShares(assetData, asset);
    assetData.updateDrawnRate(asset);
    return feeShares;
  }

  /// @inheritdoc IHubBase
  function add(address asset, uint256 amount) external returns (uint256) {
    Asset storage assetData = _assets[asset];
    SpokeData storage spoke = _spokes[asset][msg.sender];

    assetData.accrue();
    _validateAdd(assetData, spoke, amount);

    uint256 newLiquidity = assetData.liquidity + amount;
    uint120 shares = assetData.toAddedSharesDown(amount).toUint120();
    require(shares > 0, InvalidShares());
    assetData.addedShares += shares;
    spoke.addedShares += shares;
    assetData.liquidity = newLiquidity.toUint120();

    assetData.updateDrawnRate(asset);

    // enforces spoke transfers the correct funds from user to hub
    require(asset.balanceOf(address(this)) >= newLiquidity, InvalidAmountReceived());

    emit Add(asset, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc IHubBase
  function remove(address asset, uint256 amount, address to) external returns (uint256) {
    Asset storage assetData = _assets[asset];
    SpokeData storage spoke = _spokes[asset][msg.sender];

    assetData.accrue();
    _validateRemove(spoke, amount, to);

    uint256 liquidity = assetData.liquidity;
    require(amount <= liquidity, InsufficientLiquidity(liquidity));

    uint120 shares = assetData.toAddedSharesUp(amount).toUint120();
    assetData.addedShares -= shares;
    spoke.addedShares -= shares;
    assetData.liquidity = liquidity.uncheckedSub(amount).toUint120();

    assetData.updateDrawnRate(asset);

    asset.safeTransfer(to, amount);

    emit Remove(asset, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc IHubBase
  function draw(address asset, uint256 amount, address to) external returns (uint256) {
    Asset storage assetData = _assets[asset];
    SpokeData storage spoke = _spokes[asset][msg.sender];

    assetData.accrue();
    _validateDraw(assetData, spoke, amount, to);

    uint256 liquidity = assetData.liquidity;
    require(amount <= liquidity, InsufficientLiquidity(liquidity));

    uint120 drawnShares = assetData.toDrawnSharesUp(amount).toUint120();
    assetData.drawnShares += drawnShares;
    spoke.drawnShares += drawnShares;
    assetData.liquidity = liquidity.uncheckedSub(amount).toUint120();

    assetData.updateDrawnRate(asset);

    asset.safeTransfer(to, amount);

    emit Draw(asset, msg.sender, drawnShares, amount);

    return drawnShares;
  }

  /// @inheritdoc IHubBase
  function restore(
    address asset,
    uint256 drawnAmount,
    uint256 premiumAmount,
    PremiumDelta calldata premiumDelta
  ) external returns (uint256) {
    Asset storage assetData = _assets[asset];
    SpokeData storage spoke = _spokes[asset][msg.sender];

    assetData.accrue();
    _validateRestore(assetData, spoke, drawnAmount, premiumAmount);

    uint120 drawnShares = assetData.toDrawnSharesDown(drawnAmount).toUint120();
    assetData.drawnShares -= drawnShares;
    spoke.drawnShares -= drawnShares;
    _applyPremiumDelta(assetData, spoke, premiumDelta, premiumAmount);
    uint256 newLiquidity = assetData.liquidity + drawnAmount + premiumAmount;
    assetData.liquidity = newLiquidity.toUint120();

    assetData.updateDrawnRate(asset);

    // enforces spoke transfers the correct funds from user to hub
    require(asset.balanceOf(address(this)) >= newLiquidity, InvalidAmountReceived());

    emit Restore(asset, msg.sender, drawnShares, premiumDelta, drawnAmount, premiumAmount);

    return drawnShares;
  }

  /// @inheritdoc IHubBase
  function reportDeficit(
    address asset,
    uint256 drawnAmount,
    uint256 premiumAmount,
    PremiumDelta calldata premiumDelta
  ) external returns (uint256) {
    Asset storage assetData = _assets[asset];
    SpokeData storage spoke = _spokes[asset][msg.sender];

    assetData.accrue();
    _validateReportDeficit(assetData, spoke, drawnAmount, premiumAmount);

    uint120 drawnShares = assetData.toDrawnSharesDown(drawnAmount).toUint120();
    assetData.drawnShares -= drawnShares;
    spoke.drawnShares -= drawnShares;
    _applyPremiumDelta(assetData, spoke, premiumDelta, premiumAmount);
    uint120 deficitAmount = (drawnAmount + premiumAmount).toUint120();
    assetData.deficit += deficitAmount;
    spoke.deficit += deficitAmount;

    assetData.updateDrawnRate(asset);

    emit ReportDeficit(asset, msg.sender, drawnShares, premiumDelta, drawnAmount, premiumAmount);

    return drawnShares;
  }

  /// @inheritdoc IHub
  function eliminateDeficit(
    address asset,
    uint256 amount,
    address spoke
  ) external returns (uint256) {
    Asset storage assetData = _assets[asset];
    SpokeData storage callerSpoke = _spokes[asset][msg.sender];
    SpokeData storage coveredSpoke = _spokes[asset][spoke];

    assetData.accrue();
    _validateEliminateDeficit(callerSpoke, amount);

    uint256 deficit = coveredSpoke.deficit;
    require(amount <= deficit, InvalidAmount());

    uint120 shares = assetData.toAddedSharesUp(amount).toUint120();
    assetData.addedShares -= shares;
    callerSpoke.addedShares -= shares;
    assetData.deficit -= amount.toUint120();
    coveredSpoke.deficit = deficit.uncheckedSub(amount).toUint120();

    assetData.updateDrawnRate(asset);

    emit EliminateDeficit(asset, msg.sender, spoke, shares, amount);

    return shares;
  }

  /// @inheritdoc IHubBase
  function refreshPremium(address asset, PremiumDelta calldata premiumDelta) external {
    Asset storage assetData = _assets[asset];
    SpokeData storage spoke = _spokes[asset][msg.sender];

    assetData.accrue();
    require(spoke.active, SpokeNotActive());
    // no premium change allowed
    _applyPremiumDelta(assetData, spoke, premiumDelta, 0);
    assetData.updateDrawnRate(asset);

    emit RefreshPremium(asset, msg.sender, premiumDelta);
  }

  /// @inheritdoc IHubBase
  function payFeeShares(address asset, uint256 shares) external {
    Asset storage assetData = _assets[asset];
    address feeReceiver = _assets[asset].feeReceiver;
    SpokeData storage receiver = _spokes[asset][feeReceiver];
    SpokeData storage sender = _spokes[asset][msg.sender];

    assetData.accrue();
    _validatePayFeeShares(sender, shares);
    _transferShares(sender, receiver, shares);
    assetData.updateDrawnRate(asset);

    emit TransferShares(asset, msg.sender, feeReceiver, shares);
  }

  /// @inheritdoc IHub
  function transferShares(address asset, uint256 shares, address toSpoke) external {
    Asset storage assetData = _assets[asset];
    SpokeData storage sender = _spokes[asset][msg.sender];
    SpokeData storage receiver = _spokes[asset][toSpoke];

    assetData.accrue();
    _validateTransferShares(assetData, sender, receiver, shares);
    _transferShares(sender, receiver, shares);
    assetData.updateDrawnRate(asset);

    emit TransferShares(asset, msg.sender, toSpoke, shares);
  }

  /// @inheritdoc IHub
  function sweep(address asset, uint256 amount) external {
    require(_underlyingSet.contains(asset), AssetNotListed());
    Asset storage assetData = _assets[asset];

    assetData.accrue();
    _validateSweep(assetData, msg.sender, amount);

    uint256 liquidity = assetData.liquidity;
    require(amount <= liquidity, InsufficientLiquidity(liquidity));

    assetData.liquidity = liquidity.uncheckedSub(amount).toUint120();
    assetData.swept += amount.toUint120();
    assetData.updateDrawnRate(asset);

    asset.safeTransfer(msg.sender, amount);

    emit Sweep(asset, msg.sender, amount);
  }

  /// @inheritdoc IHub
  function reclaim(address asset, uint256 amount) external {
    require(_underlyingSet.contains(asset), AssetNotListed());
    Asset storage assetData = _assets[asset];

    assetData.accrue();
    _validateReclaim(assetData, msg.sender, amount);

    assetData.liquidity += amount.toUint120();
    assetData.swept -= amount.toUint120();
    assetData.updateDrawnRate(asset);

    asset.safeTransferFrom(msg.sender, address(this), amount);

    emit Reclaim(asset, msg.sender, amount);
  }

  /// @inheritdoc IHub
  function getAssetCount() external view returns (uint256) {
    return _assetCount;
  }

  /// @inheritdoc IHubBase
  function previewAddByAssets(address asset, uint256 assets) external view returns (uint256) {
    return _assets[asset].toAddedSharesDown(assets);
  }

  /// @inheritdoc IHubBase
  function previewAddByShares(address asset, uint256 shares) external view returns (uint256) {
    return _assets[asset].toAddedAssetsUp(shares);
  }

  /// @inheritdoc IHubBase
  function previewRemoveByAssets(address asset, uint256 assets) external view returns (uint256) {
    return _assets[asset].toAddedSharesUp(assets);
  }

  /// @inheritdoc IHubBase
  function previewRemoveByShares(address asset, uint256 shares) external view returns (uint256) {
    return _assets[asset].toAddedAssetsDown(shares);
  }

  /// @inheritdoc IHubBase
  function previewDrawByAssets(address asset, uint256 assets) external view returns (uint256) {
    return _assets[asset].toDrawnSharesUp(assets);
  }

  /// @inheritdoc IHubBase
  function previewDrawByShares(address asset, uint256 shares) external view returns (uint256) {
    return _assets[asset].toDrawnAssetsDown(shares);
  }

  /// @inheritdoc IHubBase
  function previewRestoreByAssets(address asset, uint256 assets) external view returns (uint256) {
    return _assets[asset].toDrawnSharesDown(assets);
  }

  /// @inheritdoc IHubBase
  function previewRestoreByShares(address asset, uint256 shares) external view returns (uint256) {
    return _assets[asset].toDrawnAssetsUp(shares);
  }

  /// @inheritdoc IHubBase
  function getAssetDecimals(address asset) external view returns (uint8) {
    return _assets[asset].decimals;
  }

  /// @inheritdoc IHubBase
  function getAssetDrawnIndex(address asset) external view returns (uint256) {
    return _assets[asset].getDrawnIndex();
  }

  /// @inheritdoc IHubBase
  function getAddedAssets(address asset) external view returns (uint256) {
    return _assets[asset].totalAddedAssets();
  }

  /// @inheritdoc IHubBase
  function getAddedShares(address asset) external view returns (uint256) {
    return _assets[asset].addedShares;
  }

  /// @inheritdoc IHubBase
  function getAssetOwed(address asset) external view returns (uint256, uint256) {
    Asset storage assetData = _assets[asset];
    uint256 drawnIndex = assetData.getDrawnIndex();
    return (assetData.drawn(drawnIndex), assetData.premium(drawnIndex));
  }

  /// @inheritdoc IHubBase
  function getAssetTotalOwed(address asset) external view returns (uint256) {
    Asset storage assetData = _assets[asset];
    return assetData.totalOwed(assetData.getDrawnIndex());
  }

  /// @inheritdoc IHubBase
  function getAssetDrawnShares(address asset) external view returns (uint256) {
    return _assets[asset].drawnShares;
  }

  /// @inheritdoc IHubBase
  function getAssetPremiumData(address asset) external view returns (uint256, uint256, uint256) {
    Asset storage assetData = _assets[asset];
    return (assetData.premiumShares, assetData.premiumOffset, assetData.realizedPremium);
  }

  /// @inheritdoc IHubBase
  function getAssetLiquidity(address asset) external view returns (uint256) {
    return _assets[asset].liquidity;
  }

  /// @inheritdoc IHubBase
  function getAssetDeficit(address asset) external view returns (uint256) {
    return _assets[asset].deficit;
  }

  /// @inheritdoc IHub
  function getAsset(address asset) external view returns (Asset memory) {
    return _assets[asset];
  }

  /// @inheritdoc IHub
  function getAssetConfig(address asset) external view returns (AssetConfig memory) {
    Asset storage assetData = _assets[asset];
    return
      AssetConfig({
        feeReceiver: assetData.feeReceiver,
        liquidityFee: assetData.liquidityFee,
        irStrategy: assetData.irStrategy,
        reinvestmentController: assetData.reinvestmentController
      });
  }

  /// @inheritdoc IHub
  function getAssetAccruedFees(address asset) external view returns (uint256) {
    Asset storage assetData = _assets[asset];
    return assetData.realizedFees + assetData.getUnrealizedFees(assetData.getDrawnIndex());
  }

  /// @inheritdoc IHub
  function getAssetSwept(address asset) external view returns (uint256) {
    return _assets[asset].swept;
  }

  /// @inheritdoc IHub
  function getAssetDrawnRate(address asset) external view returns (uint256) {
    return _assets[asset].drawnRate;
  }

  /// @inheritdoc IHub
  function getSpokeCount(address asset) external view returns (uint256) {
    return _assetToSpokes[asset].length();
  }

  /// @inheritdoc IHubBase
  function getSpokeAddedAssets(address asset, address spoke) external view returns (uint256) {
    return _assets[asset].toAddedAssetsDown(_spokes[asset][spoke].addedShares);
  }

  /// @inheritdoc IHubBase
  function getSpokeAddedShares(address asset, address spoke) external view returns (uint256) {
    return _spokes[asset][spoke].addedShares;
  }

  /// @inheritdoc IHubBase
  function getSpokeOwed(address asset, address spoke) external view returns (uint256, uint256) {
    Asset storage assetData = _assets[asset];
    SpokeData storage spokeData = _spokes[asset][spoke];
    return (_getSpokeDrawn(assetData, spokeData), _getSpokePremium(assetData, spokeData));
  }

  /// @inheritdoc IHubBase
  function getSpokeTotalOwed(address asset, address spoke) external view returns (uint256) {
    Asset storage assetData = _assets[asset];
    SpokeData storage spokeData = _spokes[asset][spoke];
    return _getSpokeDrawn(assetData, spokeData) + _getSpokePremium(assetData, spokeData);
  }

  /// @inheritdoc IHubBase
  function getSpokeDrawnShares(address asset, address spoke) external view returns (uint256) {
    return _spokes[asset][spoke].drawnShares;
  }

  /// @inheritdoc IHubBase
  function getSpokePremiumData(
    address asset,
    address spoke
  ) external view returns (uint256, uint256, uint256) {
    SpokeData storage spokeData = _spokes[asset][spoke];
    return (spokeData.premiumShares, spokeData.premiumOffset, spokeData.realizedPremium);
  }

  /// @inheritdoc IHubBase
  function getSpokeDeficit(address asset, address spoke) external view returns (uint256) {
    return _spokes[asset][spoke].deficit;
  }

  /// @inheritdoc IHub
  function isSpokeListed(address asset, address spoke) external view returns (bool) {
    return _assetToSpokes[asset].contains(spoke);
  }

  /// @inheritdoc IHub
  function getSpokeAddress(address asset, uint256 index) external view returns (address) {
    return _assetToSpokes[asset].at(index);
  }

  /// @inheritdoc IHub
  function getSpoke(address asset, address spoke) external view returns (SpokeData memory) {
    return _spokes[asset][spoke];
  }

  /// @inheritdoc IHub
  function isUnderlyingListed(address underlying) external view returns (bool) {
    return _underlyingSet.contains(underlying);
  }

  /// @inheritdoc IHub
  function getUnderlyingAddress(uint256 index) external view returns (address) {
    return _underlyingSet.at(index);
  }

  /// @inheritdoc IHub
  function getSpokeConfig(address asset, address spoke) external view returns (SpokeConfig memory) {
    SpokeData storage spokeData = _spokes[asset][spoke];
    return
      SpokeConfig({
        addCap: spokeData.addCap,
        drawCap: spokeData.drawCap,
        riskPremiumThreshold: spokeData.riskPremiumThreshold,
        active: spokeData.active,
        paused: spokeData.paused
      });
  }

  /// @notice Adds a new spoke to an asset with default feeReceiver configuration (maximum add cap, zero draw cap).
  function _addFeeReceiver(address asset, address feeReceiver) internal {
    _addSpoke(asset, feeReceiver);
    _updateSpokeConfig(
      asset,
      feeReceiver,
      SpokeConfig({
        addCap: MAX_ALLOWED_SPOKE_CAP,
        drawCap: 0,
        riskPremiumThreshold: 0,
        active: true,
        paused: false
      })
    );
  }

  /// @notice Adds a spoke to an assetData.
  /// @dev Reverts with `SpokeAlreadyListed` if spoke is already listed for the given assetData.
  function _addSpoke(address asset, address spoke) internal {
    require(_assetToSpokes[asset].add(spoke), SpokeAlreadyListed());
    emit AddSpoke(asset, spoke);
  }

  function _updateSpokeConfig(address asset, address spoke, SpokeConfig memory config) internal {
    SpokeData storage spokeData = _spokes[asset][spoke];
    spokeData.addCap = config.addCap;
    spokeData.drawCap = config.drawCap;
    spokeData.riskPremiumThreshold = config.riskPremiumThreshold;
    spokeData.active = config.active;
    spokeData.paused = config.paused;
    emit UpdateSpokeConfig(asset, spoke, config);
  }

  /// @dev Receiver `addCap` is validated in `_validateTransferShares`.
  function _transferShares(
    SpokeData storage sender,
    SpokeData storage receiver,
    uint256 shares
  ) internal {
    sender.addedShares -= shares.toUint120();
    receiver.addedShares += shares.toUint120();
  }

  /// @dev Applies premium deltas on asset & spoke premium owed.
  /// @dev Checks premium owed does not increase by more than `premiumAmount` + 2 wei (due to opposite rounding on premium shares and offset).
  /// @dev Checks updated risk premium is within allowed threshold.
  function _applyPremiumDelta(
    Asset storage assetData,
    SpokeData storage spoke,
    PremiumDelta calldata premium,
    uint256 premiumAmount
  ) internal {
    uint256 drawnIndex = assetData.getDrawnIndex();

    // asset premium change
    (
      assetData.premiumShares,
      assetData.premiumOffset,
      assetData.realizedPremium
    ) = _validateApplyPremiumDelta(
      drawnIndex,
      assetData.premiumShares,
      assetData.premiumOffset,
      assetData.realizedPremium,
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

    uint24 riskPremiumThreshold = spoke.riskPremiumThreshold;
    require(
      riskPremiumThreshold == MAX_RISK_PREMIUM_THRESHOLD ||
        spoke.premiumShares <= spoke.drawnShares.percentMulUp(riskPremiumThreshold),
      InvalidPremiumChange()
    );
  }

  function _mintFeeShares(Asset storage assetData, address asset) internal returns (uint256) {
    uint256 fees = assetData.realizedFees;
    uint120 shares = assetData.toAddedSharesDown(fees).toUint120();
    if (shares == 0) {
      return 0;
    }

    address feeReceiver = assetData.feeReceiver;
    SpokeData storage feeReceiverSpoke = _spokes[asset][feeReceiver];
    require(feeReceiverSpoke.active, SpokeNotActive());

    assetData.addedShares += shares;
    feeReceiverSpoke.addedShares += shares;
    assetData.realizedFees = 0;
    emit MintFeeShares(asset, feeReceiver, shares, fees);

    return shares;
  }

  /// @dev Returns the spoke's drawn amount for a specified assetData.
  function _getSpokeDrawn(
    Asset storage assetData,
    SpokeData storage spoke
  ) internal view returns (uint256) {
    return assetData.toDrawnAssetsUp(spoke.drawnShares);
  }

  /// @dev Returns the spoke's premium amount for a specified assetData.
  function _getSpokePremium(
    Asset storage assetData,
    SpokeData storage spoke
  ) internal view returns (uint256) {
    uint256 accruedPremium = assetData.toDrawnAssetsUp(spoke.premiumShares) - spoke.premiumOffset;
    return spoke.realizedPremium + accruedPremium;
  }

  /// @dev Spoke with maximum cap have unlimited add capacity.
  function _validateAdd(
    Asset storage assetData,
    SpokeData storage spoke,
    uint256 amount
  ) internal view {
    require(amount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    require(!spoke.paused, SpokePaused());
    uint256 addCap = spoke.addCap;
    require(
      addCap == MAX_ALLOWED_SPOKE_CAP ||
        addCap * MathUtils.uncheckedExp(10, assetData.decimals) >=
        assetData.toAddedAssetsUp(spoke.addedShares) + amount,
      AddCapExceeded(addCap)
    );
  }

  function _validateRemove(SpokeData storage spoke, uint256 amount, address to) internal view {
    require(to != address(this), InvalidAddress());
    require(amount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    require(!spoke.paused, SpokePaused());
  }

  /// @dev Spoke with maximum cap have unlimited draw capacity.
  function _validateDraw(
    Asset storage assetData,
    SpokeData storage spoke,
    uint256 amount,
    address to
  ) internal view {
    require(to != address(this), InvalidAddress());
    require(amount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    require(!spoke.paused, SpokePaused());
    uint256 drawCap = spoke.drawCap;
    uint256 owed = _getSpokeDrawn(assetData, spoke) + _getSpokePremium(assetData, spoke);
    require(
      drawCap == MAX_ALLOWED_SPOKE_CAP ||
        drawCap * MathUtils.uncheckedExp(10, assetData.decimals) >= owed + amount + spoke.deficit,
      DrawCapExceeded(drawCap)
    );
  }

  function _validateRestore(
    Asset storage assetData,
    SpokeData storage spoke,
    uint256 drawnAmount,
    uint256 premiumAmount
  ) internal view {
    require(drawnAmount + premiumAmount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    require(!spoke.paused, SpokePaused());
    uint256 drawn = _getSpokeDrawn(assetData, spoke);
    uint256 premium = _getSpokePremium(assetData, spoke);
    require(drawnAmount <= drawn, SurplusAmountRestored(drawn));
    require(premiumAmount <= premium, SurplusAmountRestored(premium));
  }

  function _validateReportDeficit(
    Asset storage assetData,
    SpokeData storage spoke,
    uint256 drawnAmount,
    uint256 premiumAmount
  ) internal view {
    require(spoke.active, SpokeNotActive());
    require(!spoke.paused, SpokePaused());
    require(drawnAmount + premiumAmount > 0, InvalidAmount());
    uint256 drawn = _getSpokeDrawn(assetData, spoke);
    uint256 premium = _getSpokePremium(assetData, spoke);
    require(drawnAmount <= drawn, SurplusDeficitReported(drawn));
    require(premiumAmount <= premium, SurplusDeficitReported(premium));
  }

  function _validateEliminateDeficit(SpokeData storage spoke, uint256 amount) internal view {
    require(spoke.active, SpokeNotActive());
    require(amount > 0, InvalidAmount());
  }

  function _validatePayFeeShares(SpokeData storage senderSpoke, uint256 feeShares) internal view {
    require(senderSpoke.active, SpokeNotActive());
    require(!senderSpoke.paused, SpokePaused());
    require(feeShares > 0, InvalidShares());
  }

  function _validateTransferShares(
    Asset storage assetData,
    SpokeData storage sender,
    SpokeData storage receiver,
    uint256 shares
  ) internal view {
    require(sender.active && receiver.active, SpokeNotActive());
    require(!sender.paused && !receiver.paused, SpokePaused());
    require(shares > 0, InvalidShares());
    uint256 addCap = receiver.addCap;
    require(
      addCap == MAX_ALLOWED_SPOKE_CAP ||
        addCap * MathUtils.uncheckedExp(10, assetData.decimals) >=
        assetData.toAddedAssetsUp(receiver.addedShares + shares),
      AddCapExceeded(addCap)
    );
  }

  function _validateSweep(Asset storage assetData, address caller, uint256 amount) internal view {
    // sufficient check to disallow when controller unset
    require(caller == assetData.reinvestmentController, OnlyReinvestmentController());
    require(amount > 0, InvalidAmount());
  }

  function _validateReclaim(Asset storage assetData, address caller, uint256 amount) internal view {
    // sufficient check to disallow when controller unset
    require(caller == assetData.reinvestmentController, OnlyReinvestmentController());
    require(amount > 0, InvalidAmount());
  }

  /// @dev Validates applied premium delta for given premium data and returns updated premium data.
  function _validateApplyPremiumDelta(
    uint256 drawnIndex,
    uint256 premiumShares,
    uint256 premiumOffset,
    uint256 realizedPremium,
    PremiumDelta calldata premium,
    uint256 premiumAmount
  ) internal pure returns (uint120, uint120, uint120) {
    uint256 premiumBefore = premiumShares.rayMulUp(drawnIndex) - premiumOffset;
    premiumBefore += realizedPremium;

    premiumShares = premiumShares.add(premium.sharesDelta);
    premiumOffset = premiumOffset.add(premium.offsetDelta);
    realizedPremium = realizedPremium.add(premium.realizedDelta);

    uint256 premiumAfter = premiumShares.rayMulUp(drawnIndex) - premiumOffset;
    premiumAfter += realizedPremium;
    // can increase due to precision loss on premium (drawn unchanged)
    require(premiumAfter + premiumAmount - premiumBefore <= 2, InvalidPremiumChange());
    return (premiumShares.toUint120(), premiumOffset.toUint120(), realizedPremium.toUint120());
  }
}
