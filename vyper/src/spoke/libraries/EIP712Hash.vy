# pragma version 0.5.0b1

SET_USER_POSITION_MANAGERS_TYPEHASH: public(constant(bytes32)) = 0xba01f7bf3d3674c63670ec4a78b0d56aac1ad6e8c84468920b9e61bfe0b9851a
POSITION_MANAGER_UPDATE: public(constant(bytes32)) = 0x187dbd227227274b90655fb4011fc21dd749e8966fc040bd91e0b92609202565
TOKENIZED_DEPOSIT_TYPEHASH: public(constant(bytes32)) = 0xdecc632fabbd6d9f578203db4396740eb2d81cf0fd7681b726d116e49cbc240c
TOKENIZED_MINT_TYPEHASH: public(constant(bytes32)) = 0x12737e595645af6fb99e7985f3dff6fb716ac1ec517c0d2b21313985dc207343
TOKENIZED_WITHDRAW_TYPEHASH: public(constant(bytes32)) = 0xe81b79af873473ec5cb79baa56499159fca87ff2e3333f24183127408a14acb5
TOKENIZED_REDEEM_TYPEHASH: public(constant(bytes32)) = 0x03929148275eed00e4c3ef9c0ee72e49ec6cb96c7a34941708e052f9a511334e
PERMIT_TYPEHASH: public(constant(bytes32)) = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9


@pure
def hash_position_manager_update(position_manager: address, approve: bool) -> bytes32:
    return keccak256(abi_encode(POSITION_MANAGER_UPDATE, position_manager, approve))


@pure
def hash_tokenized(typehash: bytes32, actor: address, amount: uint256, receiver: address, nonce: uint256, deadline: uint256) -> bytes32:
    return keccak256(abi_encode(typehash, actor, amount, receiver, nonce, deadline))
