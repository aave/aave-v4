// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';

import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Bytes} from 'src/dependencies/openzeppelin/Bytes.sol';

import {
  ChainConfig,
  PositionManagersUpdateUtils
} from 'scripts/utils/PositionManagersUpdateUtils.sol';

/// @title PositionManagersUpdateJsonBase
/// @author Aave Labs
/// @notice Emits the Safe Transaction Builder batch file for the Position Managers update.

abstract contract PositionManagersUpdateJsonBase is Script {
  /// @notice Thrown when the script runs against a chain other than the one it was built for.
  error ChainIdMismatch(uint256 expected, uint256 actual);

  /// @notice Thrown when a Position Manager address is still unset.
  error PositionManagerAddressZero();

  /// @notice Thrown when `_decode` meets a selector it does not know how to render.
  error UnsupportedSelector(bytes4 selector);

  /// @notice Builds the batch and writes it to `output/`, ready to import into the Safe.
  function run() external {
    ChainConfig memory cfg = _config();
    require(block.chainid == cfg.chainId, ChainIdMismatch(cfg.chainId, block.chainid));
    require(
      cfg.oldPms.length == cfg.newPms.length,
      PositionManagersUpdateUtils.LengthMismatch(cfg.oldPms.length, cfg.newPms.length)
    );
    for (uint256 i; i < cfg.oldPms.length; ++i) {
      require(cfg.oldPms[i] != address(0), PositionManagerAddressZero());
    }
    for (uint256 i; i < cfg.newPms.length; ++i) {
      require(cfg.newPms[i] != address(0), PositionManagerAddressZero());
    }

    PositionManagersUpdateUtils.Action[] memory actions = PositionManagersUpdateUtils.buildActions(
      cfg
    );

    uint256 createdAt = vm.unixTime();

    string memory json = _buildBatchFile(cfg, actions, createdAt);
    vm.writeFile(_outputFile(), json);
    vm.parseJson(vm.readFile(_outputFile()));

    console.log('chain id  : %s', cfg.chainId);
    console.log('actions   : %s', actions.length);
    console.log('written to: %s', _outputFile());
  }

  /// @dev Override to select the chain.
  function _config() internal pure virtual returns (ChainConfig memory);

  /// @dev Override to set the destination path under `output/`.
  function _outputFile() internal pure virtual returns (string memory);

  /// @dev Override to set `meta.name`, the label the Safe UI shows for the batch.
  function _batchName() internal pure virtual returns (string memory);

  // ─────────────────────────── Decoding ─────────────────────────── //

  /// @dev A call rendered as the Transaction Builder describes it, in ABI order.
  struct DecodedCall {
    string methodName;
    string[] inputNames;
    string[] inputTypes;
    string[] inputValues;
  }

  /// @dev Recovers the method signature and argument values from the raw calldata, so the
  ///      emitted file is derived from the bytes that are actually executed.
  function _decode(
    PositionManagersUpdateUtils.Action memory action
  ) internal pure returns (DecodedCall memory d) {
    bytes4 selector = bytes4(action.data);
    bytes memory args = Bytes.slice(action.data, 4);

    if (selector == ISpokeConfigurator.updatePositionManager.selector) {
      (address spoke, address pm, bool active) = abi.decode(args, (address, address, bool));
      d.methodName = 'updatePositionManager';
      d.inputNames = _arr3('spoke', 'positionManager', 'active');
      d.inputTypes = _arr3('address', 'address', 'bool');
      d.inputValues = _arr3(_addr(spoke), _addr(pm), active ? 'true' : 'false');
      return d;
    }

    if (selector == IPositionManagerBase.registerSpoke.selector) {
      (address spoke, bool registered) = abi.decode(args, (address, bool));
      d.methodName = 'registerSpoke';
      d.inputNames = _arr2('spoke', 'registered');
      d.inputTypes = _arr2('address', 'bool');
      d.inputValues = _arr2(_addr(spoke), registered ? 'true' : 'false');
      return d;
    }

    if (selector == IAccessManager.grantRole.selector) {
      (uint64 roleId, address account, uint32 executionDelay) = abi.decode(
        args,
        (uint64, address, uint32)
      );
      d.methodName = 'grantRole';
      d.inputNames = _arr3('roleId', 'account', 'executionDelay');
      d.inputTypes = _arr3('uint64', 'address', 'uint32');
      d.inputValues = _arr3(vm.toString(roleId), _addr(account), vm.toString(executionDelay));
      return d;
    }

    revert UnsupportedSelector(selector);
  }

  // ─────────────────────── Transaction Builder file ─────────────────────── //

  /// @notice Builds the JSON file that the Safe Transaction Builder can import.
  /// @param cfg The chainconfig to build for.
  /// @param actions The ordered action list.
  /// @param createdAt The timestamp to emit in the file.
  /// @return The final JSON string.
  function _buildBatchFile(
    ChainConfig memory cfg,
    PositionManagersUpdateUtils.Action[] memory actions,
    uint256 createdAt
  ) internal pure returns (string memory) {
    string memory txs;
    for (uint256 i; i < actions.length; ++i) {
      txs = string.concat(txs, i == 0 ? '\n    ' : ',\n    ', _prettyTx(actions[i]));
    }

    return
      string.concat(
        '{\n',
        '  "version": "1.0",\n',
        '  "chainId": "',
        vm.toString(cfg.chainId),
        '",\n',
        '  "createdAt": ',
        vm.toString(createdAt),
        ',\n',
        '  "meta": {\n',
        '    "name": "',
        _batchName(),
        '",\n',
        '    "description": "",\n',
        '    "txBuilderVersion": "2.0.1",\n',
        '    "createdFromSafeAddress": "',
        _addr(PositionManagersUpdateUtils.PROTOCOL_SECURITY_COUNCIL),
        '",\n',
        '    "createdFromOwnerAddress": ""\n',
        '  },\n',
        '  "transactions": [',
        txs,
        '\n  ]\n',
        '}\n'
      );
  }

  /// @notice The readable shape, so a reviewer in the Safe UI sees
  /// @param action The raw action to render.
  /// @return The JSON string for the action pretty-printed in the Transaction Builder.
  function _prettyTx(
    PositionManagersUpdateUtils.Action memory action
  ) internal pure returns (string memory) {
    DecodedCall memory d = _decode(action);
    (string memory inputs, string memory values) = _inputsJson(d);

    return
      string.concat(
        '{\n',
        '      "to": "',
        _addr(action.to),
        '",\n',
        '      "value": "0",\n',
        '      "data": null,\n',
        '      "contractMethod": {\n',
        '        "inputs": [',
        inputs,
        '\n        ],\n',
        '        "name": "',
        d.methodName,
        '",\n',
        '        "payable": false\n',
        '      },\n',
        '      "contractInputsValues": {',
        values,
        '\n      }\n',
        '    }'
      );
  }

  /// @notice Renders the per-argument sections of one transaction entry.
  /// @param d The decoded call to render.
  /// @return inputs The `contractMethod.inputs` array body.
  /// @return values The `contractInputsValues` object body.
  function _inputsJson(
    DecodedCall memory d
  ) private pure returns (string memory inputs, string memory values) {
    for (uint256 i; i < d.inputNames.length; ++i) {
      inputs = string.concat(
        inputs,
        i == 0 ? '\n          ' : ',\n          ',
        '{"name": "',
        d.inputNames[i],
        '", "type": "',
        d.inputTypes[i],
        '", "internalType": "',
        d.inputTypes[i],
        '"}'
      );
      values = string.concat(
        values,
        i == 0 ? '\n        ' : ',\n        ',
        '"',
        d.inputNames[i],
        '": "',
        d.inputValues[i],
        '"'
      );
    }
  }

  // ─────────────────────────── Small helpers ───────────────────────────

  /// @notice EIP-55 mixed case, the same casing the Transaction Builder writes in its own exports.
  function _addr(address a) private pure returns (string memory) {
    return vm.toString(a);
  }

  /// @notice Builds a `string[]` from its arguments, which Solidity has no literal syntax for.
  function _arr2(string memory a, string memory b) private pure returns (string[] memory out) {
    out = new string[](2);
    out[0] = a;
    out[1] = b;
  }

  /// @notice Stands in for the dynamic array literals Solidity does not have.
  function _arr3(
    string memory a,
    string memory b,
    string memory c
  ) private pure returns (string[] memory out) {
    out = new string[](3);
    out[0] = a;
    out[1] = b;
    out[2] = c;
  }
}

/// @title GenerateEthereumJson
/// @author Aave Labs
/// @notice Ethereum batch. 10 Spokes x 2 Position Managers x 4 changes = 80 actions.
contract GenerateEthereumJson is PositionManagersUpdateJsonBase {
  function _config() internal pure override returns (ChainConfig memory) {
    return PositionManagersUpdateUtils.ethereum();
  }

  function _outputFile() internal pure override returns (string memory) {
    return './output/position-managers-update-ethereum.json';
  }

  function _batchName() internal pure override returns (string memory) {
    return 'Replace v4 Position Managers (v0.5.12) - Ethereum';
  }
}

/// @title GenerateAvalancheJson
/// @author Aave Labs
/// @notice Avalanche batch. 1 role grant + 3 Spokes x 2 Position Managers x 4 changes = 25 actions.
contract GenerateAvalancheJson is PositionManagersUpdateJsonBase {
  function _config() internal pure override returns (ChainConfig memory) {
    return PositionManagersUpdateUtils.avalanche();
  }

  function _outputFile() internal pure override returns (string memory) {
    return './output/position-managers-update-avalanche.json';
  }

  function _batchName() internal pure override returns (string memory) {
    return 'Replace v4 Position Managers (v0.5.12) - Avalanche';
  }
}
