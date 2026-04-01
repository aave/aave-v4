// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/helpers/tokenization-spoke/TokenizationSpokeHelpers.sol';
import 'tests/setup/Base.t.sol';

contract TokenizationSpokeBaseTest is Base, TokenizationSpokeHelpers {
  ITokenizationSpoke public daiVault;
  string public constant SHARE_NAME = 'Core Hub DAI';
  string public constant SHARE_SYMBOL = 'chDAI';

  function setUp() public virtual override {
    super.setUp();
    daiVault = _deployTokenizationSpoke(
      hub1,
      address(tokenList.dai),
      SHARE_NAME,
      SHARE_SYMBOL,
      ADMIN
    );
    _registerTokenizationSpoke(hub1, daiAssetId, daiVault, ADMIN);
  }

  function _simulateYield(ITokenizationSpoke vault, uint256 amount) internal {
    _simulateYield(vault, amount, address(spoke2), address(irStrategy));
  }
}
