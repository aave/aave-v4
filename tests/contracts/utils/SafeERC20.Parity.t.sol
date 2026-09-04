// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';

contract SafeERC20ParityHarness {
  function forceApprove(IERC20 token, address spender, uint256 amount) external {
    SafeERC20.forceApprove(token, spender, amount);
  }

  function safeTransfer(IERC20 token, address receiver, uint256 amount) external {
    SafeERC20.safeTransfer(token, receiver, amount);
  }
}

contract ResetApprovalToken {
  mapping(address => mapping(address => uint256)) public allowance;
  uint256 public resets;

  function approve(address spender, uint256 amount) external returns (bool) {
    if (amount != 0 && allowance[msg.sender][spender] != 0) return false;
    if (amount == 0) ++resets;
    allowance[msg.sender][spender] = amount;
    return true;
  }
}

contract NoReturnToken {
  address public receiver;
  uint256 public amount;

  function transfer(address to, uint256 quantity) external {
    receiver = to;
    amount = quantity;
  }
}

contract SafeERC20ParityTest is Test {
  SafeERC20ParityHarness internal harness;

  function setUp() public {
    harness = vm.envOr('TEST_VYPER', false)
      ? SafeERC20ParityHarness(vm.deployCode('SafeERC20Harness.vy:SafeERC20Harness'))
      : new SafeERC20ParityHarness();
  }

  function test_compat_forceApproveResetsResidualAllowance() public {
    ResetApprovalToken token = new ResetApprovalToken();
    harness.forceApprove(IERC20(address(token)), address(this), 7);
    harness.forceApprove(IERC20(address(token)), address(this), 11);
    assertEq(token.allowance(address(harness), address(this)), 11);
    assertEq(token.resets(), 1);
  }

  function test_compat_optionalTokenReturn() public {
    NoReturnToken token = new NoReturnToken();
    harness.safeTransfer(IERC20(address(token)), address(this), 13);
    assertEq(token.receiver(), address(this));
    assertEq(token.amount(), 13);
  }
}
