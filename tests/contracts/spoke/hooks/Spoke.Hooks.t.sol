// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';
import {ISpokeHook} from 'src/spoke/interfaces/ISpokeHook.sol';
import {BaseSpokeHook} from 'src/spoke/hooks/BaseSpokeHook.sol';
import {MockSpokeHook} from 'tests/helpers/mocks/MockSpokeHook.sol';

contract SpokeHooksTest is Base {
  MockSpokeHook internal hook;

  function setUp() public override {
    super.setUp();

    hook = new MockSpokeHook(address(spoke1));
    SpokeInstance implementation = new SpokeInstance(
      spoke1.ORACLE(),
      spoke1.MAX_USER_RESERVES_LIMIT(),
      address(hook)
    );

    vm.prank(_getProxyAdminAddress(address(spoke1)));
    ITransparentUpgradeableProxy(address(spoke1)).upgradeToAndCall(address(implementation), '');
  }

  function test_hookReceivesActionContext() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;
    _deal(spoke1, reserveId, alice, amount);
    SpokeActions.approve({spoke: spoke1, reserveId: reserveId, owner: alice, amount: amount});

    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    assertEq(hook.lastSelector(), ISpoke.supply.selector);
    assertEq(hook.lastCaller(), alice);
    assertEq(hook.lastOnBehalfOf(), alice);
  }

  function test_hookCanBlockEverySupportedAction() public {
    bytes4[6] memory selectors = [
      ISpoke.supply.selector,
      ISpoke.withdraw.selector,
      ISpoke.borrow.selector,
      ISpoke.repay.selector,
      ISpoke.liquidationCall.selector,
      ISpoke.setUsingAsCollateral.selector
    ];

    for (uint256 i = 0; i < selectors.length; ++i) {
      hook.setBlockedSelector(selectors[i]);
      vm.expectRevert(
        abi.encodeWithSelector(MockSpokeHook.HookBlocked.selector, selectors[i], alice, alice)
      );
      vm.prank(alice);
      _callAction(selectors[i]);
    }
  }

  function test_baseHookRoutesEverySupportedSelector() public {
    bytes4[6] memory selectors = [
      ISpoke.supply.selector,
      ISpoke.withdraw.selector,
      ISpoke.borrow.selector,
      ISpoke.repay.selector,
      ISpoke.liquidationCall.selector,
      ISpoke.setUsingAsCollateral.selector
    ];

    for (uint256 i = 0; i < selectors.length; ++i) {
      vm.prank(address(spoke1));
      hook.onAction(
        ISpokeHook.HookContext({caller: alice, onBehalfOf: bob, selector: selectors[i]})
      );
      assertEq(hook.lastSelector(), selectors[i]);
      assertEq(hook.lastCaller(), alice);
      assertEq(hook.lastOnBehalfOf(), bob);
    }
  }

  function test_baseHookRejectsUnauthorizedCaller() public {
    vm.expectRevert(
      abi.encodeWithSelector(BaseSpokeHook.UnauthorizedCaller.selector, address(this))
    );
    hook.onAction(
      ISpokeHook.HookContext({caller: alice, onBehalfOf: alice, selector: ISpoke.supply.selector})
    );
  }

  function test_baseHookRejectsUnsupportedSelector() public {
    bytes4 unsupportedSelector = bytes4(keccak256('unsupported()'));
    vm.expectRevert(
      abi.encodeWithSelector(BaseSpokeHook.UnsupportedSelector.selector, unsupportedSelector)
    );
    vm.prank(address(spoke1));
    hook.onAction(
      ISpokeHook.HookContext({caller: alice, onBehalfOf: alice, selector: unsupportedSelector})
    );
  }

  function _callAction(bytes4 selector) internal {
    if (selector == ISpoke.supply.selector) {
      spoke1.supply(0, 0, alice);
    } else if (selector == ISpoke.withdraw.selector) {
      spoke1.withdraw(0, 0, alice);
    } else if (selector == ISpoke.borrow.selector) {
      spoke1.borrow(0, 0, alice);
    } else if (selector == ISpoke.repay.selector) {
      spoke1.repay(0, 0, alice);
    } else if (selector == ISpoke.liquidationCall.selector) {
      spoke1.liquidationCall(0, 0, alice, 0, false);
    } else {
      spoke1.setUsingAsCollateral(0, false, alice);
    }
  }
}
