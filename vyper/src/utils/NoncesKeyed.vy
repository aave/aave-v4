#pragma version 0.5.0b1

nonces_by_owner: HashMap[address, HashMap[uint192, uint256]]


@internal
@pure
def _pack(key: uint192, nonce: uint64) -> uint256:
    return unsafe_mul(convert(key, uint256), 2**64) | convert(nonce, uint256)


@internal
def _use_nonce(owner: address, key: uint192) -> uint256:
    nonce: uint64 = convert(self.nonces_by_owner[owner][key] & (2**64 - 1), uint64)
    self.nonces_by_owner[owner][key] = convert(unsafe_add(nonce, 1), uint256)
    return self._pack(key, nonce)


@internal
def _use_checked_nonce(owner: address, key_nonce: uint256):
    key: uint192 = convert(key_nonce // 2**64, uint192)
    current: uint256 = self._use_nonce(owner, key)
    if key_nonce != current:
        raw_revert(
            concat(
                method_id("InvalidAccountNonce(address,uint256)"),
                convert(owner, bytes32),
                convert(current, bytes32),
            )
        )


@external
def useNonce(key: uint192) -> uint256:
    return self._use_nonce(msg.sender, key)


@external
@view
def nonces(owner: address, key: uint192) -> uint256:
    nonce: uint64 = convert(self.nonces_by_owner[owner][key] & (2**64 - 1), uint64)
    return self._pack(key, nonce)
