#pragma version 0.5.0b2

from utils import NoncesKeyed

initializes: NoncesKeyed
exports: NoncesKeyed.__interface__


@external
def useCheckedNonce(owner: address, keyNonce: uint256):
    NoncesKeyed._use_checked_nonce(owner, keyNonce)
