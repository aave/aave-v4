# pragma version 0.5.0b2

error AccessManagedUnauthorized:
    caller: address
error AccessManagedInvalidAuthority:
    authority: address

interface IAccessManager:
    def consumeScheduledOp(caller: address, data: Bytes[INF]): nonpayable

consuming_schedule: transient(bool)

@internal
@view
def validate_authority(authority: address):
    if not authority.is_contract:
        raise AccessManagedInvalidAuthority(authority)

@internal
def check_access(authority: address, selector: bytes4, data: Bytes[INF]):
    # AuthorityUtils accepts both legacy bool and extended (bool,uint32) results.
    success: bool = False
    response: Bytes[64] = b""
    success, response = raw_call(
        authority,
        abi_encode(msg.sender, self, selector, method_id=method_id("canCall(address,address,bytes4)")),
        max_outsize=64,
        is_static_call=True,
        revert_on_failure=False,
    )
    immediate: bool = False
    delay: uint256 = 0
    if success:
        # Match AuthorityUtils' zero-initialized 64-byte output area, including
        # legacy and short responses; bytes beyond the output area are ignored.
        padded: Bytes[128] = concat(response, empty(bytes32), empty(bytes32))
        immediate = convert(slice(padded, 0, 32), uint256) != 0
        delay = convert(slice(padded, 32, 32), uint256)
        if delay > convert(max_value(uint32), uint256):
            delay = 0
    if not immediate:
        if delay == 0:
            raise AccessManagedUnauthorized(msg.sender)
        self.consuming_schedule = True
        extcall IAccessManager(authority).consumeScheduledOp(msg.sender, data)
        self.consuming_schedule = False

@external
@view
def isConsumingScheduledOp() -> bytes4:
    if self.consuming_schedule:
        return method_id("isConsumingScheduledOp()", output_type=bytes4)
    return empty(bytes4)
