# pragma version 0.5.0b2
from utils import SafeERC20

@external
def forceApprove(token: address, spender: address, amount: uint256):
    SafeERC20.force_approve(token, spender, amount)

@external
def safeTransfer(token: address, receiver: address, amount: uint256):
    SafeERC20.safe_transfer(token, receiver, amount)
