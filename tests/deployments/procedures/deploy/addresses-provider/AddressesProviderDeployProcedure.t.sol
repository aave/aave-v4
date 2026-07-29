// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AddressesProviderDeployProcedureTest is ProceduresBase {
  AddressesProviderDeployProcedureWrapper public addressesProviderDeployProcedureWrapper;

  function setUp() public override {
    super.setUp();
    addressesProviderDeployProcedureWrapper = new AddressesProviderDeployProcedureWrapper();
  }

  function test_deployAddressesProvider() public {
    (
      address addressesProviderProxy,
      address addressesProviderImplementation
    ) = addressesProviderDeployProcedureWrapper.deployAddressesProvider(owner, salt);
    assertEq(Ownable(addressesProviderProxy).owner(), owner);
    assertEq(Ownable(ProxyHelper.getProxyAdmin(addressesProviderProxy)).owner(), owner);
    assertNotEq(addressesProviderImplementation, address(0));
    assertEq(
      ProxyHelper.getImplementation(addressesProviderProxy),
      addressesProviderImplementation
    );
  }

  function test_deployAddressesProvider_reverts() public {
    vm.expectRevert('invalid owner');
    addressesProviderDeployProcedureWrapper.deployAddressesProvider({
      owner: address(0),
      salt: salt
    });
  }
}
