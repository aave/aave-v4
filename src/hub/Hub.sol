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
  mapping(address underlying => Asset) internal _assets;
  mapping(address underlying => mapping(address spoke => SpokeData)) internal _spokes;
  mapping(address underlying => EnumerableSet.AddressSet) internal _assetToSpokes;
  EnumerableSet.AddressSet internal _underlyingSet;

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
  ) external restricted {
    require(
      underlying != address(0) && feeReceiver != address(0) && irStrategy != address(0),
      InvalidAddress()
    );
    require(
      MIN_ALLOWED_UNDERLYING_DECIMALS <= decimals && decimals <= MAX_ALLOWED_UNDERLYING_DECIMALS,
      InvalidAssetDecimals()
    );
    require(!_underlyingSet.contains(underlying), AssetAlreadyListed());

    IBasicInterestRateStrategy(irStrategy).setInterestRateData(underlying, irData);
    uint256 drawnRate = IBasicInterestRateStrategy(irStrategy).calculateInterestRate({
      underlying: underlying,
      liquidity: 0,
      drawn: 0,
      deficit: 0,
      swept: 0
    });

    uint256 drawnIndex = WadRayMath.RAY;
    uint256 lastUpdateTimestamp = block.timestamp;
    _assets[underlying] = Asset({
      liquidity: 0,
      deficit: 0,
      swept: 0,
      addedShares: 0,
      drawnShares: 0,
      premiumShares: 0,
      premiumOffset: 0,
      drawnIndex: drawnIndex.toUint120(),
      realizedPremium: 0,
      underlying: underlying,
      lastUpdateTimestamp: lastUpdateTimestamp.toUint40(),
      decimals: decimals,
      drawnRate: drawnRate.toUint96(),
      irStrategy: irStrategy,
      realizedFees: 0,
      reinvestmentController: address(0),
      feeReceiver: feeReceiver,
      liquidityFee: 0
    });
    _underlyingSet.add(underlying);
    _addFeeReceiver(underlying, feeReceiver);

    emit AddAsset(underlying, decimals);
    emit UpdateAssetConfig(
      underlying,
      AssetConfig({
        feeReceiver: feeReceiver,
        liquidityFee: 0,
        irStrategy: irStrategy,
        reinvestmentController: address(0)
      })
    );
    emit UpdateAsset(underlying, drawnIndex, drawnRate, 0);
  }

  /// @inheritdoc IHub
  function updateAssetConfig(
    address underlying,
    AssetConfig calldata config,
    bytes calldata irData
  ) external restricted {
    Asset storage asset = _assets[underlying];
    asset.accrue();

    require(config.liquidityFee <= PercentageMath.PERCENTAGE_FACTOR, InvalidLiquidityFee());
    require(config.feeReceiver != address(0) && config.irStrategy != address(0), InvalidAddress());
    require(
      config.reinvestmentController != address(0) || asset.swept == 0,
      InvalidReinvestmentController()
    );

    if (config.irStrategy != asset.irStrategy) {
      asset.irStrategy = config.irStrategy;
      IBasicInterestRateStrategy(config.irStrategy).setInterestRateData(underlying, irData);
    } else {
      require(irData.length == 0, InvalidInterestRateStrategy());
    }

    address oldFeeReceiver = asset.feeReceiver;
    if (oldFeeReceiver != config.feeReceiver) {
      _mintFeeShares(asset, underlying);
      IHub.SpokeConfig memory spokeConfig;
      spokeConfig.active = _spokes[underlying][oldFeeReceiver].active;
      spokeConfig.paused = _spokes[underlying][oldFeeReceiver].paused;
      _updateSpokeConfig(underlying, oldFeeReceiver, spokeConfig);
      asset.feeReceiver = config.feeReceiver;
      _addFeeReceiver(underlying, config.feeReceiver);
    }

    asset.liquidityFee = config.liquidityFee;
    asset.reinvestmentController = config.reinvestmentController;

    asset.updateDrawnRate(underlying);

    emit UpdateAssetConfig(underlying, config);
  }

  /// @inheritdoc IHub
  function addSpoke(
    address underlying,
    address spoke,
    SpokeConfig calldata config
  ) external restricted {
    require(spoke != address(0), InvalidAddress());
    _addSpoke(underlying, spoke);
    _updateSpokeConfig(underlying, spoke, config);
  }

  /// @inheritdoc IHub
  function updateSpokeConfig(
    address underlying,
    address spoke,
    SpokeConfig calldata config
  ) external restricted {
    require(_assetToSpokes[underlying].contains(spoke), SpokeNotListed());
    _updateSpokeConfig(underlying, spoke, config);
  }

  /// @inheritdoc IHub
  function setInterestRateData(address underlying, bytes calldata irData) external restricted {
    Asset storage asset = _assets[underlying];
    asset.accrue();
    IBasicInterestRateStrategy(asset.irStrategy).setInterestRateData(underlying, irData);
    asset.updateDrawnRate(underlying);
  }

  /// @inheritdoc IHub
  function mintFeeShares(address underlying) external restricted returns (uint256) {
    Asset storage asset = _assets[underlying];
    asset.accrue();
    uint256 feeShares = _mintFeeShares(asset, underlying);
    asset.updateDrawnRate(underlying);
    return feeShares;
  }

  /// @inheritdoc IHubBase
  function add(address underlying, uint256 amount) external returns (uint256) {
    Asset storage asset = _assets[underlying];
    SpokeData storage spoke = _spokes[underlying][msg.sender];

    asset.accrue();
    _validateAdd(asset, spoke, amount);

    uint256 newLiquidity = asset.liquidity + amount;
    uint120 shares = asset.toAddedSharesDown(amount).toUint120();
    require(shares > 0, InvalidShares());
    asset.addedShares += shares;
    spoke.addedShares += shares;
    asset.liquidity = newLiquidity.toUint120();

    asset.updateDrawnRate(underlying);

    // enforces spoke transfers the correct funds from user to hub
    require(underlying.balanceOf(address(this)) >= newLiquidity, InvalidAmountReceived());

    emit Add(underlying, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc IHubBase
  function remove(address underlying, uint256 amount, address to) external returns (uint256) {
    Asset storage asset = _assets[underlying];
    SpokeData storage spoke = _spokes[underlying][msg.sender];

    asset.accrue();
    _validateRemove(spoke, amount, to);

    uint256 liquidity = asset.liquidity;
    require(amount <= liquidity, InsufficientLiquidity(liquidity));

    uint120 shares = asset.toAddedSharesUp(amount).toUint120();
    asset.addedShares -= shares;
    spoke.addedShares -= shares;
    asset.liquidity = liquidity.uncheckedSub(amount).toUint120();

    asset.updateDrawnRate(underlying);

    underlying.safeTransfer(to, amount);

    emit Remove(underlying, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc IHubBase
  function draw(address underlying, uint256 amount, address to) external returns (uint256) {
    Asset storage asset = _assets[underlying];
    SpokeData storage spoke = _spokes[underlying][msg.sender];

    asset.accrue();
    _validateDraw(asset, spoke, amount, to);

    uint256 liquidity = asset.liquidity;
    require(amount <= liquidity, InsufficientLiquidity(liquidity));

    uint120 drawnShares = asset.toDrawnSharesUp(amount).toUint120();
    asset.drawnShares += drawnShares;
    spoke.drawnShares += drawnShares;
    asset.liquidity = liquidity.uncheckedSub(amount).toUint120();

    asset.updateDrawnRate(underlying);

    underlying.safeTransfer(to, amount);

    emit Draw(underlying, msg.sender, drawnShares, amount);

    return drawnShares;
  }

  /// @inheritdoc IHubBase
  function restore(
    address underlying,
    uint256 drawnAmount,
    uint256 premiumAmount,
    PremiumDelta calldata premiumDelta
  ) external returns (uint256) {
    Asset storage asset = _assets[underlying];
    SpokeData storage spoke = _spokes[underlying][msg.sender];

    asset.accrue();
    _validateRestore(asset, spoke, drawnAmount, premiumAmount);

    uint120 drawnShares = asset.toDrawnSharesDown(drawnAmount).toUint120();
    asset.drawnShares -= drawnShares;
    spoke.drawnShares -= drawnShares;
    _applyPremiumDelta(asset, spoke, premiumDelta, premiumAmount);
    uint256 newLiquidity = asset.liquidity + drawnAmount + premiumAmount;
    asset.liquidity = newLiquidity.toUint120();

    asset.updateDrawnRate(underlying);

    // enforces spoke transfers the correct funds from user to hub
    require(underlying.balanceOf(address(this)) >= newLiquidity, InvalidAmountReceived());

    emit Restore(underlying, msg.sender, drawnShares, premiumDelta, drawnAmount, premiumAmount);

    return drawnShares;
  }

  /// @inheritdoc IHubBase
  function reportDeficit(
    address underlying,
    uint256 drawnAmount,
    uint256 premiumAmount,
    PremiumDelta calldata premiumDelta
  ) external returns (uint256) {
    Asset storage asset = _assets[underlying];
    SpokeData storage spoke = _spokes[underlying][msg.sender];

    asset.accrue();
    _validateReportDeficit(asset, spoke, drawnAmount, premiumAmount);

    uint120 drawnShares = asset.toDrawnSharesDown(drawnAmount).toUint120();
    asset.drawnShares -= drawnShares;
    spoke.drawnShares -= drawnShares;
    _applyPremiumDelta(asset, spoke, premiumDelta, premiumAmount);
    uint120 deficitAmount = (drawnAmount + premiumAmount).toUint120();
    asset.deficit += deficitAmount;
    spoke.deficit += deficitAmount;

    asset.updateDrawnRate(underlying);

    emit ReportDeficit(
      underlying,
      msg.sender,
      drawnShares,
      premiumDelta,
      drawnAmount,
      premiumAmount
    );

    return drawnShares;
  }

  /// @inheritdoc IHub
  function eliminateDeficit(
    address underlying,
    uint256 amount,
    address spoke
  ) external returns (uint256) {
    Asset storage asset = _assets[underlying];
    SpokeData storage callerSpoke = _spokes[underlying][msg.sender];
    SpokeData storage coveredSpoke = _spokes[underlying][spoke];

    asset.accrue();
    _validateEliminateDeficit(callerSpoke, amount);

    uint256 deficit = coveredSpoke.deficit;
    require(amount <= deficit, InvalidAmount());

    uint120 shares = asset.toAddedSharesUp(amount).toUint120();
    asset.addedShares -= shares;
    callerSpoke.addedShares -= shares;
    asset.deficit -= amount.toUint120();
    coveredSpoke.deficit = deficit.uncheckedSub(amount).toUint120();

    asset.updateDrawnRate(underlying);

    emit EliminateDeficit(underlying, msg.sender, spoke, shares, amount);

    return shares;
  }

  /// @inheritdoc IHubBase
  function refreshPremium(address underlying, PremiumDelta calldata premiumDelta) external {
    Asset storage asset = _assets[underlying];
    SpokeData storage spoke = _spokes[underlying][msg.sender];

    asset.accrue();
    require(spoke.active, SpokeNotActive());
    // no premium change allowed
    _applyPremiumDelta(asset, spoke, premiumDelta, 0);
    asset.updateDrawnRate(underlying);

    emit RefreshPremium(underlying, msg.sender, premiumDelta);
  }

  /// @inheritdoc IHubBase
  function payFeeShares(address underlying, uint256 shares) external {
    Asset storage asset = _assets[underlying];
    address feeReceiver = _assets[underlying].feeReceiver;
    SpokeData storage receiver = _spokes[underlying][feeReceiver];
    SpokeData storage sender = _spokes[underlying][msg.sender];

    asset.accrue();
    _validatePayFeeShares(sender, shares);
    _transferShares(sender, receiver, shares);
    asset.updateDrawnRate(underlying);

    emit TransferShares(underlying, msg.sender, feeReceiver, shares);
  }

  /// @inheritdoc IHub
  function transferShares(address underlying, uint256 shares, address toSpoke) external {
    Asset storage asset = _assets[underlying];
    SpokeData storage sender = _spokes[underlying][msg.sender];
    SpokeData storage receiver = _spokes[underlying][toSpoke];

    asset.accrue();
    _validateTransferShares(asset, sender, receiver, shares);
    _transferShares(sender, receiver, shares);
    asset.updateDrawnRate(underlying);

    emit TransferShares(underlying, msg.sender, toSpoke, shares);
  }

  /// @inheritdoc IHub
  function sweep(address underlying, uint256 amount) external {
    Asset storage asset = _assets[underlying];

    asset.accrue();
    _validateSweep(asset, msg.sender, amount);

    uint256 liquidity = asset.liquidity;
    require(amount <= liquidity, InsufficientLiquidity(liquidity));

    asset.liquidity = liquidity.uncheckedSub(amount).toUint120();
    asset.swept += amount.toUint120();
    asset.updateDrawnRate(underlying);

    underlying.safeTransfer(msg.sender, amount);

    emit Sweep(underlying, msg.sender, amount);
  }

  /// @inheritdoc IHub
  function reclaim(address underlying, uint256 amount) external {
    Asset storage asset = _assets[underlying];

    asset.accrue();
    _validateReclaim(asset, msg.sender, amount);

    asset.liquidity += amount.toUint120();
    asset.swept -= amount.toUint120();
    asset.updateDrawnRate(underlying);

    underlying.safeTransferFrom(msg.sender, address(this), amount);

    emit Reclaim(underlying, msg.sender, amount);
  }

  /// @inheritdoc IHub
  function getAssetCount() external view returns (uint256) {
    return _assetCount;
  }

  /// @inheritdoc IHubBase
  function previewAddByAssets(address underlying, uint256 assets) external view returns (uint256) {
    return _assets[underlying].toAddedSharesDown(assets);
  }

  /// @inheritdoc IHubBase
  function previewAddByShares(address underlying, uint256 shares) external view returns (uint256) {
    return _assets[underlying].toAddedAssetsUp(shares);
  }

  /// @inheritdoc IHubBase
  function previewRemoveByAssets(
    address underlying,
    uint256 assets
  ) external view returns (uint256) {
    return _assets[underlying].toAddedSharesUp(assets);
  }

  /// @inheritdoc IHubBase
  function previewRemoveByShares(
    address underlying,
    uint256 shares
  ) external view returns (uint256) {
    return _assets[underlying].toAddedAssetsDown(shares);
  }

  /// @inheritdoc IHubBase
  function previewDrawByAssets(address underlying, uint256 assets) external view returns (uint256) {
    return _assets[underlying].toDrawnSharesUp(assets);
  }

  /// @inheritdoc IHubBase
  function previewDrawByShares(address underlying, uint256 shares) external view returns (uint256) {
    return _assets[underlying].toDrawnAssetsDown(shares);
  }

  /// @inheritdoc IHubBase
  function previewRestoreByAssets(
    address underlying,
    uint256 assets
  ) external view returns (uint256) {
    return _assets[underlying].toDrawnSharesDown(assets);
  }

  /// @inheritdoc IHubBase
  function previewRestoreByShares(
    address underlying,
    uint256 shares
  ) external view returns (uint256) {
    return _assets[underlying].toDrawnAssetsUp(shares);
  }

  /// @inheritdoc IHubBase
  function getAssetUnderlyingAndDecimals(
    address underlying
  ) external view returns (address, uint8) {
    Asset storage asset = _assets[underlying];
    return (asset.underlying, asset.decimals);
  }

  /// @inheritdoc IHubBase
  function getAssetDrawnIndex(address underlying) external view returns (uint256) {
    return _assets[underlying].getDrawnIndex();
  }

  /// @inheritdoc IHubBase
  function getAddedAssets(address underlying) external view returns (uint256) {
    return _assets[underlying].totalAddedAssets();
  }

  /// @inheritdoc IHubBase
  function getAddedShares(address underlying) external view returns (uint256) {
    return _assets[underlying].addedShares;
  }

  /// @inheritdoc IHubBase
  function getAssetOwed(address underlying) external view returns (uint256, uint256) {
    Asset storage asset = _assets[underlying];
    uint256 drawnIndex = asset.getDrawnIndex();
    return (asset.drawn(drawnIndex), asset.premium(drawnIndex));
  }

  /// @inheritdoc IHubBase
  function getAssetTotalOwed(address underlying) external view returns (uint256) {
    Asset storage asset = _assets[underlying];
    return asset.totalOwed(asset.getDrawnIndex());
  }

  /// @inheritdoc IHubBase
  function getAssetDrawnShares(address underlying) external view returns (uint256) {
    return _assets[underlying].drawnShares;
  }

  /// @inheritdoc IHubBase
  function getAssetPremiumData(
    address underlying
  ) external view returns (uint256, uint256, uint256) {
    Asset storage asset = _assets[underlying];
    return (asset.premiumShares, asset.premiumOffset, asset.realizedPremium);
  }

  /// @inheritdoc IHubBase
  function getAssetLiquidity(address underlying) external view returns (uint256) {
    return _assets[underlying].liquidity;
  }

  /// @inheritdoc IHubBase
  function getAssetDeficit(address underlying) external view returns (uint256) {
    return _assets[underlying].deficit;
  }

  /// @inheritdoc IHub
  function getAsset(address underlying) external view returns (Asset memory) {
    return _assets[underlying];
  }

  /// @inheritdoc IHub
  function getAssetConfig(address underlying) external view returns (AssetConfig memory) {
    Asset storage asset = _assets[underlying];
    return
      AssetConfig({
        feeReceiver: asset.feeReceiver,
        liquidityFee: asset.liquidityFee,
        irStrategy: asset.irStrategy,
        reinvestmentController: asset.reinvestmentController
      });
  }

  /// @inheritdoc IHub
  function getAssetAccruedFees(address underlying) external view returns (uint256) {
    Asset storage asset = _assets[underlying];
    return asset.realizedFees + asset.getUnrealizedFees(asset.getDrawnIndex());
  }

  /// @inheritdoc IHub
  function getAssetSwept(address underlying) external view returns (uint256) {
    return _assets[underlying].swept;
  }

  /// @inheritdoc IHub
  function getAssetDrawnRate(address underlying) external view returns (uint256) {
    return _assets[underlying].drawnRate;
  }

  /// @inheritdoc IHub
  function getSpokeCount(address underlying) external view returns (uint256) {
    return _assetToSpokes[underlying].length();
  }

  /// @inheritdoc IHubBase
  function getSpokeAddedAssets(address underlying, address spoke) external view returns (uint256) {
    return _assets[underlying].toAddedAssetsDown(_spokes[underlying][spoke].addedShares);
  }

  /// @inheritdoc IHubBase
  function getSpokeAddedShares(address underlying, address spoke) external view returns (uint256) {
    return _spokes[underlying][spoke].addedShares;
  }

  /// @inheritdoc IHubBase
  function getSpokeOwed(
    address underlying,
    address spoke
  ) external view returns (uint256, uint256) {
    Asset storage asset = _assets[underlying];
    SpokeData storage spokeData = _spokes[underlying][spoke];
    return (_getSpokeDrawn(asset, spokeData), _getSpokePremium(asset, spokeData));
  }

  /// @inheritdoc IHubBase
  function getSpokeTotalOwed(address underlying, address spoke) external view returns (uint256) {
    Asset storage asset = _assets[underlying];
    SpokeData storage spokeData = _spokes[underlying][spoke];
    return _getSpokeDrawn(asset, spokeData) + _getSpokePremium(asset, spokeData);
  }

  /// @inheritdoc IHubBase
  function getSpokeDrawnShares(address underlying, address spoke) external view returns (uint256) {
    return _spokes[underlying][spoke].drawnShares;
  }

  /// @inheritdoc IHubBase
  function getSpokePremiumData(
    address underlying,
    address spoke
  ) external view returns (uint256, uint256, uint256) {
    SpokeData storage spokeData = _spokes[underlying][spoke];
    return (spokeData.premiumShares, spokeData.premiumOffset, spokeData.realizedPremium);
  }

  /// @inheritdoc IHubBase
  function getSpokeDeficit(address underlying, address spoke) external view returns (uint256) {
    return _spokes[underlying][spoke].deficit;
  }

  /// @inheritdoc IHub
  function isSpokeListed(address underlying, address spoke) external view returns (bool) {
    return _assetToSpokes[underlying].contains(spoke);
  }

  /// @inheritdoc IHub
  function getSpokeAddress(address underlying, uint256 index) external view returns (address) {
    return _assetToSpokes[underlying].at(index);
  }

  /// @inheritdoc IHub
  function getSpoke(address underlying, address spoke) external view returns (SpokeData memory) {
    return _spokes[underlying][spoke];
  }

  /// @inheritdoc IHub
  function isUnderlyingListed(address underlying) external view returns (bool) {
    return _underlyingSet.contains(underlying);
  }

  /// @inheritdoc IHub
  function getSpokeConfig(
    address underlying,
    address spoke
  ) external view returns (SpokeConfig memory) {
    SpokeData storage spokeData = _spokes[underlying][spoke];
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
  function _addFeeReceiver(address underlying, address feeReceiver) internal {
    _addSpoke(underlying, feeReceiver);
    _updateSpokeConfig(
      underlying,
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

  /// @notice Adds a spoke to an asset.
  /// @dev Reverts with `SpokeAlreadyListed` if spoke is already listed for the given asset.
  function _addSpoke(address underlying, address spoke) internal {
    require(_assetToSpokes[underlying].add(spoke), SpokeAlreadyListed());
    emit AddSpoke(underlying, spoke);
  }

  function _updateSpokeConfig(
    address underlying,
    address spoke,
    SpokeConfig memory config
  ) internal {
    SpokeData storage spokeData = _spokes[underlying][spoke];
    spokeData.addCap = config.addCap;
    spokeData.drawCap = config.drawCap;
    spokeData.riskPremiumThreshold = config.riskPremiumThreshold;
    spokeData.active = config.active;
    spokeData.paused = config.paused;
    emit UpdateSpokeConfig(underlying, spoke, config);
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

    uint24 riskPremiumThreshold = spoke.riskPremiumThreshold;
    require(
      riskPremiumThreshold == MAX_RISK_PREMIUM_THRESHOLD ||
        spoke.premiumShares <= spoke.drawnShares.percentMulUp(riskPremiumThreshold),
      InvalidPremiumChange()
    );
  }

  function _mintFeeShares(Asset storage asset, address underlying) internal returns (uint256) {
    uint256 fees = asset.realizedFees;
    uint120 shares = asset.toAddedSharesDown(fees).toUint120();
    if (shares == 0) {
      return 0;
    }

    address feeReceiver = asset.feeReceiver;
    SpokeData storage feeReceiverSpoke = _spokes[underlying][feeReceiver];
    require(feeReceiverSpoke.active, SpokeNotActive());

    asset.addedShares += shares;
    feeReceiverSpoke.addedShares += shares;
    asset.realizedFees = 0;
    emit MintFeeShares(underlying, feeReceiver, shares, fees);

    return shares;
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
    uint256 amount
  ) internal view {
    require(amount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    require(!spoke.paused, SpokePaused());
    uint256 addCap = spoke.addCap;
    require(
      addCap == MAX_ALLOWED_SPOKE_CAP ||
        addCap * MathUtils.uncheckedExp(10, asset.decimals) >=
        asset.toAddedAssetsUp(spoke.addedShares) + amount,
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
    Asset storage asset,
    SpokeData storage spoke,
    uint256 amount,
    address to
  ) internal view {
    require(to != address(this), InvalidAddress());
    require(amount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    require(!spoke.paused, SpokePaused());
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
    uint256 premiumAmount
  ) internal view {
    require(drawnAmount + premiumAmount > 0, InvalidAmount());
    require(spoke.active, SpokeNotActive());
    require(!spoke.paused, SpokePaused());
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
    require(!spoke.paused, SpokePaused());
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
    require(!senderSpoke.paused, SpokePaused());
    require(feeShares > 0, InvalidShares());
  }

  function _validateTransferShares(
    Asset storage asset,
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
        addCap * MathUtils.uncheckedExp(10, asset.decimals) >=
        asset.toAddedAssetsUp(receiver.addedShares + shares),
      AddCapExceeded(addCap)
    );
  }

  function _validateSweep(Asset storage asset, address caller, uint256 amount) internal view {
    // sufficient check to disallow when controller unset
    require(caller == asset.reinvestmentController, OnlyReinvestmentController());
    require(amount > 0, InvalidAmount());
  }

  function _validateReclaim(Asset storage asset, address caller, uint256 amount) internal view {
    // sufficient check to disallow when controller unset
    require(caller == asset.reinvestmentController, OnlyReinvestmentController());
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
