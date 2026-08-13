# pragma version 0.5.0a3

# Vyper 0.5 does not expose an arbitrary-slot SLOAD builtin. Keep the Aave
# ExtSload ABI in Vyper and delegate only that unavailable opcode-level
# primitive to a stateless backend. Delegatecall is required so SLOAD observes
# this contract's storage rather than the backend's storage.

MAX_SLOTS: constant(uint256) = 1024
MAX_RETURN: constant(uint256) = 32 + 32 + MAX_SLOTS * 32

EXTSLOAD_BACKEND: immutable(address)


@deploy
def __init__(backend: address):
    EXTSLOAD_BACKEND = backend


@external
def extSload(slot: bytes32) -> bytes32:
    result: Bytes[32] = raw_call(
        EXTSLOAD_BACKEND,
        msg.data,
        max_outsize=32,
        is_delegate_call=True,
    )
    return abi_decode(result, bytes32)


@external
def extSloads(slots: DynArray[bytes32, MAX_SLOTS]) -> DynArray[bytes32, MAX_SLOTS]:
    result: Bytes[MAX_RETURN] = raw_call(
        EXTSLOAD_BACKEND,
        msg.data,
        max_outsize=MAX_RETURN,
        is_delegate_call=True,
    )
    return abi_decode(result, DynArray[bytes32, MAX_SLOTS])
