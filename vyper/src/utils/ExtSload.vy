# pragma version 0.5.0b2

# Vyper 0.5 does not expose an arbitrary-slot SLOAD builtin. Keep the Aave
# ExtSload ABI in Vyper and delegate only that unavailable opcode-level
# primitive to a stateless backend. Delegatecall is required so SLOAD observes
# this contract's storage rather than the backend's storage.

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
def extSloads(slots: DynArray[bytes32, INF]) -> DynArray[bytes32, INF]:
    # `raw_call` still requires a finite return bound in 0.5.0b2. Calling the
    # backend's scalar primitive keeps this public array genuinely unbounded.
    results: DynArray[bytes32, INF] = []
    for slot: bytes32 in slots:
        result: Bytes[32] = raw_call(
            EXTSLOAD_BACKEND,
            concat(method_id("extSload(bytes32)"), slot),
            max_outsize=32,
            is_delegate_call=True,
        )
        results.append(abi_decode(result, bytes32))
    return results
