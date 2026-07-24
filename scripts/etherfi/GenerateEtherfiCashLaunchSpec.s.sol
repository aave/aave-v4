// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';

import {EtherfiCashLaunchPayload} from 'src/etherfi/EtherfiCashLaunchPayload.sol';
import {EtherfiCashOpMainnet} from 'src/etherfi/EtherfiCashOpMainnet.sol';
import {DeployEtherfiCashLaunchPayloadScript} from 'scripts/etherfi/DeployEtherfiCashLaunchPayload.s.sol';

/// @title GenerateEtherfiCashLaunchSpec
/// @notice Generates the launch specification document from the payload's own specs, so the
/// document can never drift from what the contract actually does. Writes
/// output/etherfi/launch-spec.md. Optional env: PAYLOAD (deployed address).
///   forge script scripts/etherfi/GenerateEtherfiCashLaunchSpec.s.sol --sig 'generate()' --rpc-url optimism
contract GenerateEtherfiCashLaunchSpecScript is DeployEtherfiCashLaunchPayloadScript {
  function generate() external {
    EtherfiCashLaunchPayload expectedPayload = new EtherfiCashLaunchPayload(
      _instanceAddresses(),
      _assetAddresses()
    );
    EtherfiCashLaunchPayload.AssetSpec[] memory specs = expectedPayload.getAssetSpecs();

    address payloadAddress = vm.envOr('PAYLOAD', address(0));
    address activationAddress = vm.envOr('ACTIVATION', address(0));

    string memory md = '# ether.fi Cash Aave V4 Instance on OP Mainnet - Launch Specification\n\n';
    md = string.concat(
      md,
      '## Summary\n\n',
      'Two-phase launch of the ether.fi Cash Aave V4 whitelabel instance on OP Mainnet, ',
      'mirroring the Aave V4 Avalanche activation (proposal 504). Phase 1 (launch payload) ',
      'configures everything DORMANT: lists ',
      vm.toString(specs.length),
      ' assets on the Hub, registers the Cash Spoke with per-asset caps (active = false), lists ',
      'the reserves with their risk parameters, sets the Spoke liquidation configuration, and ',
      'wires the operator roles. After on-chain verification of the configured state, phase 2 ',
      '(activation payload) enumerates and activates every (asset, spoke) pair. Both phases are ',
      'executed by the Owner Safe via delegatecall Safe transactions.\n\n',
      '## Administration\n\n',
      '| Role | Holder |\n|---|---|\n',
      '| Instance owner / payload executor | Owner Safe ',
      vm.toString(EtherfiCashOpMainnet.OWNER_SAFE),
      ' |\n| Caps + dynamic risk config operator | Operator Safe (Nonce Capital) ',
      vm.toString(EtherfiCashOpMainnet.OPERATOR_SAFE),
      ' |\n\n',
      'Operator roles carved out by the payload: HUB_CAPS_OPERATOR_ROLE (201) for ',
      'updateSpokeCaps/updateSpokeAddCap/updateSpokeDrawCap on the HubConfigurator, and ',
      'SPOKE_RISK_OPERATOR_ROLE (401) for addDynamicReserveConfig/updateDynamicReserveConfig ',
      'on the SpokeConfigurator. Both roles are also granted to the Owner Safe.\n\n',
      '## Specification\n\n'
    );

    md = string.concat(
      md,
      '### Liquidation engine (Spoke)\n\n',
      '| Parameter | Value |\n|---|---|\n',
      '| Target health factor | 1.24 |\n',
      '| Health factor for max bonus | 0.90 |\n',
      '| Liquidation bonus factor | unchanged (deploy default) |\n\n'
    );

    md = string.concat(
      md,
      '### Reserves\n\n',
      '| Asset | CF | Max liq. bonus | Liq. fee | Borrowable | Liquidity fee | Kink | Base | Slope1 | Slope2 | Add cap | Draw cap |\n',
      '|---|---|---|---|---|---|---|---|---|---|---|---|\n'
    );
    for (uint256 i; i < specs.length; i++) {
      md = string.concat(md, _reserveRow(specs[i]));
    }

    md = string.concat(md, '\n### Addresses\n\n| Contract | Address |\n|---|---|\n');
    md = string.concat(md, _addrRow('Launch payload (phase 1, dormant config)', payloadAddress));
    md = string.concat(md, _addrRow('Activation payload (phase 2)', activationAddress));
    md = string.concat(md, _addrRow('Owner Safe', EtherfiCashOpMainnet.OWNER_SAFE));
    md = string.concat(md, _addrRow('Operator Safe', EtherfiCashOpMainnet.OPERATOR_SAFE));
    md = string.concat(md, _addrRow('AccessManager', expectedPayload.ACCESS_MANAGER()));
    md = string.concat(md, _addrRow('Config Engine', address(expectedPayload.CONFIG_ENGINE())));
    md = string.concat(md, _addrRow('Hub', expectedPayload.HUB()));
    md = string.concat(md, _addrRow('Hub Configurator', address(expectedPayload.HUB_CONFIGURATOR())));
    md = string.concat(md, _addrRow('Cash Spoke', expectedPayload.CASH_SPOKE()));
    md = string.concat(
      md,
      _addrRow('Spoke Configurator', address(expectedPayload.SPOKE_CONFIGURATOR()))
    );
    md = string.concat(md, _addrRow('IR Strategy', expectedPayload.IR_STRATEGY()));
    md = string.concat(md, _addrRow('Treasury Spoke (fee receiver)', expectedPayload.FEE_RECEIVER()));
    for (uint256 i; i < specs.length; i++) {
      md = string.concat(md, _addrRow(specs[i].symbol, specs[i].underlying));
      md = string.concat(md, _addrRow(string.concat(specs[i].symbol, ' feed'), specs[i].priceFeed));
    }

    md = string.concat(
      md,
      '\n## Review\n\n',
      'TODO: link payload review reports against the deployed payload address.\n'
    );

    vm.createDir('output/etherfi', true);
    vm.writeFile('output/etherfi/launch-spec.md', md);
    console2.log('wrote output/etherfi/launch-spec.md');
  }

  function _reserveRow(
    EtherfiCashLaunchPayload.AssetSpec memory s
  ) internal view returns (string memory) {
    string memory left = string.concat(
      '| ',
      s.symbol,
      ' | ',
      _bps(s.collateralFactor),
      ' | ',
      _bps(s.maxLiquidationBonus - 100_00),
      ' | ',
      _bps(s.liquidationFee),
      ' | ',
      s.borrowable ? 'yes' : 'no',
      ' | ',
      _bps(s.liquidityFee)
    );
    string memory right = string.concat(
      ' | ',
      _bps(s.irData.optimalUsageRatio),
      ' | ',
      _bps(s.irData.baseDrawnRate),
      ' | ',
      _bps(s.irData.rateGrowthBeforeOptimal),
      ' | ',
      _bps(s.irData.rateGrowthAfterOptimal),
      ' | ',
      vm.toString(s.addCap),
      ' | ',
      vm.toString(s.drawCap),
      ' |\n'
    );
    return string.concat(left, right);
  }

  /// @dev Renders a BPS value as a percent string, e.g. 350 -> "3.5%", 9500 -> "95%".
  function _bps(uint256 value) internal view returns (string memory) {
    uint256 whole = value / 100;
    uint256 frac = value % 100;
    if (frac == 0) return string.concat(vm.toString(whole), '%');
    if (frac % 10 == 0) return string.concat(vm.toString(whole), '.', vm.toString(frac / 10), '%');
    return
      string.concat(vm.toString(whole), '.', frac < 10 ? '0' : '', vm.toString(frac), '%');
  }

  function _addrRow(string memory name, address a) internal view returns (string memory) {
    return string.concat('| ', name, ' | ', a == address(0) ? 'TBD' : vm.toString(a), ' |\n');
  }
}
