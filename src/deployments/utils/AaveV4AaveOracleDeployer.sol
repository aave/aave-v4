// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';

/// @title AaveV4AaveOracleDeployer
/// @author Aave Labs
/// @notice Deploys the AaveOracle of a Spoke and later binds it to the Spoke.
/// @dev The only deployment helper contract left: every other component is deployed directly from the
///      deployer through the CREATE2 factory. It breaks the Spoke <> AaveOracle cycle: the Spoke
///      implementation takes the oracle in its constructor, and only the oracle's deployer can call
///      `AaveOracle.setSpoke`. A factory-deployed oracle would have the factory as its deployer, and an
///      oracle deployed with CREATE from the deployer would have a nonce-dependent address (I-06).
///      This contract is deployed through the CREATE2 factory and deploys the oracle with CREATE2 from
///      itself, so both addresses are deterministic and this contract can bind the oracle later.
///      `AaveOracle.setSpoke` is one-shot, so `setSpoke` here can succeed only once.
contract AaveV4AaveOracleDeployer {
  /// @notice The only account allowed to call `setSpoke`.
  /// @dev Without it, anyone could bind the oracle first to a Spoke of their own that reports this
  ///      oracle in `ORACLE()`.
  address public immutable OWNER;

  /// @notice The AaveOracle deployed by this contract.
  address public immutable AAVE_ORACLE;

  /// @dev Constructor.
  /// @param owner_ The account allowed to bind the AaveOracle to its Spoke.
  /// @param oracleDecimals_ The decimal precision for the AaveOracle.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(address owner_, uint8 oracleDecimals_, bytes32 salt_) {
    require(owner_ != address(0), 'invalid owner');
    require(oracleDecimals_ > 0, 'invalid oracle decimals');
    OWNER = owner_;
    AAVE_ORACLE = address(new AaveOracle{salt: salt_}({decimals_: oracleDecimals_}));
  }

  /// @notice Binds the AaveOracle to its Spoke.
  /// @dev `AaveOracle.setSpoke` checks that the Spoke uses this oracle and that no Spoke is bound yet.
  /// @param spoke The address of the Spoke proxy using the AaveOracle.
  function setSpoke(address spoke) external {
    require(msg.sender == OWNER, 'only owner');
    IAaveOracle(AAVE_ORACLE).setSpoke(spoke);
  }
}
