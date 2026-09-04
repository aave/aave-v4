# pragma version 0.5.0b2

error SafeERC20FailedOperation:
    token: address

@internal
@view
def _accepted(token: address, response: Bytes[32]) -> bool:
    if len(response) == 0:
        return token.is_contract
    return len(response) == 32 and convert(response, uint256) == 1

@internal
def _call(token: address, data: Bytes[100]):
    # Default failure handling preserves the complete downstream revert data.
    response: Bytes[32] = raw_call(token, data, max_outsize=32)
    if not self._accepted(token, response):
        raise SafeERC20FailedOperation(token)

@internal
def safe_transfer(token: address, receiver: address, amount: uint256):
    self._call(token, abi_encode(receiver, amount, method_id=method_id("transfer(address,uint256)")))

@internal
def safe_transfer_from(token: address, owner: address, receiver: address, amount: uint256):
    self._call(token, abi_encode(owner, receiver, amount, method_id=method_id("transferFrom(address,address,uint256)")))

@internal
def force_approve(token: address, spender: address, amount: uint256):
    data: Bytes[68] = abi_encode(spender, amount, method_id=method_id("approve(address,uint256)"))
    success: bool = False
    response: Bytes[32] = b""
    success, response = raw_call(token, data, max_outsize=32, revert_on_failure=False)
    if not success or not self._accepted(token, response):
        self._call(token, abi_encode(spender, convert(0, uint256), method_id=method_id("approve(address,uint256)")))
        self._call(token, data)
