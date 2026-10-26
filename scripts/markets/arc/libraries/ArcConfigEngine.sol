// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4ConfigEngine} from 'src/config-engine/AaveV4ConfigEngine.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

/// @title ArcConfigEngine
/// @author Aave Labs
/// @notice Deploys and locates the `AaveV4ConfigEngine` for the Arc market.
/// @dev The engine is what governance payloads delegatecall into to maintain the market after
/// launch. It is stateless and holds no permissions, so one instance serves every future payload
/// and it is deployed on its own rather than by the deploy orchestration.
///
/// Deployed through the Safe Singleton Factory under a fixed salt, so its address does not depend
/// on the deployer or its nonce, and `predictedAddress` recomputes it rather than the deployment
/// report having to record it.
///
/// It is not deployer-independent in the stronger sense, though. The engine links five engine
/// libraries, and `type(...).creationCode` is only linked bytecode once forge has resolved those
/// library addresses — so the engine's address is a function of where they land. Forge deploys them
/// by CREATE2, which is deterministic for a given library bytecode, and reuses any already on
/// chain; but a toolchain that placed them elsewhere would move the engine too. Recompute from this
/// repo, and treat a recorded deployed address as authoritative over a recomputation elsewhere.
library ArcConfigEngine {
  /// @dev Fixed salt for the Arc config engine. Bump the suffix if the engine is ever redeployed,
  /// since `Create2Utils` refuses to deploy twice to the same address.
  bytes32 internal constant SALT = keccak256('AAVE_V4_ARC_CONFIG_ENGINE_V1');

  /// @notice Deploys the config engine at its deterministic address.
  /// @dev Reverts with `ContractAlreadyDeployed` if it is already there, so re-running is safe.
  /// @return The address of the deployed config engine.
  function deploy() internal returns (address) {
    return Create2Utils.create2Deploy(SALT, type(AaveV4ConfigEngine).creationCode);
  }

  /// @notice The address the config engine has, or will have, on any chain.
  /// @return The deterministic config engine address.
  function predictedAddress() internal pure returns (address) {
    return Create2Utils.computeCreate2Address(SALT, type(AaveV4ConfigEngine).creationCode);
  }
}
