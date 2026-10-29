// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokeCollateralRiskTierTest is Base {
  function test_collateralRiskTier_denseRankAfterSetup() public view {
    _assertDenseRank(spoke1);
  }

  function test_fuzz_updateReserveConfig_collateralRiskTier(uint256 seed) public {
    uint256 reserveCount = spoke1.getReserveCount();
    for (uint256 i; i < 10; ++i) {
      uint256 rand = uint256(keccak256(abi.encode(seed, i)));
      // a small risk domain forces ties, merges and splits of tiers
      _updateCollateralRisk(
        spoke1,
        rand % reserveCount,
        uint24(((rand >> 128) % 4) * 25_00),
        SPOKE_ADMIN
      );
      _assertDenseRank(spoke1);
    }
  }

  function test_addReserve_collateralRiskTier() public {
    _listReserve(0);
    _assertDenseRank(spoke1);
    _listReserve(MAX_ALLOWED_COLLATERAL_RISK);
    _assertDenseRank(spoke1);
  }

  function test_addReserve_revertsWith_MaxCollateralRiskTiersExceeded() public {
    uint256 distinctRisks = _distinctRiskCount(spoke1);
    // risks above every fixture risk, each one a new tier
    uint24 risk = 900_00;
    for (uint256 i = distinctRisks; i < 256; ++i) {
      _listReserve(++risk);
    }
    _assertDenseRank(spoke1);

    // reusing an existing risk does not add a tier
    _listReserve(risk);

    (uint256 assetId, address priceSource) = _listAsset();
    vm.expectRevert(ISpoke.MaxCollateralRiskTiersExceeded.selector);
    vm.prank(ADMIN);
    spoke1.addReserve(
      address(hub1),
      assetId,
      priceSource,
      _getDefaultReserveConfig(++risk),
      _dynamicConfig()
    );
  }

  function _assertDenseRank(ISpoke spoke) internal view {
    uint256[] memory risks = _risks(spoke);
    for (uint256 reserveId; reserveId < risks.length; ++reserveId) {
      uint256 lowerDistinctRisks;
      for (uint256 other; other < risks.length; ++other) {
        if (risks[other] < risks[reserveId] && _isFirstWithRisk(risks, other)) {
          ++lowerDistinctRisks;
        }
      }
      assertEq(spoke.getReserve(reserveId).collateralRiskTier, lowerDistinctRisks, 'tier');
    }
  }

  function _distinctRiskCount(ISpoke spoke) internal view returns (uint256 count) {
    uint256[] memory risks = _risks(spoke);
    for (uint256 reserveId; reserveId < risks.length; ++reserveId) {
      if (_isFirstWithRisk(risks, reserveId)) ++count;
    }
  }

  function _risks(ISpoke spoke) internal view returns (uint256[] memory risks) {
    risks = new uint256[](spoke.getReserveCount());
    for (uint256 reserveId; reserveId < risks.length; ++reserveId) {
      risks[reserveId] = spoke.getReserve(reserveId).collateralRisk;
    }
  }

  function _isFirstWithRisk(uint256[] memory risks, uint256 index) internal pure returns (bool) {
    for (uint256 other; other < index; ++other) {
      if (risks[other] == risks[index]) return false;
    }
    return true;
  }

  function _listReserve(uint24 collateralRisk) internal {
    (uint256 assetId, address priceSource) = _listAsset();
    vm.prank(ADMIN);
    spoke1.addReserve(
      address(hub1),
      assetId,
      priceSource,
      _getDefaultReserveConfig(collateralRisk),
      _dynamicConfig()
    );
  }

  function _listAsset() internal returns (uint256 assetId, address priceSource) {
    TestnetERC20 token = new TestnetERC20('TKN', 'TKN', 18);
    vm.prank(ADMIN);
    assetId = hub1.addAsset(
      address(token),
      18,
      address(treasurySpoke),
      address(irStrategy),
      abi.encode(_defaultIrData)
    );
    priceSource = _deployMockPriceFeed(spoke1, 1e8);
  }

  function _dynamicConfig() internal pure returns (ISpoke.DynamicReserveConfig memory) {
    return
      ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 10_00
      });
  }
}
