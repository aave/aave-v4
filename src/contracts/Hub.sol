// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {AssetLogic} from 'src/libraries/logic/AssetLogic.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SharesMath} from 'src/libraries/math/SharesMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {Constants} from 'src/libraries/helpers/Constants.sol';

import {IHubBase, IHub} from 'src/interfaces/IHub.sol';
import {IAssetInterestRateStrategy} from 'src/interfaces/IAssetInterestRateStrategy.sol';

contract Hub is IHub, AccessManaged {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeERC20 for IERC20;
  using SafeCast for uint256;
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using AssetLogic for DataTypes.Asset;
  using MathUtils for uint128;

  uint256 internal _assetCount;
  mapping(uint256 assetId => DataTypes.Asset assetData) internal _assets;
  mapping(uint256 assetId => mapping(address spoke => DataTypes.SpokeData spokeData))
    internal _spokes;
  mapping(uint256 assetId => EnumerableSet.AddressSet spoke) internal _assetToSpokes;

  /**
   * @dev Constructor.
   * @dev The authority contract must implement the AccessManaged interface for access control.
   * @param authority_ The address of the authority contract which manages permissions.
   */
  constructor(address authority_) AccessManaged(authority_) {
    // Intentionally left blank
  }

  /// @inheritdoc IHub
  function addAsset(
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address irStrategy,
    bytes calldata data
  ) external restricted returns (uint256) {
    require(underlying != address(0), InvalidUnderlying());
    require(decimals <= Constants.MAX_ALLOWED_ASSET_DECIMALS, InvalidAssetDecimals());
    require(feeReceiver != address(0), InvalidFeeReceiver());
    require(irStrategy != address(0), InvalidIrStrategy());

    uint256 assetId = _assetCount++;
    IAssetInterestRateStrategy(irStrategy).setInterestRateData(assetId, data);
    uint256 drawnRate = IAssetInterestRateStrategy(irStrategy).calculateInterestRate({
      assetId: assetId,
      liquidity: 0,
      drawn: 0,
      premium: 0
    });

    uint256 drawnIndex = WadRayMath.RAY;
    uint256 lastUpdateTimestamp = block.timestamp;
    _assets[assetId] = DataTypes.Asset({
      liquidity: 0,
      deficit: 0,
      addedShares: 0,
      drawnShares: 0,
      premiumShares: 0,
      premiumOffset: 0,
      drawnIndex: drawnIndex.toUint128(),
      realizedPremium: 0,
      underlying: underlying,
      lastUpdateTimestamp: lastUpdateTimestamp.toUint40(),
      decimals: decimals,
      drawnRate: drawnRate.toUint128(),
      irStrategy: irStrategy,
      feeReceiver: feeReceiver,
      liquidityFee: 0
    });

    emit AddAsset(assetId, underlying, decimals);
    emit AssetConfigUpdate(
      assetId,
      DataTypes.AssetConfig({feeReceiver: feeReceiver, liquidityFee: 0, irStrategy: irStrategy})
    );
    emit AssetUpdate(assetId, drawnIndex, drawnRate, lastUpdateTimestamp);

    return assetId;
  }

  /// @inheritdoc IHub
  function updateAssetConfig(
    uint256 assetId,
    DataTypes.AssetConfig calldata config
  ) external restricted {
    require(assetId < _assetCount, AssetNotListed());
    require(config.liquidityFee <= PercentageMath.PERCENTAGE_FACTOR, InvalidLiquidityFee());
    require(config.feeReceiver != address(0), InvalidFeeReceiver());
    require(config.irStrategy != address(0), InvalidIrStrategy());

    DataTypes.Asset storage asset = _assets[assetId];
    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);

    asset.feeReceiver = config.feeReceiver;
    asset.liquidityFee = config.liquidityFee;
    asset.irStrategy = config.irStrategy;

    asset.updateDrawnRate(assetId);

    emit AssetConfigUpdate(assetId, config);
  }

  function addSpoke(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig calldata config
  ) external restricted {
    require(assetId < _assetCount, AssetNotListed());
    require(spoke != address(0), InvalidSpoke());
    require(!_assetToSpokes[assetId].contains(spoke), SpokeAlreadyListed());

    _assetToSpokes[assetId].add(spoke);
    emit AddSpoke(assetId, spoke);

    _updateSpokeConfig(assetId, spoke, config);
  }

  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig calldata config
  ) external restricted {
    require(_assetToSpokes[assetId].contains(spoke), SpokeNotListed());
    _updateSpokeConfig(assetId, spoke, config);
  }

  /// @inheritdoc IHub
  function setInterestRateData(uint256 assetId, bytes calldata data) external restricted {
    DataTypes.Asset storage asset = _assets[assetId];
    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    IAssetInterestRateStrategy(asset.irStrategy).setInterestRateData(assetId, data);
  }

  /// @inheritdoc IHubBase
  function add(uint256 assetId, uint256 amount, address from) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    _validateAdd(asset, spoke, assetId, amount, from);

    // todo: Mitigate inflation attack
    uint128 shares = previewAddByAssets(assetId, amount).toUint128();
    require(shares != 0, InvalidSharesAmount());
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
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    _validateRemove(asset, spoke, assetId, amount, to);

    uint128 shares = previewRemoveByAssets(assetId, amount).toUint128(); // non zero since we round up
    asset.addedShares -= shares;
    spoke.addedShares -= shares;
    asset.liquidity -= amount.toUint128();

    asset.updateDrawnRate(assetId);

    IERC20(asset.underlying).safeTransfer(to, amount);

    emit Remove(assetId, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc IHubBase
  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    _validateDraw(asset, spoke, assetId, amount, to);

    uint128 drawnShares = previewDrawByAssets(assetId, amount).toUint128(); // non zero since we round up
    asset.drawnShares += drawnShares;
    spoke.drawnShares += drawnShares;
    asset.liquidity -= amount.toUint128();

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
    DataTypes.PremiumDelta calldata premiumDelta,
    address from
  ) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    _validateRestore(asset, spoke, assetId, drawnAmount, premiumAmount, from);

    _applyPremiumDelta(asset, spoke, premiumDelta, premiumAmount);
    uint128 drawnShares = previewRestoreByAssets(assetId, drawnAmount).toUint128();
    asset.drawnShares -= drawnShares;
    spoke.drawnShares -= drawnShares;
    uint256 totalAmount = drawnAmount + premiumAmount;
    asset.liquidity += totalAmount.toUint128();

    asset.updateDrawnRate(assetId);

    IERC20(asset.underlying).safeTransferFrom(from, address(this), totalAmount);

    emit Restore(assetId, msg.sender, drawnShares, premiumDelta, drawnAmount, premiumAmount);

    return drawnShares;
  }

  /// @inheritdoc IHub
  function reportDeficit(
    uint256 assetId,
    uint256 drawnAmount,
    uint256 premiumAmount,
    DataTypes.PremiumDelta calldata premiumDelta
  ) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);

    _validateReportDeficit(asset, spoke, assetId, drawnAmount, premiumAmount);

    _applyPremiumDelta(asset, spoke, premiumDelta, premiumAmount);
    uint128 drawnShares = previewRestoreByAssets(assetId, drawnAmount).toUint128();
    asset.drawnShares -= drawnShares;
    spoke.drawnShares -= drawnShares;
    uint256 totalDeficitAmount = drawnAmount + premiumAmount;
    asset.deficit += totalDeficitAmount.toUint128();

    asset.updateDrawnRate(assetId);

    emit ReportDeficit(assetId, msg.sender, drawnShares, premiumDelta, totalDeficitAmount);

    return drawnShares;
  }

  /// @inheritdoc IHub
  function eliminateDeficit(uint256 assetId, uint256 amount) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);
    _validateEliminateDeficit(asset, spoke, amount);

    uint128 shares = previewRemoveByAssets(assetId, amount).toUint128();
    asset.addedShares -= shares;
    spoke.addedShares -= shares;
    asset.deficit -= amount.toUint128();

    asset.updateDrawnRate(assetId);

    emit EliminateDeficit(assetId, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc IHub
  function refreshPremium(uint256 assetId, DataTypes.PremiumDelta calldata premiumDelta) external {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    require(spoke.active, SpokeNotActive());
    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);

    // no premium change allowed
    _applyPremiumDelta(asset, spoke, premiumDelta, 0);

    emit RefreshPremium(assetId, msg.sender, premiumDelta);
  }

  /// @inheritdoc IHub
  function payFee(uint256 assetId, uint256 shares) external {
    DataTypes.SpokeData storage sender = _spokes[assetId][msg.sender];
    _validatePayFee(sender, shares);

    address feeReceiver = _assets[assetId].feeReceiver;
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage receiver = _spokes[assetId][feeReceiver];

    asset.accrue(assetId, receiver);

    _transferShares(sender, receiver, shares);

    emit TransferShares(assetId, shares, msg.sender, feeReceiver);
  }

  /// @inheritdoc IHub
  function transferShares(uint256 assetId, uint256 shares, address toSpoke) external {
    DataTypes.SpokeData storage sender = _spokes[assetId][msg.sender];
    DataTypes.SpokeData storage receiver = _spokes[assetId][toSpoke];
    DataTypes.Asset storage asset = _assets[assetId];
    _validateTransferShares(asset, sender, receiver, assetId, shares);

    asset.accrue(assetId, _spokes[assetId][asset.feeReceiver]);

    _transferShares(sender, receiver, shares);

    emit TransferShares(assetId, shares, msg.sender, toSpoke);
  }

  /// @inheritdoc IHub
  function getAssetCount() external view override returns (uint256) {
    return _assetCount;
  }

  /// @inheritdoc IHub
  function getAsset(uint256 assetId) external view returns (DataTypes.Asset memory) {
    return _assets[assetId];
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
  function getSpoke(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeData memory) {
    return _spokes[assetId][spoke];
  }

  /// @inheritdoc IHub
  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeConfig memory) {
    return
      DataTypes.SpokeConfig({
        active: _spokes[assetId][spoke].active,
        addCap: _spokes[assetId][spoke].addCap,
        drawCap: _spokes[assetId][spoke].drawCap
      });
  }

  /// @inheritdoc IHub
  function previewAddByAssets(uint256 assetId, uint256 assets) public view returns (uint256) {
    return _assets[assetId].toAddedSharesDown(assets);
  }

  /// @inheritdoc IHub
  function previewAddByShares(uint256 assetId, uint256 shares) public view returns (uint256) {
    return _assets[assetId].toAddedAssetsUp(shares);
  }

  /// @inheritdoc IHub
  function previewRemoveByAssets(uint256 assetId, uint256 assets) public view returns (uint256) {
    return _assets[assetId].toAddedSharesUp(assets);
  }

  /// @inheritdoc IHub
  function previewRemoveByShares(uint256 assetId, uint256 shares) public view returns (uint256) {
    return _assets[assetId].toAddedAssetsDown(shares);
  }

  /// @inheritdoc IHub
  function previewDrawByAssets(uint256 assetId, uint256 assets) public view returns (uint256) {
    return _assets[assetId].toDrawnSharesUp(assets);
  }

  /// @inheritdoc IHub
  function previewDrawByShares(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].toDrawnAssetsDown(shares);
  }

  /// @inheritdoc IHub
  function previewRestoreByAssets(uint256 assetId, uint256 assets) public view returns (uint256) {
    return _assets[assetId].toDrawnSharesDown(assets);
  }

  /// @inheritdoc IHub
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

  function getAssetOwed(uint256 assetId) external view returns (uint256, uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    return (asset.drawn(), asset.premium());
  }

  function getAssetTotalOwed(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].totalOwed();
  }

  function getSpokeOwed(uint256 assetId, address spoke) external view returns (uint256, uint256) {
    return _getSpokeOwed(_assets[assetId], _spokes[assetId][spoke], assetId);
  }

  function getSpokeTotalOwed(uint256 assetId, address spoke) external view returns (uint256) {
    (uint256 drawn, uint256 premium) = _getSpokeOwed(
      _assets[assetId],
      _spokes[assetId][spoke],
      assetId
    );
    return drawn + premium;
  }

  function getAssetAddedAmount(uint256 assetId) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    return previewRemoveByShares(assetId, asset.addedShares);
  }

  function getAssetDrawnRate(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].drawnRate;
  }

  function getAssetAddedShares(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].addedShares;
  }

  function getTotalAddedAssets(uint256 assetId) external view override returns (uint256) {
    return _assets[assetId].totalAddedAssets();
  }

  function getTotalAddedShares(uint256 assetId) external view override returns (uint256) {
    return _assets[assetId].totalAddedShares();
  }

  function getSpokeAddedAmount(uint256 assetId, address spoke) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    if (spoke == asset.feeReceiver) {
      return
        previewRemoveByShares(
          assetId,
          _spokes[assetId][spoke].addedShares + asset.unrealizedFeeShares()
        );
    }
    return previewRemoveByShares(assetId, _spokes[assetId][spoke].addedShares);
  }

  function getSpokeAddedShares(uint256 assetId, address spoke) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
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

  function getAssetConfig(uint256 assetId) external view returns (DataTypes.AssetConfig memory) {
    return
      DataTypes.AssetConfig({
        feeReceiver: _assets[assetId].feeReceiver,
        liquidityFee: _assets[assetId].liquidityFee,
        irStrategy: _assets[assetId].irStrategy
      });
  }

  function _updateSpokeConfig(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig calldata config
  ) internal {
    _spokes[assetId][spoke].active = config.active;
    _spokes[assetId][spoke].addCap = config.addCap;
    _spokes[assetId][spoke].drawCap = config.drawCap;
    emit SpokeConfigUpdate(assetId, spoke, config);
  }

  /**
   * @dev Applies premium deltas on asset and spoke owed, and validates that total premium
   * cannot decrease by more than `premiumAmount`.
   */
  function _applyPremiumDelta(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    DataTypes.PremiumDelta calldata premium,
    uint256 premiumAmount
  ) internal {
    uint256 premiumBefore = asset.premium();

    asset.premiumShares = asset.premiumShares.add(premium.sharesDelta).toUint128();
    asset.premiumOffset = asset.premiumOffset.add(premium.offsetDelta).toUint128();
    asset.realizedPremium = asset.realizedPremium.add(premium.realizedDelta).toUint128();

    spoke.premiumShares = spoke.premiumShares.add(premium.sharesDelta).toUint128();
    spoke.premiumOffset = spoke.premiumOffset.add(premium.offsetDelta).toUint128();
    spoke.realizedPremium = spoke.realizedPremium.add(premium.realizedDelta).toUint128();

    // can increase due to precision loss on premium (drawn unchanged)
    // todo mathematically find premium diff ceiling and replace the `2`
    require(asset.premium() + premiumAmount - premiumBefore <= 2, InvalidPremiumChange());
  }

  function _transferShares(
    DataTypes.SpokeData storage sender,
    DataTypes.SpokeData storage receiver,
    uint256 shares
  ) internal {
    uint256 addedShares = sender.addedShares;
    require(shares <= addedShares, AddedSharesExceeded(addedShares));

    sender.addedShares = (addedShares - shares).toUint128();
    receiver.addedShares += shares.toUint128();
  }

  function _getSpokeOwed(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 assetId
  ) internal view returns (uint256, uint256) {
    uint256 accruedPremium = previewRestoreByShares(assetId, spoke.premiumShares) -
      spoke.premiumOffset;
    return (
      previewRestoreByShares(assetId, spoke.drawnShares),
      spoke.realizedPremium + accruedPremium
    );
  }

  function _validateAdd(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 assetId,
    uint256 amount,
    address from
  ) internal view {
    require(from != address(this), InvalidFromAddress());
    require(amount > 0, InvalidAddAmount());
    require(spoke.active, SpokeNotActive());
    uint256 addCap = spoke.addCap;
    require(
      addCap == Constants.MAX_CAP ||
        addCap * 10 ** asset.decimals >= previewAddByShares(assetId, spoke.addedShares) + amount,
      AddCapExceeded(addCap)
    );
  }

  function _validateRemove(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 assetId,
    uint256 amount,
    address to
  ) internal view {
    require(to != address(this), InvalidToAddress());
    require(amount > 0, InvalidRemoveAmount());
    require(spoke.active, SpokeNotActive());
    uint256 withdrawable = previewRemoveByShares(assetId, spoke.addedShares);
    require(amount <= withdrawable, AddedAmountExceeded(withdrawable));
    require(amount <= asset.liquidity, NotLiquidity(asset.liquidity));
  }

  function _validateDraw(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 assetId,
    uint256 amount,
    address to
  ) internal view {
    require(to != address(this), InvalidToAddress());
    require(amount > 0, InvalidDrawAmount());
    require(spoke.active, SpokeNotActive());
    uint256 drawCap = spoke.drawCap;
    (uint256 drawn, uint256 premium) = _getSpokeOwed(asset, spoke, assetId);
    require(
      drawCap == Constants.MAX_CAP || drawCap * 10 ** asset.decimals >= drawn + premium + amount,
      DrawCapExceeded(drawCap)
    );
    require(amount <= asset.liquidity, NotLiquidity(asset.liquidity));
  }

  function _validateRestore(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 assetId,
    uint256 drawnAmount,
    uint256 premiumAmount,
    address from
  ) internal view {
    require(from != address(this), InvalidFromAddress());
    require(drawnAmount + premiumAmount > 0, InvalidRestoreAmount());
    require(spoke.active, SpokeNotActive());
    (uint256 drawn, uint256 premium) = _getSpokeOwed(asset, spoke, assetId);
    require(drawnAmount <= drawn, SurplusAmountRestored(drawn));
    require(premiumAmount <= premium, SurplusAmountRestored(premium));
  }

  function _validateReportDeficit(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 assetId,
    uint256 drawnAmount,
    uint256 premiumAmount
  ) internal view {
    require(spoke.active, SpokeNotActive());
    require(drawnAmount + premiumAmount != 0, InvalidDeficitAmount());
    (uint256 drawn, uint256 premium) = _getSpokeOwed(asset, spoke, assetId);
    require(drawnAmount <= drawn, SurplusDeficitReported(drawn));
    require(premiumAmount <= premium, SurplusDeficitReported(premium));
  }

  function _validateEliminateDeficit(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount
  ) internal view {
    require(spoke.active, SpokeNotActive());
    require(amount != 0 && amount <= asset.deficit, InvalidDeficitAmount());
  }

  function _validatePayFee(
    DataTypes.SpokeData storage senderSpoke,
    uint256 feeShares
  ) internal view {
    require(senderSpoke.active, SpokeNotActive());
    require(feeShares != 0, InvalidFeeShares());
  }

  function _validateTransferShares(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage sender,
    DataTypes.SpokeData storage receiver,
    uint256 assetId,
    uint256 shares
  ) internal view {
    require(sender.active && receiver.active, SpokeNotActive());
    require(shares > 0, InvalidSharesAmount());
    uint256 addCap = receiver.addCap;
    require(
      addCap == Constants.MAX_CAP ||
        addCap * 10 ** asset.decimals >=
        previewRemoveByShares(assetId, receiver.addedShares + shares),
      AddCapExceeded(addCap)
    );
  }
}
