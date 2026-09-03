// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ArcConfigEngine} from 'scripts/config/ArcConfigEngine.sol';
import {ArcConfigInputs} from 'scripts/config/ArcConfigInputs.sol';
import {ArcHandover} from 'scripts/config/ArcHandover.sol';
import {ArcParameters} from 'scripts/config/ArcParameters.sol';

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {Ownable2Step} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

/// @title ArcVerification
/// @author Aave Labs
/// @notice Asserts that a deployed, configured and handed-over Arc market matches what the deploy
/// inputs and `ArcParameters` say it should be.
/// @dev Read-only, and reverts on the first discrepancy. Reconstructs the expected state from the
/// same sources the deploy and configuration scripts read, then compares it against on-chain reads,
/// so it catches a step that was skipped, half-applied, or applied with the wrong values.
///
/// Roles, ownership and the halt are delegated to `ArcHandover.verify`, which enumerates them; this
/// library adds deployment integrity and the risk parameters of every listed asset.
library ArcVerification {
  /// @notice Thrown when a contract that should exist has no code.
  error MissingCode(string what, address target);
  /// @notice Thrown when an on-chain address does not match the expected one.
  error UnexpectedAddress(string what, address actual, address expected);
  /// @notice Thrown when an on-chain value does not match the expected one.
  error UnexpectedUint(string what, uint256 actual, uint256 expected);
  /// @notice Thrown when an on-chain flag does not match the expected one.
  error UnexpectedFlag(string what, bool actual, bool expected);
  /// @notice Thrown when a Spoke is registered for an asset the parameters do not list it for.
  error SpokeUnexpectedlyListed(string symbol, uint256 spokeIndex);
  /// @notice Thrown when a listed asset has no tokenization spoke registered on the Hub.
  error TokenizationSpokeNotFound(string symbol);
  /// @notice Thrown when a position manager is not active on a spoke. The configuration script does
  /// this half, so it means configuration did not run or did not complete.
  error PositionManagerNotActive(address manager, address spoke);
  /// @notice Thrown when a spoke is not registered on a position manager.
  error SpokeNotRegisteredOnManager(address manager, address spoke);
  /// @notice Thrown when a position manager's ownership transfer to the Council has not been
  /// accepted yet. The Council completes it with `acceptOwnership`.
  error ManagerOwnershipNotAccepted(address manager, address owner, address pendingOwner);

  /// @notice Asserts the whole market: deployment, handover, and the configuration of every asset in
  /// the launch set.
  /// @param market The deployed Arc market.
  /// @param targets The addresses the market was handed over to.
  /// @param assets The launch set that was configured.
  /// @param deployer The address that ran the deployment and configuration.
  function verify(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.Handover memory targets,
    ArcConfigInputs.AssetInput[] memory assets,
    address deployer
  ) internal view {
    verifyDeployment(market);
    ArcHandover.verify(market, targets, deployer);
    verifyLiquidationConfigs(market);
    verifyPositionManagers(market, targets);

    for (uint256 i; i < assets.length; ++i) {
      verifyAsset(market, assets[i]);
    }
  }

  /// @notice Asserts every contract in the deployment report exists and is wired to the others.
  /// @param market The deployed Arc market.
  function verifyDeployment(ArcConfigInputs.Market memory market) internal view {
    _requireCode('accessManager', market.accessManager);
    _requireCode('hubConfigurator', market.hubConfigurator);
    _requireCode('spokeConfigurator', market.spokeConfigurator);
    _requireCode('treasurySpoke', market.treasurySpoke);
    _requireCode('configEngine', ArcConfigEngine.predictedAddress());
    _requireCode('hub', market.hub);
    _requireCode('irStrategy', market.irStrategy);

    _requireAddress(
      'hubConfigurator authority',
      IAccessManaged(market.hubConfigurator).authority(),
      market.accessManager
    );
    _requireAddress(
      'spokeConfigurator authority',
      IAccessManaged(market.spokeConfigurator).authority(),
      market.accessManager
    );
    _requireAddress('hub authority', IAccessManaged(market.hub).authority(), market.accessManager);

    for (uint256 i; i < market.spokes.length; ++i) {
      _requireCode('spoke', market.spokes[i]);
      _requireAddress(
        'spoke authority',
        IAccessManaged(market.spokes[i]).authority(),
        market.accessManager
      );
      _requireCode('spoke oracle', ISpoke(market.spokes[i]).ORACLE());
    }

    if (market.signatureGateway != address(0)) {
      _requireCode('signatureGateway', market.signatureGateway);
    }
    if (market.giverPositionManager != address(0)) {
      _requireCode('giverPositionManager', market.giverPositionManager);
      _requireCode('takerPositionManager', market.takerPositionManager);
      _requireCode('configPositionManager', market.configPositionManager);
    }
  }

  /// @notice Asserts each spoke carries the dynamic liquidation bonus configuration for its role.
  /// @param market The deployed Arc market.
  function verifyLiquidationConfigs(ArcConfigInputs.Market memory market) internal view {
    for (uint256 i; i < market.spokes.length; ++i) {
      ISpoke.LiquidationConfig memory expected = ArcParameters.liquidationConfig(
        ArcParameters.Spoke(i)
      );
      ISpoke.LiquidationConfig memory actual = ISpoke(market.spokes[i]).getLiquidationConfig();

      _requireUint('targetHealthFactor', actual.targetHealthFactor, expected.targetHealthFactor);
      _requireUint(
        'healthFactorForMaxBonus',
        actual.healthFactorForMaxBonus,
        expected.healthFactorForMaxBonus
      );
      _requireUint(
        'liquidationBonusFactor',
        actual.liquidationBonusFactor,
        expected.liquidationBonusFactor
      );
    }
  }

  /// @notice Asserts both halves of position manager wiring on every spoke.
  /// @dev Configuration does both halves of the wiring, so a failure there means configuration did
  /// not run or did not complete. Ownership is separate: the handover starts an `Ownable2Step`
  /// transfer and only the Council can accept it, so `ManagerOwnershipNotAccepted` means the
  /// Council's `acceptOwnership` bundle is still outstanding.
  /// @param market The deployed Arc market.
  /// @param targets The addresses the market was handed over to.
  function verifyPositionManagers(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.Handover memory targets
  ) internal view {
    address[4] memory managers = [
      market.giverPositionManager,
      market.takerPositionManager,
      market.configPositionManager,
      market.signatureGateway
    ];

    for (uint256 i; i < managers.length; ++i) {
      if (managers[i] == address(0)) continue;
      address expectedOwner = managers[i] == market.signatureGateway
        ? targets.gatewayOwner
        : targets.positionManagerOwner;
      address owner = Ownable(managers[i]).owner();
      require(
        owner == expectedOwner,
        ManagerOwnershipNotAccepted(managers[i], owner, Ownable2Step(managers[i]).pendingOwner())
      );

      for (uint256 j; j < market.spokes.length; ++j) {
        require(
          ISpoke(market.spokes[j]).isPositionManagerActive(managers[i]),
          PositionManagerNotActive(managers[i], market.spokes[j])
        );
        require(
          IPositionManagerBase(managers[i]).isSpokeRegistered(market.spokes[j]),
          SpokeNotRegisteredOnManager(managers[i], market.spokes[j])
        );
      }
    }
  }

  /// @notice Asserts one asset's Hub configuration, its reserve on every spoke, and its tokenization
  /// spoke.
  /// @param market The deployed Arc market.
  /// @param asset The asset to check.
  function verifyAsset(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.AssetInput memory asset
  ) internal view {
    // reverts if the asset was never listed on the Hub
    uint256 assetId = IHubBase(market.hub).getAssetId(asset.underlying);

    _verifyHubAsset(market, asset, assetId);

    for (uint256 i; i < market.spokes.length; ++i) {
      _verifySpokeReserve(market, asset, assetId, i);
    }

    _verifyTokenizationSpoke(market, asset, assetId);
  }

  function _verifyHubAsset(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.AssetInput memory asset,
    uint256 assetId
  ) private view {
    string memory name = ArcParameters.symbol(asset.key);
    ArcParameters.AssetParams memory expected = ArcParameters.assetParams(asset.key);

    IHub.AssetConfig memory config = IHub(market.hub).getAssetConfig(assetId);
    _requireAddress(string.concat(name, ' feeReceiver'), config.feeReceiver, market.treasurySpoke);
    _requireAddress(string.concat(name, ' irStrategy'), config.irStrategy, market.irStrategy);
    _requireUint(string.concat(name, ' liquidityFee'), config.liquidityFee, expected.liquidityFee);

    IAssetInterestRateStrategy.InterestRateData memory rate = IAssetInterestRateStrategy(
      market.irStrategy
    ).getInterestRateData(assetId);
    _requireUint(
      string.concat(name, ' optimalUsageRatio'),
      rate.optimalUsageRatio,
      expected.optimalUsageRatio
    );
    _requireUint(string.concat(name, ' baseDrawnRate'), rate.baseDrawnRate, expected.baseDrawnRate);
    _requireUint(
      string.concat(name, ' slope1'),
      rate.rateGrowthBeforeOptimal,
      expected.rateGrowthBeforeOptimal
    );
    _requireUint(
      string.concat(name, ' slope2'),
      rate.rateGrowthAfterOptimal,
      expected.rateGrowthAfterOptimal
    );
  }

  function _verifySpokeReserve(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.AssetInput memory asset,
    uint256 assetId,
    uint256 spokeIndex
  ) private view {
    address spoke = market.spokes[spokeIndex];
    string memory name = ArcParameters.symbol(asset.key);
    ArcParameters.ReserveParams memory expected = ArcParameters.reserveParams(
      asset.key,
      ArcParameters.Spoke(spokeIndex)
    );

    if (!expected.listed) {
      require(
        !IHub(market.hub).isSpokeListed(assetId, spoke),
        SpokeUnexpectedlyListed(name, spokeIndex)
      );
      return;
    }

    IHub.SpokeConfig memory spokeConfig = IHub(market.hub).getSpokeConfig(assetId, spoke);
    _requireUint(string.concat(name, ' addCap'), spokeConfig.addCap, expected.addCap);
    _requireUint(string.concat(name, ' drawCap'), spokeConfig.drawCap, expected.drawCap);

    uint256 reserveId = ISpoke(spoke).getReserveId(market.hub, assetId);

    ISpoke.DynamicReserveConfig memory dynamicConfig = ISpoke(spoke).getDynamicReserveConfig(
      reserveId,
      0
    );
    _requireUint(
      string.concat(name, ' collateralFactor'),
      dynamicConfig.collateralFactor,
      expected.collateralFactor
    );
    _requireUint(
      string.concat(name, ' maxLiquidationBonus'),
      dynamicConfig.maxLiquidationBonus,
      expected.maxLiquidationBonus
    );
    _requireUint(
      string.concat(name, ' liquidationFee'),
      dynamicConfig.liquidationFee,
      expected.liquidationFee
    );

    ISpoke.ReserveConfig memory reserveConfig = ISpoke(spoke).getReserveConfig(reserveId);
    _requireFlag(string.concat(name, ' borrowable'), reserveConfig.borrowable, expected.borrowable);
    _requireFlag(
      string.concat(name, ' receiveSharesEnabled'),
      reserveConfig.receiveSharesEnabled,
      ArcParameters.RECEIVE_SHARES_ENABLED
    );
    _requireUint(
      string.concat(name, ' collateralRisk'),
      reserveConfig.collateralRisk,
      ArcParameters.COLLATERAL_RISK
    );
    _requireUint(
      string.concat(name, ' riskPremiumThreshold'),
      spokeConfig.riskPremiumThreshold,
      ArcParameters.RISK_PREMIUM_THRESHOLD
    );
    _requireAddress(
      string.concat(name, ' priceSource'),
      IAaveOracle(ISpoke(spoke).ORACLE()).getReserveSource(reserveId),
      asset.priceSource
    );
  }

  /// @dev The tokenization spoke is the Hub-registered spoke for this asset that is neither a
  /// borrowing spoke nor the treasury spoke; it is then identified positively by the asset it
  /// tokenizes.
  function _verifyTokenizationSpoke(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.AssetInput memory asset,
    uint256 assetId
  ) private view {
    string memory name = ArcParameters.symbol(asset.key);
    uint40 expectedAddCap = ArcParameters.assetParams(asset.key).tokenizationAddCap;
    if (expectedAddCap == 0) return;

    uint256 spokeCount = IHub(market.hub).getSpokeCount(assetId);

    for (uint256 i; i < spokeCount; ++i) {
      address spoke = IHub(market.hub).getSpokeAddress(assetId, i);
      if (spoke == market.treasurySpoke || _isBorrowingSpoke(market, spoke)) continue;

      _requireAddress(
        string.concat(name, ' tokenization underlying'),
        ITokenizationSpoke(spoke).asset(),
        asset.underlying
      );
      _requireAddress(
        string.concat(name, ' tokenization hub'),
        ITokenizationSpoke(spoke).hub(),
        market.hub
      );

      IHub.SpokeConfig memory config = IHub(market.hub).getSpokeConfig(assetId, spoke);
      _requireUint(string.concat(name, ' tokenization addCap'), config.addCap, expectedAddCap);
      _requireUint(string.concat(name, ' tokenization drawCap'), config.drawCap, 0);
      return;
    }

    revert TokenizationSpokeNotFound(name);
  }

  function _isBorrowingSpoke(
    ArcConfigInputs.Market memory market,
    address spoke
  ) private pure returns (bool) {
    for (uint256 i; i < market.spokes.length; ++i) {
      if (market.spokes[i] == spoke) return true;
    }
    return false;
  }

  function _requireCode(string memory what, address target) private view {
    require(target.code.length > 0, MissingCode(what, target));
  }

  function _requireAddress(string memory what, address actual, address expected) private pure {
    require(actual == expected, UnexpectedAddress(what, actual, expected));
  }

  function _requireUint(string memory what, uint256 actual, uint256 expected) private pure {
    require(actual == expected, UnexpectedUint(what, actual, expected));
  }

  function _requireFlag(string memory what, bool actual, bool expected) private pure {
    require(actual == expected, UnexpectedFlag(what, actual, expected));
  }
}
