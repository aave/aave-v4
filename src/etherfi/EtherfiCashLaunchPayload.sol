// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {EtherfiCashOpMainnet} from 'src/etherfi/EtherfiCashOpMainnet.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

/// @title EtherfiCashLaunchPayload
/// @author ether.fi
/// - Discussion: https://governance.aave.com/t/arfc-deploy-a-dedicated-aave-v4-whitelabel-instance-fully-managed-by-etherfi-on-op-mainnet-to-power-ether-fi-cash/25314
/// @notice Launch payload for the ether.fi Cash Aave V4 instance on OP Mainnet (whitelabel:
/// executed by the OWNER Safe via a delegatecall Safe transaction — no Aave Governance V3).
/// The executing Safe must hold the AccessManager admin role (0) and the configurator domain
/// admin roles (200/400), which the instance deployment grants.
///
/// PHASE 1 of the two-phase launch (config-dormant -> verify -> activate, mirroring the Aave V4
/// Avalanche launch, proposal 504): this payload configures everything but registers every
/// spoke with active = false, so the market stays unusable until the on-chain state has been
/// verified and the Owner Safe executes EtherfiCashActivationPayload (phase 2).
///
/// Executes, in the AaveV4Payload fixed order:
///   1. AccessManager actions — labels the two operator roles, reassigns the cap /
///      dynamic-config selectors to them, and grants them to the Operator Safe (Nonce risk
///      curator) and the Owner Safe.
///   2. Hub asset listings — every launch asset, with its interest rate curve and liquidity fee.
///   3. Hub spoke-to-assets addition — registers the Cash Spoke for every launch asset with its
///      add/draw caps, DORMANT (active = false).
///   4. Spoke reserve listings — lists every launch asset as a reserve on the Cash Spoke with its
///      collateral factor, max liquidation bonus and liquidation fee.
///   5. Spoke liquidation config — target health factor 1.24, health factor for max bonus 0.90
///      (liquidation bonus factor kept at the deploy default).
///
/// SAFE-DELEGATECALL SAFETY: this contract must never write storage — it holds only immutables
/// and constants, so delegatecalling it from the Safe cannot corrupt Safe state.
///
/// Parameter source: "Proposal — Aave V4 Parameters by Nonce", 'Submit to AAVE' section
/// (FINAL, 2026-07-23 17:25 revision):
///   - Only USDC and WETH are borrowable at launch; every other asset is collateral-only
///     (flat 0% curve, 0% liquidity fee, draw cap 0).
///   - Borrowable curves copied from the equivalent Aave asset with the liquidity fee halved.
///   - Risk premium (collateralRisk) is 0 bps across the board.
///   - Caps come from EtherfiCashOpMainnet (final sheet values).
///
/// An asset is only included when BOTH its underlying and its price feed address are set; unset
/// (zero) entries are skipped so the payload can ship while some listings are still pending.
/// Addresses are constructor-injected immutables (payload storage is unreadable during
/// delegatecall execution); all risk parameters are compile-time constants below.
contract EtherfiCashLaunchPayload is AaveV4Payload {
  /// @notice Addresses of the ether.fi Cash Aave V4 instance contracts.
  struct InstanceAddresses {
    address configEngine;
    address hubConfigurator;
    address hub;
    address spokeConfigurator;
    address cashSpoke;
    address irStrategy;
    address feeReceiver; // TreasurySpoke
    address accessManager;
    address ownerSafe; // executes this payload via delegatecall; retains operator selectors
    address operatorSafe; // Nonce risk curator
  }

  /// @notice Underlying + price feed pairs for every launch asset. address(0) = skip.
  struct AssetAddresses {
    address usdc;
    address usdcFeed;
    address usdt;
    address usdtFeed;
    address eurc;
    address eurcFeed;
    address frxUsd;
    address frxUsdFeed;
    address weth;
    address wethFeed;
    address weEth;
    address weEthFeed;
    address eBtc;
    address eBtcFeed;
    address eUsd;
    address eUsdFeed;
    address ethfi;
    address ethfiFeed;
    address sEthfi;
    address sEthfiFeed;
    address op;
    address opFeed;
    address wHype;
    address wHypeFeed;
    address beHype;
    address beHypeFeed;
    address liquidEth;
    address liquidEthFeed;
    address liquidBtc;
    address liquidBtcFeed;
    address liquidUsd;
    address liquidUsdFeed;
    address liquidReserve;
    address liquidReserveFeed;
    address weEur;
    address weEurFeed;
    address liquidRwa;
    address liquidRwaFeed;
  }

  /// @notice Full per-asset launch configuration.
  struct AssetSpec {
    string symbol;
    address underlying;
    address priceFeed;
    uint16 collateralFactor; // BPS
    uint32 maxLiquidationBonus; // BPS, 100_00 = 0% bonus
    uint16 liquidationFee; // BPS
    bool borrowable;
    uint256 liquidityFee; // BPS
    IAssetInterestRateStrategy.InterestRateData irData;
    uint40 addCap; // whole tokens; 0 = TBD, supply blocked until follow-up
    uint40 drawCap; // whole tokens
  }

  // ------------------------------- liquidation engine (global) --------------------------------
  uint256 public constant TARGET_HEALTH_FACTOR = 1.24e18; // WAD
  uint256 public constant HEALTH_FACTOR_FOR_MAX_BONUS = 0.9e18; // WAD

  // ------------------------------- operator roles (Nonce curator) -----------------------------
  // Granular roles carved out of the configurator domain-admin roles, following the Roles.sol
  // evolution rules (next free IDs; domain admins are granted the new roles to retain access).
  uint64 public constant HUB_CAPS_OPERATOR_ROLE = 201; // updateSpokeCaps / AddCap / DrawCap
  uint64 public constant SPOKE_RISK_OPERATOR_ROLE = 401; // add/updateDynamicReserveConfig

  // ------------------------------- shared reserve parameters ----------------------------------
  uint16 internal constant LIQUIDATION_FEE = 10_00; // 10% for every reserve
  uint24 internal constant COLLATERAL_RISK = 0; // risk premium unused at launch

  // maxLiquidationBonus encoding: 100_00 == 0.00% bonus
  uint32 internal constant BONUS_1_0 = 101_00;
  uint32 internal constant BONUS_2_0 = 102_00;
  uint32 internal constant BONUS_3_5 = 103_50;
  uint32 internal constant BONUS_4_0 = 104_00;
  uint32 internal constant BONUS_5_0 = 105_00;

  // ------------------------------------- instance wiring --------------------------------------
  IHubConfigurator public immutable HUB_CONFIGURATOR;
  address public immutable HUB;
  ISpokeConfigurator public immutable SPOKE_CONFIGURATOR;
  address public immutable CASH_SPOKE;
  address public immutable IR_STRATEGY;
  address public immutable FEE_RECEIVER;
  address public immutable ACCESS_MANAGER;
  address public immutable OWNER_SAFE;
  address public immutable OPERATOR_SAFE;

  // ---------------------------------------- underlyings ---------------------------------------
  address public immutable USDC;
  address public immutable USDT;
  address public immutable EURC;
  address public immutable FRXUSD;
  address public immutable WETH;
  address public immutable WEETH;
  address public immutable EBTC;
  address public immutable EUSD;
  address public immutable ETHFI;
  address public immutable SETHFI;
  address public immutable OP;
  address public immutable WHYPE;
  address public immutable BEHYPE;
  address public immutable LIQUID_ETH;
  address public immutable LIQUID_BTC;
  address public immutable LIQUID_USD;
  address public immutable LIQUID_RESERVE;
  address public immutable WEEUR;
  address public immutable LIQUID_RWA;

  // ---------------------------------------- price feeds ---------------------------------------
  address public immutable USDC_FEED;
  address public immutable USDT_FEED;
  address public immutable EURC_FEED;
  address public immutable FRXUSD_FEED;
  address public immutable WETH_FEED;
  address public immutable WEETH_FEED;
  address public immutable EBTC_FEED;
  address public immutable EUSD_FEED;
  address public immutable ETHFI_FEED;
  address public immutable SETHFI_FEED;
  address public immutable OP_FEED;
  address public immutable WHYPE_FEED;
  address public immutable BEHYPE_FEED;
  address public immutable LIQUID_ETH_FEED;
  address public immutable LIQUID_BTC_FEED;
  address public immutable LIQUID_USD_FEED;
  address public immutable LIQUID_RESERVE_FEED;
  address public immutable WEEUR_FEED;
  address public immutable LIQUID_RWA_FEED;

  error MissingInstanceAddress();

  constructor(
    InstanceAddresses memory instance,
    AssetAddresses memory assets
  ) AaveV4Payload(IAaveV4ConfigEngine(instance.configEngine)) {
    require(
      instance.hubConfigurator != address(0) &&
        instance.hub != address(0) &&
        instance.spokeConfigurator != address(0) &&
        instance.cashSpoke != address(0) &&
        instance.irStrategy != address(0) &&
        instance.feeReceiver != address(0) &&
        instance.accessManager != address(0) &&
        instance.ownerSafe != address(0) &&
        instance.operatorSafe != address(0),
      MissingInstanceAddress()
    );

    HUB_CONFIGURATOR = IHubConfigurator(instance.hubConfigurator);
    HUB = instance.hub;
    SPOKE_CONFIGURATOR = ISpokeConfigurator(instance.spokeConfigurator);
    CASH_SPOKE = instance.cashSpoke;
    IR_STRATEGY = instance.irStrategy;
    FEE_RECEIVER = instance.feeReceiver;
    ACCESS_MANAGER = instance.accessManager;
    OWNER_SAFE = instance.ownerSafe;
    OPERATOR_SAFE = instance.operatorSafe;

    USDC = assets.usdc;
    USDC_FEED = assets.usdcFeed;
    USDT = assets.usdt;
    USDT_FEED = assets.usdtFeed;
    EURC = assets.eurc;
    EURC_FEED = assets.eurcFeed;
    FRXUSD = assets.frxUsd;
    FRXUSD_FEED = assets.frxUsdFeed;
    WETH = assets.weth;
    WETH_FEED = assets.wethFeed;
    WEETH = assets.weEth;
    WEETH_FEED = assets.weEthFeed;
    EBTC = assets.eBtc;
    EBTC_FEED = assets.eBtcFeed;
    EUSD = assets.eUsd;
    EUSD_FEED = assets.eUsdFeed;
    ETHFI = assets.ethfi;
    ETHFI_FEED = assets.ethfiFeed;
    SETHFI = assets.sEthfi;
    SETHFI_FEED = assets.sEthfiFeed;
    OP = assets.op;
    OP_FEED = assets.opFeed;
    WHYPE = assets.wHype;
    WHYPE_FEED = assets.wHypeFeed;
    BEHYPE = assets.beHype;
    BEHYPE_FEED = assets.beHypeFeed;
    LIQUID_ETH = assets.liquidEth;
    LIQUID_ETH_FEED = assets.liquidEthFeed;
    LIQUID_BTC = assets.liquidBtc;
    LIQUID_BTC_FEED = assets.liquidBtcFeed;
    LIQUID_USD = assets.liquidUsd;
    LIQUID_USD_FEED = assets.liquidUsdFeed;
    LIQUID_RESERVE = assets.liquidReserve;
    LIQUID_RESERVE_FEED = assets.liquidReserveFeed;
    WEEUR = assets.weEur;
    WEEUR_FEED = assets.weEurFeed;
    LIQUID_RWA = assets.liquidRwa;
    LIQUID_RWA_FEED = assets.liquidRwaFeed;
  }

  // ============================================================================================
  //                                     asset specifications
  // ============================================================================================

  /// @notice Launch asset specs, excluding any asset whose underlying or price feed is unset.
  function getAssetSpecs() public view returns (AssetSpec[] memory specs) {
    AssetSpec[19] memory all = _allAssetSpecs();

    uint256 count;
    for (uint256 i; i < all.length; i++) {
      if (all[i].underlying != address(0) && all[i].priceFeed != address(0)) count++;
    }

    specs = new AssetSpec[](count);
    uint256 j;
    for (uint256 i; i < all.length; i++) {
      if (all[i].underlying != address(0) && all[i].priceFeed != address(0)) {
        specs[j++] = all[i];
      }
    }
  }

  function _allAssetSpecs() internal view returns (AssetSpec[19] memory specs) {
    // -------- borrowable reserves (final sheet: USDC and WETH only) --------
    // USDC — CF 95%, bonus 1%; fee 5%; kink 92%, base 0%, slope1 4%, slope2 10% (max 14%)
    specs[0] = AssetSpec({
      symbol: 'USDC',
      underlying: USDC,
      priceFeed: USDC_FEED,
      collateralFactor: 95_00,
      maxLiquidationBonus: BONUS_1_0,
      liquidationFee: LIQUIDATION_FEE,
      borrowable: true,
      liquidityFee: 5_00,
      irData: _ir(92_00, 0, 4_00, 10_00),
      addCap: EtherfiCashOpMainnet.USDC_ADD_CAP,
      drawCap: EtherfiCashOpMainnet.USDC_DRAW_CAP
    });
    // WETH — CF 75%, bonus 3.5%; fee 7%; kink 92%, slope1 2.35%, slope2 14% (max 16.35%)
    specs[1] = AssetSpec({
      symbol: 'WETH',
      underlying: WETH,
      priceFeed: WETH_FEED,
      collateralFactor: 75_00,
      maxLiquidationBonus: BONUS_3_5,
      liquidationFee: LIQUIDATION_FEE,
      borrowable: true,
      liquidityFee: 7_00,
      irData: _ir(92_00, 0, 2_35, 14_00),
      addCap: EtherfiCashOpMainnet.WETH_ADD_CAP,
      drawCap: EtherfiCashOpMainnet.WETH_DRAW_CAP
    });

    // -------- collateral-only reserves: flat 0% curve, 0% liquidity fee --------
    specs[2] = _collateralOnly('USDT', USDT, USDT_FEED, 95_00, BONUS_1_0, EtherfiCashOpMainnet.USDT_ADD_CAP);
    specs[3] = _collateralOnly('EURC', EURC, EURC_FEED, 95_00, BONUS_1_0, EtherfiCashOpMainnet.EURC_ADD_CAP);
    specs[4] = _collateralOnly('frxUSD', FRXUSD, FRXUSD_FEED, 95_00, BONUS_1_0, EtherfiCashOpMainnet.FRXUSD_ADD_CAP);
    specs[5] = _collateralOnly('weETH', WEETH, WEETH_FEED, 75_00, BONUS_3_5, EtherfiCashOpMainnet.WEETH_ADD_CAP);
    specs[6] = _collateralOnly('eBTC', EBTC, EBTC_FEED, 72_00, BONUS_5_0, EtherfiCashOpMainnet.EBTC_ADD_CAP);
    specs[7] = _collateralOnly('eUSD', EUSD, EUSD_FEED, 90_00, BONUS_2_0, EtherfiCashOpMainnet.EUSD_ADD_CAP);
    specs[8] = _collateralOnly('ETHFI', ETHFI, ETHFI_FEED, 30_00, BONUS_5_0, EtherfiCashOpMainnet.ETHFI_ADD_CAP);
    specs[9] = _collateralOnly('sETHFI', SETHFI, SETHFI_FEED, 30_00, BONUS_5_0, EtherfiCashOpMainnet.SETHFI_ADD_CAP);
    specs[10] = _collateralOnly('OP', OP, OP_FEED, 30_00, BONUS_5_0, EtherfiCashOpMainnet.OP_ADD_CAP);
    specs[11] = _collateralOnly('WHYPE', WHYPE, WHYPE_FEED, 65_00, BONUS_4_0, EtherfiCashOpMainnet.WHYPE_ADD_CAP);
    specs[12] = _collateralOnly('beHYPE', BEHYPE, BEHYPE_FEED, 60_00, BONUS_5_0, EtherfiCashOpMainnet.BEHYPE_ADD_CAP);
    specs[13] = _collateralOnly('liquidETH', LIQUID_ETH, LIQUID_ETH_FEED, 70_00, BONUS_5_0, EtherfiCashOpMainnet.LIQUID_ETH_ADD_CAP);
    specs[14] = _collateralOnly('liquidBTC', LIQUID_BTC, LIQUID_BTC_FEED, 70_00, BONUS_5_0, EtherfiCashOpMainnet.LIQUID_BTC_ADD_CAP);
    specs[15] = _collateralOnly('liquidUSD', LIQUID_USD, LIQUID_USD_FEED, 80_00, BONUS_2_0, EtherfiCashOpMainnet.LIQUID_USD_ADD_CAP);
    specs[16] = _collateralOnly('liquidRESERVE', LIQUID_RESERVE, LIQUID_RESERVE_FEED, 80_00, BONUS_2_0, EtherfiCashOpMainnet.LIQUID_RESERVE_ADD_CAP);
    specs[17] = _collateralOnly('weEUR', WEEUR, WEEUR_FEED, 80_00, BONUS_2_0, EtherfiCashOpMainnet.WEEUR_ADD_CAP);
    specs[18] = _collateralOnly('liquidRWA', LIQUID_RWA, LIQUID_RWA_FEED, 80_00, BONUS_2_0, EtherfiCashOpMainnet.LIQUID_RWA_ADD_CAP);
  }

  function _ir(
    uint16 optimalUsageRatio,
    uint32 baseDrawnRate,
    uint32 rateGrowthBeforeOptimal,
    uint32 rateGrowthAfterOptimal
  ) internal pure returns (IAssetInterestRateStrategy.InterestRateData memory) {
    return
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: optimalUsageRatio,
        baseDrawnRate: baseDrawnRate,
        rateGrowthBeforeOptimal: rateGrowthBeforeOptimal,
        rateGrowthAfterOptimal: rateGrowthAfterOptimal
      });
  }

  function _collateralOnly(
    string memory symbol,
    address underlying,
    address priceFeed,
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint40 addCap
  ) internal pure returns (AssetSpec memory) {
    return
      AssetSpec({
        symbol: symbol,
        underlying: underlying,
        priceFeed: priceFeed,
        collateralFactor: collateralFactor,
        maxLiquidationBonus: maxLiquidationBonus,
        liquidationFee: LIQUIDATION_FEE,
        borrowable: false,
        liquidityFee: 0,
        irData: _ir(99_00, 0, 0, 0), // flat 0% — no borrow use case at launch
        addCap: addCap, // 0 = TBD pending seed-liquidity decisions; supply blocked until raised
        drawCap: 0
      });
  }

  // ============================================================================================
  //                                       payload actions
  // ============================================================================================

  /// @notice Labels the two new operator roles on the AccessManager.
  function accessManagerRoleUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleUpdate[] memory updates)
  {
    updates = new IAaveV4ConfigEngine.RoleUpdate[](2);
    updates[0] = IAaveV4ConfigEngine.RoleUpdate({
      authority: ACCESS_MANAGER,
      roleId: HUB_CAPS_OPERATOR_ROLE,
      admin: EngineFlags.KEEP_CURRENT_UINT64,
      guardian: EngineFlags.KEEP_CURRENT_UINT64,
      grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
      label: 'HUB_CAPS_OPERATOR_ROLE',
      labelUpdate: false
    });
    updates[1] = IAaveV4ConfigEngine.RoleUpdate({
      authority: ACCESS_MANAGER,
      roleId: SPOKE_RISK_OPERATOR_ROLE,
      admin: EngineFlags.KEEP_CURRENT_UINT64,
      guardian: EngineFlags.KEEP_CURRENT_UINT64,
      grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
      label: 'SPOKE_RISK_OPERATOR_ROLE',
      labelUpdate: false
    });
  }

  /// @notice Moves the cap / dynamic-config selectors from the domain-admin roles (200/400)
  /// to the new granular operator roles (201/401).
  function accessManagerTargetFunctionRoleUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] memory updates)
  {
    bytes4[] memory hubSelectors = new bytes4[](3);
    hubSelectors[0] = IHubConfigurator.updateSpokeCaps.selector;
    hubSelectors[1] = IHubConfigurator.updateSpokeAddCap.selector;
    hubSelectors[2] = IHubConfigurator.updateSpokeDrawCap.selector;

    bytes4[] memory spokeSelectors = new bytes4[](2);
    spokeSelectors[0] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    spokeSelectors[1] = ISpokeConfigurator.updateDynamicReserveConfig.selector;

    updates = new IAaveV4ConfigEngine.TargetFunctionRoleUpdate[](2);
    updates[0] = IAaveV4ConfigEngine.TargetFunctionRoleUpdate({
      authority: ACCESS_MANAGER,
      target: address(HUB_CONFIGURATOR),
      selectors: hubSelectors,
      roleId: HUB_CAPS_OPERATOR_ROLE
    });
    updates[1] = IAaveV4ConfigEngine.TargetFunctionRoleUpdate({
      authority: ACCESS_MANAGER,
      target: address(SPOKE_CONFIGURATOR),
      selectors: spokeSelectors,
      roleId: SPOKE_RISK_OPERATOR_ROLE
    });
  }

  /// @notice Grants the operator roles to the Operator Safe (Nonce risk curator) and to the
  /// Owner Safe — required by the Roles.sol evolution rules, since reassigning selectors away
  /// from the domain-admin roles would otherwise strip the Owner Safe of cap/risk access.
  function accessManagerRoleMemberships()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleMembership[] memory memberships)
  {
    memberships = new IAaveV4ConfigEngine.RoleMembership[](4);
    memberships[0] = _grant(HUB_CAPS_OPERATOR_ROLE, OPERATOR_SAFE);
    memberships[1] = _grant(SPOKE_RISK_OPERATOR_ROLE, OPERATOR_SAFE);
    memberships[2] = _grant(HUB_CAPS_OPERATOR_ROLE, OWNER_SAFE);
    memberships[3] = _grant(SPOKE_RISK_OPERATOR_ROLE, OWNER_SAFE);
  }

  function _grant(
    uint64 roleId,
    address account
  ) internal view returns (IAaveV4ConfigEngine.RoleMembership memory) {
    return
      IAaveV4ConfigEngine.RoleMembership({
        authority: ACCESS_MANAGER,
        roleId: roleId,
        account: account,
        granted: true,
        executionDelay: 0
      });
  }

  function hubAssetListings()
    public
    view
    override
    returns (IAaveV4ConfigEngine.AssetListing[] memory listings)
  {
    AssetSpec[] memory specs = getAssetSpecs();
    listings = new IAaveV4ConfigEngine.AssetListing[](specs.length);
    for (uint256 i; i < specs.length; i++) {
      listings[i] = IAaveV4ConfigEngine.AssetListing({
        hubConfigurator: HUB_CONFIGURATOR,
        hub: HUB,
        underlying: specs[i].underlying,
        feeReceiver: FEE_RECEIVER,
        liquidityFee: specs[i].liquidityFee,
        irStrategy: IR_STRATEGY,
        irData: specs[i].irData,
        tokenization: IAaveV4ConfigEngine.TokenizationSpokeConfig({
          addCap: 0,
          proxyAdminOwner: address(0),
          name: '',
          symbol: ''
        })
      });
    }
  }

  function hubSpokeToAssetsAdditions()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory additions)
  {
    AssetSpec[] memory specs = getAssetSpecs();
    IAaveV4ConfigEngine.SpokeAssetConfig[]
      memory assets = new IAaveV4ConfigEngine.SpokeAssetConfig[](specs.length);
    for (uint256 i; i < specs.length; i++) {
      assets[i] = IAaveV4ConfigEngine.SpokeAssetConfig({
        underlying: specs[i].underlying,
        config: IHub.SpokeConfig({
          addCap: specs[i].addCap,
          drawCap: specs[i].drawCap,
          riskPremiumThreshold: 0,
          // DORMANT LAUNCH (two-phase, mirroring the Aave V4 Avalanche activation): the market
          // is fully configured but unusable until EtherfiCashActivationPayload flips every
          // spoke active — after the live state has been verified on-chain.
          active: false,
          halted: false
        })
      });
    }

    additions = new IAaveV4ConfigEngine.SpokeToAssetsAddition[](1);
    additions[0] = IAaveV4ConfigEngine.SpokeToAssetsAddition({
      hubConfigurator: HUB_CONFIGURATOR,
      hub: HUB,
      spoke: CASH_SPOKE,
      assets: assets
    });
  }

  function spokeReserveListings()
    public
    view
    override
    returns (IAaveV4ConfigEngine.ReserveListing[] memory listings)
  {
    AssetSpec[] memory specs = getAssetSpecs();
    listings = new IAaveV4ConfigEngine.ReserveListing[](specs.length);
    for (uint256 i; i < specs.length; i++) {
      listings[i] = IAaveV4ConfigEngine.ReserveListing({
        spokeConfigurator: SPOKE_CONFIGURATOR,
        spoke: CASH_SPOKE,
        hub: HUB,
        underlying: specs[i].underlying,
        priceSource: specs[i].priceFeed,
        config: ISpoke.ReserveConfig({
          collateralRisk: COLLATERAL_RISK,
          paused: false,
          frozen: false,
          borrowable: specs[i].borrowable,
          receiveSharesEnabled: true
        }),
        dynamicConfig: ISpoke.DynamicReserveConfig({
          collateralFactor: specs[i].collateralFactor,
          maxLiquidationBonus: specs[i].maxLiquidationBonus,
          liquidationFee: specs[i].liquidationFee
        })
      });
    }
  }

  function spokeLiquidationConfigUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory updates)
  {
    updates = new IAaveV4ConfigEngine.LiquidationConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.LiquidationConfigUpdate({
      spokeConfigurator: SPOKE_CONFIGURATOR,
      spoke: CASH_SPOKE,
      targetHealthFactor: TARGET_HEALTH_FACTOR,
      healthFactorForMaxBonus: HEALTH_FACTOR_FOR_MAX_BONUS,
      liquidationBonusFactor: EngineFlags.KEEP_CURRENT // deploy default, unchanged from core
    });
  }
}
