# pragma version 0.5.0b2

@external
def two_calls(target: address, first: Bytes[INF], second: Bytes[INF]) -> (Bytes[INF], Bytes[INF]):
    a: Bytes[INF] = raw_call(target, first, max_outsize=INF)
    b: Bytes[INF] = raw_call(target, second, max_outsize=INF)
    return a, b

@external
def forward(target: address, data: Bytes[INF]) -> Bytes[INF]:
    return raw_call(target, data, max_outsize=INF)

@external
def capture(target: address, data: Bytes[INF]) -> (bool, Bytes[INF]):
    return raw_call(target, data, max_outsize=INF, revert_on_failure=False)

@external
@view
def static_forward(target: address, data: Bytes[INF]) -> Bytes[INF]:
    return raw_call(target, data, max_outsize=INF, is_static_call=True)

@external
def delegate_forward(target: address, data: Bytes[INF]) -> Bytes[INF]:
    return raw_call(target, data, max_outsize=INF, is_delegate_call=True)

@internal
def _forward(target: address, data: Bytes[INF]) -> Bytes[INF]:
    return raw_call(target, data, max_outsize=INF)

@external
def via_internal(target: address, data: Bytes[INF]) -> Bytes[INF]:
    result: Bytes[INF] = self._forward(target, data)
    return result

@external
def bounded_widened(target: address, data: Bytes[INF]) -> Bytes[INF]:
    result: Bytes[INF] = raw_call(target, data, max_outsize=32)
    return result

@external
def bounded_capture(target: address, data: Bytes[INF]) -> (bool, Bytes[INF]):
    return raw_call(target, data, max_outsize=32, revert_on_failure=False)
