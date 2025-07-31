// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// external
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';

// libraries
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {AssetLogic} from 'src/libraries/logic/AssetLogic.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SharesMath} from 'src/libraries/math/SharesMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';

// interfaces
import {IHub} from 'src/interfaces/IHub.sol';
import {IAssetInterestRateStrategy} from 'src/interfaces/IAssetInterestRateStrategy.sol';

// @dev Amounts are `asset` denominated by default unless specified otherwise with `share` suffix
contract Hub is IHub, AccessManaged {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using AssetLogic for DataTypes.Asset;
  using MathUtils for uint256;

  uint8 public constant MAX_ALLOWED_ASSET_DECIMALS = 18;

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
    require(decimals <= MAX_ALLOWED_ASSET_DECIMALS, InvalidAssetDecimals());
    require(feeReceiver != address(0), InvalidFeeReceiver());
    require(irStrategy != address(0), InvalidIrStrategy());

    uint256 assetId = _assetCount++;
    IAssetInterestRateStrategy(irStrategy).setInterestRateData(assetId, data);
    uint256 baseDrawRate = IAssetInterestRateStrategy(irStrategy).calculateInterestRate({
      assetId: assetId,
      availableLiquidity: 0,
      drawn: 0,
      premium: 0
    });

    uint256 baseDrawnIndex = WadRayMath.RAY;
    uint256 lastUpdateTimestamp = block.timestamp;
    DataTypes.AssetConfig memory config = DataTypes.AssetConfig({
      feeReceiver: feeReceiver,
      liquidityFee: 0,
      irStrategy: irStrategy
    });
    _assets[assetId] = DataTypes.Asset({
      underlying: underlying,
      decimals: decimals,
      addedShares: 0,
      availableLiquidity: 0,
      baseDrawnShares: 0,
      premiumDrawnShares: 0,
      premiumOffset: 0,
      realizedPremium: 0,
      baseDrawnIndex: baseDrawnIndex,
      baseDrawRate: baseDrawRate,
      lastUpdateTimestamp: lastUpdateTimestamp,
      deficit: 0,
      config: config
    });

    emit AssetAdded(assetId, underlying, decimals);
    emit AssetConfigUpdated(assetId, config);
    emit AssetUpdated(assetId, baseDrawnIndex, baseDrawRate, lastUpdateTimestamp);

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
    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);

    asset.config = config;
    asset.updateDrawRate(assetId);

    emit AssetConfigUpdated(assetId, config);
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
    _spokes[assetId][spoke].config = config;

    emit SpokeAdded(assetId, spoke);
    emit SpokeConfigUpdated(assetId, spoke, config);
  }

  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig calldata config
  ) external restricted {
    require(_assetToSpokes[assetId].contains(spoke), SpokeNotListed());
    _spokes[assetId][spoke].config = config;
    emit SpokeConfigUpdated(assetId, spoke, config);
  }

  /// @inheritdoc IHub
  function setInterestRateData(uint256 assetId, bytes calldata data) external restricted {
    DataTypes.Asset storage asset = _assets[assetId];
    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    IAssetInterestRateStrategy(asset.config.irStrategy).setInterestRateData(assetId, data);
  }

  // /////
  // Spoke Actions
  // /////

  /// @inheritdoc IHub
  function add(uint256 assetId, uint256 amount, address from) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    _validateAdd(asset, spoke, amount, from);

    // todo: Mitigate inflation attack
    uint256 shares = previewAddByAssets(assetId, amount);
    require(shares != 0, InvalidSharesAmount());
    asset.addedShares += shares;
    spoke.addedShares += shares;
    asset.availableLiquidity += amount;

    asset.updateDrawRate(assetId);

    // TODO: fee-on-transfer
    IERC20(asset.underlying).safeTransferFrom(from, address(this), amount);

    emit Add(assetId, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc IHub
  function remove(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    _validateRemove(asset, spoke, amount, to);

    uint256 shares = previewRemoveByAssets(assetId, amount); // non zero since we round up
    asset.addedShares -= shares;
    spoke.addedShares -= shares;
    asset.availableLiquidity -= amount;

    asset.updateDrawRate(assetId);

    IERC20(asset.underlying).safeTransfer(to, amount);

    emit Remove(assetId, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc IHub
  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);
    _validateDraw(asset, spoke, amount, to);

    uint256 shares = previewDrawByAssets(assetId, amount); // non zero since we round up
    asset.baseDrawnShares += shares;
    spoke.baseDrawnShares += shares;
    asset.availableLiquidity -= amount;

    asset.updateDrawRate(assetId);

    IERC20(asset.underlying).safeTransfer(to, amount);

    emit Draw(assetId, msg.sender, shares, amount);

    return shares;
  }

  /// @inheritdoc IHub
  function restore(
    uint256 assetId,
    uint256 baseAmount,
    uint256 premiumAmount,
    address from
  ) external returns (uint256) {
    // global & spoke premium (premium, offset, realized) is *expected* to be updated on the `refreshPremium` callback

    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);

    _validateRestore(asset, spoke, baseAmount, premiumAmount, from);

    uint256 shares = previewRestoreByAssets(assetId, baseAmount);
    asset.baseDrawnShares -= shares;
    spoke.baseDrawnShares -= shares;
    uint256 totalAmount = baseAmount + premiumAmount;
    asset.availableLiquidity += totalAmount;

    /// @dev premium must be restored in `refreshPremium` before calling this function
    asset.updateDrawRate(assetId);

    IERC20(asset.underlying).safeTransferFrom(from, address(this), totalAmount);

    emit Restore(assetId, msg.sender, shares, totalAmount);

    return shares;
  }

  /// @inheritdoc IHub
  function reportDeficit(
    uint256 assetId,
    uint256 baseAmount,
    uint256 premiumAmount
  ) external returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);

    _validateReportDeficit(asset, spoke, baseAmount, premiumAmount);

    uint256 totalDeficitAmount = baseAmount + premiumAmount;
    uint256 baseDrawnSharesRestored = previewRestoreByAssets(assetId, baseAmount);
    asset.baseDrawnShares -= baseDrawnSharesRestored;
    spoke.baseDrawnShares -= baseDrawnSharesRestored;
    asset.deficit += totalDeficitAmount;

    /// @dev premium debt must be restored in `refreshPremium` before calling this function
    asset.updateDrawRate(assetId);

    emit DeficitReported(assetId, msg.sender, baseDrawnSharesRestored, totalDeficitAmount);

    return baseDrawnSharesRestored;
  }

  /// @inheritdoc IHub
  function refreshPremium(
    uint256 assetId,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    uint256 realizedPremiumAdded,
    uint256 realizedPremiumTaken
  ) external {
    require(_spokes[assetId][msg.sender].config.active, SpokeNotActive());

    DataTypes.Asset storage asset = _assets[assetId];

    uint256 premiumBefore = asset.premium();
    _refresh(
      assetId,
      msg.sender,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumAdded,
      realizedPremiumTaken
    );
    uint256 premiumAfter = asset.premium();
    // can increase due to precision loss on premium (base unchanged)
    // todo mathematically find premium diff ceiling and replace the `2`
    // if no premium is restored, premium remains unchanged
    require(premiumAfter + realizedPremiumTaken - premiumBefore <= 2, InvalidPremiumChange());
  }

  /// @inheritdoc IHub
  function payFee(uint256 assetId, uint256 shares) external {
    DataTypes.SpokeData storage sender = _spokes[assetId][msg.sender];
    _validatePayFee(sender, shares);

    address feeReceiver = _assets[assetId].config.feeReceiver;
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage receiver = _spokes[assetId][feeReceiver];

    asset.accrue(assetId, receiver);

    uint256 addedShares = sender.addedShares;
    uint256 addedAssets = asset.toAddedAssetsDown(addedShares);
    uint256 feeAmount = asset.toAddedAssetsDown(shares);
    require(feeAmount <= addedAssets, AddedAmountExceeded(addedAssets));

    sender.addedShares = addedShares - shares;
    receiver.addedShares += shares;

    emit Remove(assetId, msg.sender, shares, feeAmount);
    emit Add(assetId, feeReceiver, shares, feeAmount);
  }

  function _refresh(
    uint256 assetId,
    address spokeAddress,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    uint256 realizedPremiumAdded,
    uint256 realizedPremiumTaken
  ) internal {
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][spokeAddress];

    // accrue interest and liquidity fees
    asset.accrue(assetId, _spokes[assetId][asset.config.feeReceiver]);

    asset.premiumDrawnShares = asset.premiumDrawnShares.add(premiumDrawnSharesDelta);
    asset.premiumOffset = asset.premiumOffset.add(premiumOffsetDelta);
    asset.realizedPremium = asset.realizedPremium + realizedPremiumAdded - realizedPremiumTaken;

    spoke.premiumDrawnShares = spoke.premiumDrawnShares.add(premiumDrawnSharesDelta);
    spoke.premiumOffset = spoke.premiumOffset.add(premiumOffsetDelta);
    spoke.realizedPremium = spoke.realizedPremium + realizedPremiumAdded - realizedPremiumTaken;

    emit RefreshPremium(
      assetId,
      spokeAddress,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumAdded,
      realizedPremiumTaken
    );
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

  function getSpoke(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeData memory) {
    return _spokes[assetId][spoke];
  }

  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeConfig memory) {
    return _spokes[assetId][spoke].config;
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
  function previewDrawByShares(uint256 assetId, uint256 shares) public view returns (uint256) {
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

  function getBaseDrawRate(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].baseDrawRate;
  }

  function getAssetOwed(uint256 assetId) external view returns (uint256, uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    return (asset.drawn(), asset.premium());
  }

  function getAssetTotalOwed(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].totalOwed();
  }

  function getSpokeOwed(uint256 assetId, address spoke) external view returns (uint256, uint256) {
    return _getSpokeOwed(_assets[assetId], _spokes[assetId][spoke]);
  }

  function getSpokeTotalOwed(uint256 assetId, address spoke) external view returns (uint256) {
    (uint256 drawn, uint256 premium) = _getSpokeOwed(_assets[assetId], _spokes[assetId][spoke]);
    return drawn + premium;
  }

  function getAssetAddedAmount(uint256 assetId) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    return asset.toAddedAssetsDown(asset.addedShares);
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
    if (spoke == asset.config.feeReceiver) {
      return
        asset.toAddedAssetsDown(_spokes[assetId][spoke].addedShares + asset.unrealizedFeeShares());
    }
    return asset.toAddedAssetsDown(_spokes[assetId][spoke].addedShares);
  }

  function getSpokeAddedShares(uint256 assetId, address spoke) external view returns (uint256) {
    DataTypes.Asset storage asset = _assets[assetId];
    if (spoke == asset.config.feeReceiver) {
      return _spokes[assetId][spoke].addedShares + asset.unrealizedFeeShares();
    }
    return _spokes[assetId][spoke].addedShares;
  }

  function getAvailableLiquidity(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].availableLiquidity;
  }

  function getAssetConfig(uint256 assetId) external view returns (DataTypes.AssetConfig memory) {
    return _assets[assetId].config;
  }

  //
  // Internal
  //

  function _validateAdd(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount,
    address from
  ) internal view {
    require(from != address(this), InvalidFromAddress());
    require(amount > 0, InvalidAddAmount());
    require(spoke.config.active, SpokeNotActive());
    uint256 addCap = spoke.config.addCap;
    require(
      addCap == type(uint256).max || addCap >= asset.toAddedAssetsUp(spoke.addedShares) + amount,
      AddCapExceeded(addCap)
    );
  }

  function _validateRemove(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount,
    address to
  ) internal view {
    require(to != address(this), InvalidToAddress());
    require(amount > 0, InvalidRemoveAmount());
    require(spoke.config.active, SpokeNotActive());
    uint256 withdrawable = asset.toAddedAssetsDown(spoke.addedShares);
    require(amount <= withdrawable, AddedAmountExceeded(withdrawable));
    require(amount <= asset.availableLiquidity, NotAvailableLiquidity(asset.availableLiquidity));
  }

  function _validateDraw(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount,
    address to
  ) internal view {
    require(to != address(this), InvalidToAddress());
    require(amount > 0, InvalidDrawAmount());
    require(spoke.config.active, SpokeNotActive());
    uint256 drawCap = spoke.config.drawCap;
    (uint256 drawn, uint256 premium) = _getSpokeOwed(asset, spoke);
    require(
      drawCap == type(uint256).max || drawCap >= drawn + premium + amount,
      DrawCapExceeded(drawCap)
    );
    require(amount <= asset.availableLiquidity, NotAvailableLiquidity(asset.availableLiquidity));
  }

  function _validateRestore(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 baseAmount,
    uint256 premiumAmount,
    address from
  ) internal view {
    require(from != address(this), InvalidFromAddress());
    require(baseAmount + premiumAmount > 0, InvalidRestoreAmount());
    require(spoke.config.active, SpokeNotActive());
    (uint256 drawn, ) = _getSpokeOwed(asset, spoke);
    require(baseAmount <= drawn, SurplusAmountRestored(drawn));
    // we should have already restored premium
  }

  function _getSpokeOwed(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke
  ) internal view returns (uint256, uint256) {
    // sanity: utilize solc underflow check
    uint256 accruedPremium = asset.toDrawnAssetsUp(spoke.premiumDrawnShares) - spoke.premiumOffset;
    return (asset.toDrawnAssetsUp(spoke.baseDrawnShares), spoke.realizedPremium + accruedPremium);
  }

  function _validateReportDeficit(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 baseAmount,
    uint256 premiumAmount
  ) internal view {
    require(spoke.config.active, SpokeNotActive());
    require(baseAmount + premiumAmount != 0, InvalidDeficitAmount());
    (uint256 drawn, ) = _getSpokeOwed(asset, spoke);
    require(baseAmount <= drawn, SurplusDeficitReported(drawn));
    // we should have already restored premium
  }

  function _validatePayFee(
    DataTypes.SpokeData storage senderSpoke,
    uint256 feeShares
  ) internal view {
    require(senderSpoke.config.active, SpokeNotActive());
    require(feeShares != 0, InvalidFeeShares());
  }
}
