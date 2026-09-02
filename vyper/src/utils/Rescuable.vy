#pragma version 0.5.0b1


@view
@abstract
def _rescue_guardian() -> address:
    ...


@internal
@view
def _check_rescue_guardian():
    if self._rescue_guardian() != msg.sender:
        raw_revert(method_id("OnlyRescueGuardian()"))


@external
def rescueToken(token: address, to: address, amount: uint256):
    self._check_rescue_guardian()
    result: Bytes[32] = raw_call(
        token,
        concat(
            method_id("transfer(address,uint256)"),
            convert(to, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )
    assert len(result) == 0 or abi_decode(result, bool)


@external
def rescueNative(to: address, amount: uint256):
    self._check_rescue_guardian()
    raw_call(to, b"", value=amount)


@external
@view
def rescueGuardian() -> address:
    return self._rescue_guardian()
