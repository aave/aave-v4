// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';

import {SpokeDeployUtils} from 'scripts/utils/SpokeDeployUtils.sol';
import {EtherfiCashScriptBase} from 'scripts/etherfi/EtherfiCashScriptBase.s.sol';
import {AaveV4EtherfiCash} from 'src/etherfi/AaveV4EtherfiCash.sol';

/// @title PredeployLiquidationLogic
/// @notice Reproduces the CANONICAL Aave LiquidationLogic on OP Mainnet at
/// {AaveV4EtherfiCash.LIQUIDATION_LOGIC} — the same address as the Ethereum mainnet
/// deployment: Safe Singleton Factory, the canonical salt below, and an init code this
/// repo's checked-out source reproduces byte-for-byte (canonical creation tx
/// 0x81f2dc0c16306fb0efbba3392891f656e0fcd722fd59ff069f83b33f966c68da). Because the CREATE2
/// address commits to the init code hash, the address assertion below proves the deployed
/// library is byte-identical to the canonical one.
///
/// Broadcast from ANY funded account EXCEPT the launch deployer: the instance address pins
/// assume the launch deployer acts from nonce 3 with no interleaved transactions, so its
/// nonce must not move before the instance deployment.
///
/// Usage:
///   dry run:   make etherfi-predeploy-liquidationlogic account=<keystore> dry=1
///   broadcast: make etherfi-predeploy-liquidationlogic account=<keystore>
///   then:      make etherfi-verify-liquidationlogic   (Etherscan source verification)
contract PredeployLiquidationLogicScript is EtherfiCashScriptBase {
  error LaunchDeployerMustNotBroadcast(address broadcaster);
  error CanonicalAddressMismatch(address deployed, address expected);

  /// @dev Salt of the canonical Ethereum mainnet deployment (from its creation tx input).
  bytes32 internal constant CANONICAL_SALT = bytes32(uint256(0x2bdf));

  function run() external returns (address deployed) {
    _requireOpMainnet();

    address expected = AaveV4EtherfiCash.LIQUIDATION_LOGIC;
    if (expected.code.length > 0) {
      console2.log('canonical LiquidationLogic already has code at:', expected);
      return expected;
    }

    vm.startBroadcast();
    (, address broadcaster, ) = vm.readCallers();
    require(
      broadcaster != AaveV4EtherfiCash.LAUNCH_DEPLOYER,
      LaunchDeployerMustNotBroadcast(broadcaster)
    );
    deployed = SpokeDeployUtils.deployLiquidationLogic(CANONICAL_SALT);
    vm.stopBroadcast();

    require(deployed == expected, CanonicalAddressMismatch(deployed, expected));
    console2.log('canonical LiquidationLogic deployed at:', deployed);
    console2.log('next: make etherfi-verify-liquidationlogic (Etherscan source verification)');
  }
}
