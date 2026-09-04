# pragma version 0.5.0b2

# Match the repository's OpenZeppelin ECDSA and SignatureChecker semantics.
error ECDSAInvalidSignature:
    pass
error ECDSAInvalidSignatureS:
    s: bytes32

HALF_ORDER: constant(uint256) = 57896044618658097711785492504343953926418782139537452191302581570759080747168
ERC1271_MAGIC: constant(bytes32) = 0x1626ba7e00000000000000000000000000000000000000000000000000000000

@internal
@pure
def recover(digest: bytes32, v: uint256, r: bytes32, s: bytes32) -> address:
    if convert(s, uint256) > HALF_ORDER:
        raise ECDSAInvalidSignatureS(s)
    signer: address = ecrecover(digest, v, r, s)
    if signer == empty(address):
        raise ECDSAInvalidSignature()
    return signer

@internal
@view
def is_valid_signature_now(signer: address, digest: bytes32, signature: Bytes[INF]) -> bool:
    if signer.is_contract:
        success: bool = False
        response: Bytes[32] = b""
        success, response = raw_call(
            signer,
            abi_encode(digest, signature, method_id=method_id("isValidSignature(bytes32,bytes)")),
            max_outsize=32,
            is_static_call=True,
            revert_on_failure=False,
        )
        return success and len(response) == 32 and convert(response, bytes32) == ERC1271_MAGIC
    if len(signature) != 65:
        return False
    r: bytes32 = convert(slice(signature, 0, 32), bytes32)
    s: bytes32 = convert(slice(signature, 32, 32), bytes32)
    v: uint256 = convert(slice(signature, 64, 1), uint256)
    if convert(s, uint256) > HALF_ORDER:
        return False
    recovered: address = ecrecover(digest, v, r, s)
    return recovered != empty(address) and recovered == signer
