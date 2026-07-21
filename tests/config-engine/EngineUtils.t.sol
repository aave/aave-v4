// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {EngineUtils} from 'src/config-engine/libraries/EngineUtils.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IV4AddressesProvider} from 'src/addresses-provider/interfaces/IV4AddressesProvider.sol';

/// @dev Wrapper to call EngineUtils library functions externally.
contract EngineUtilsHarness {
  function isConsistentRegistration(
    IAaveV4ConfigEngine.AddressesProviderRegistration calldata registration
  ) external pure returns (bool) {
    return EngineUtils.isConsistentRegistration(registration);
  }
}

contract EngineUtilsTest is Test {
  EngineUtilsHarness internal _harness;

  function setUp() public {
    _harness = new EngineUtilsHarness();
  }

  function _registration(
    address addressesProvider,
    bool register,
    string memory name
  ) internal pure returns (IAaveV4ConfigEngine.AddressesProviderRegistration memory) {
    return
      IAaveV4ConfigEngine.AddressesProviderRegistration({
        addressesProvider: IV4AddressesProvider(addressesProvider),
        register: register,
        name: name
      });
  }

  function test_isConsistentRegistration_register_allFieldsSet() public view {
    assertTrue(_harness.isConsistentRegistration(_registration(address(1), true, 'CORE')));
  }

  function test_isConsistentRegistration_register_noProvider() public view {
    assertFalse(_harness.isConsistentRegistration(_registration(address(0), true, 'CORE')));
  }

  function test_isConsistentRegistration_register_noName() public view {
    assertFalse(_harness.isConsistentRegistration(_registration(address(1), true, '')));
  }

  function test_isConsistentRegistration_register_allFieldsUnset() public view {
    assertFalse(_harness.isConsistentRegistration(_registration(address(0), true, '')));
  }

  function test_isConsistentRegistration_noRegister_allFieldsUnset() public view {
    assertTrue(_harness.isConsistentRegistration(_registration(address(0), false, '')));
  }

  function test_isConsistentRegistration_noRegister_providerSet() public view {
    assertFalse(_harness.isConsistentRegistration(_registration(address(1), false, '')));
  }

  function test_isConsistentRegistration_noRegister_nameSet() public view {
    assertFalse(_harness.isConsistentRegistration(_registration(address(0), false, 'CORE')));
  }

  function test_isConsistentRegistration_noRegister_allFieldsSet() public view {
    assertFalse(_harness.isConsistentRegistration(_registration(address(1), false, 'CORE')));
  }

  function test_fuzz_isConsistentRegistration(
    address addressesProvider,
    bool register,
    string memory name
  ) public view {
    bool fieldsSet = addressesProvider != address(0) && bytes(name).length > 0;
    bool fieldsUnset = addressesProvider == address(0) && bytes(name).length == 0;
    assertEq(
      _harness.isConsistentRegistration(_registration(addressesProvider, register, name)),
      register ? fieldsSet : fieldsUnset
    );
  }
}
