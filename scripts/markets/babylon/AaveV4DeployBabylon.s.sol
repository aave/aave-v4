// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {SpokeDeployUtils} from 'scripts/utils/SpokeDeployUtils.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';

/// @title AaveV4DeployBabylon
/// @author Aave Labs
/// @notice Deploys the Babylon market: the Hubs and one BabylonSpoke, with roles and ownership kept
/// by the deployer until `AaveV4BabylonHandover`.
contract AaveV4DeployBabylon is AaveV4DeployBatchBaseScript {
  constructor() AaveV4DeployBatchBaseScript('babylon') {}

  function _getDeployInputs() internal view override returns (InputUtils.FullDeployInputs memory) {
    AaveV4BabylonConfig.Config memory config = _config();
    _requireConfigLibraries(config.librarySalt);
    return AaveV4BabylonConfig.deployInputs(config);
  }

  /// @dev The chain is validated by the config lookup.
  function _expectedChainId() internal view override returns (uint256) {
    return _config().chainId;
  }

  function _config() internal view virtual returns (AaveV4BabylonConfig.Config memory) {
    return AaveV4BabylonConfig.read();
  }

  /// @dev Reverts unless the BabylonSpoke links the libraries deployed at `librarySalt`, so a
  /// deployment never links the libraries of another config.
  function _requireConfigLibraries(bytes32 librarySalt) internal view virtual {
    address liquidationLogic = Create2Utils.computeCreate2Address(
      librarySalt,
      vm.getCode(SpokeDeployUtils.LIQUIDATION_LOGIC_ARTIFACT)
    );
    require(liquidationLogic.code.length > 0, 'config libraries not deployed');
    address babylonLiquidationLogic = Create2Utils.computeCreate2Address(
      librarySalt,
      vm.getCode(SpokeDeployUtils.BABYLON_LIQUIDATION_LOGIC_ARTIFACT)
    );
    require(babylonLiquidationLogic.code.length > 0, 'config libraries not deployed');
    bytes memory babylonSpokeBytecode = BytecodeHelper.getBabylonSpokeBytecode();
    require(
      _containsAddress(babylonSpokeBytecode, liquidationLogic) &&
        _containsAddress(babylonSpokeBytecode, babylonLiquidationLogic),
      'babylon spoke links other libraries'
    );
  }

  function _containsAddress(bytes memory code, address target) internal pure returns (bool) {
    bytes20 needle = bytes20(target);
    for (uint256 i; i + 20 <= code.length; ++i) {
      bytes20 window;
      assembly ('memory-safe') {
        // keep the 20 leading bytes, the word's tail belongs to the next bytes of the code
        window := and(mload(add(add(code, 0x20), i)), not(sub(shl(96, 1), 1)))
      }
      if (window == needle) {
        return true;
      }
    }
    return false;
  }
}
