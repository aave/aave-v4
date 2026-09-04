// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

/// @dev Production-style payload: all action data lives in immutables or literals. `execute()`
/// runs via delegatecall inside the Executor, so payload storage is not readable at execution time.
contract MockTokenizationListingPayload is AaveV4Payload {
  IHubConfigurator internal immutable HUB_CONFIGURATOR;
  address internal immutable HUB;
  address internal immutable UNDERLYING;
  address internal immutable FEE_RECEIVER;
  address internal immutable IR_STRATEGY;
  address internal immutable PROXY_ADMIN_OWNER;

  constructor(
    IAaveV4ConfigEngine configEngine,
    IHubConfigurator hubConfigurator,
    address hub,
    address underlying,
    address feeReceiver,
    address irStrategy,
    address proxyAdminOwner
  ) AaveV4Payload(configEngine) {
    HUB_CONFIGURATOR = hubConfigurator;
    HUB = hub;
    UNDERLYING = underlying;
    FEE_RECEIVER = feeReceiver;
    IR_STRATEGY = irStrategy;
    PROXY_ADMIN_OWNER = proxyAdminOwner;
  }

  function hubAssetListings()
    public
    view
    override
    returns (IAaveV4ConfigEngine.AssetListing[] memory)
  {
    IAaveV4ConfigEngine.AssetListing[] memory listings = new IAaveV4ConfigEngine.AssetListing[](1);
    listings[0] = IAaveV4ConfigEngine.AssetListing({
      hubConfigurator: HUB_CONFIGURATOR,
      hub: HUB,
      underlying: UNDERLYING,
      feeReceiver: FEE_RECEIVER,
      liquidityFee: 5_00,
      irStrategy: IR_STRATEGY,
      irData: IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 80_00,
        baseDrawnRate: 1_00,
        rateGrowthBeforeOptimal: 4_00,
        rateGrowthAfterOptimal: 60_00
      }),
      tokenization: IAaveV4ConfigEngine.TokenizationSpokeConfig({
        addCap: 1000,
        proxyAdminOwner: PROXY_ADMIN_OWNER,
        name: 'Tokenized NEW',
        symbol: 'tNEW'
      })
    });
    return listings;
  }
}
