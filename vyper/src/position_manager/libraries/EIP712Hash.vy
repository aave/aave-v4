# pragma version 0.5.0b2

SUPPLY_TYPEHASH: public(constant(bytes32)) = 0xe85497eb293c001e8483fe105efadd1d50aa0dadfc0570b27058031dfceab2e6
WITHDRAW_TYPEHASH: public(constant(bytes32)) = 0x0bc73eb58cf4068a29b9593ef18c0d26b3b4453bd2155424a90cb26a22f41d7f
BORROW_TYPEHASH: public(constant(bytes32)) = 0xe248895a233688ba2a70b6f560472dbc27e35ece0d86914f7d43bf2f7df8025b
REPAY_TYPEHASH: public(constant(bytes32)) = 0xd23fe99a7aac398d03952a098faa8889259d062784bd80ea0f159e4af604c045
SET_USING_AS_COLLATERAL_TYPEHASH: public(constant(bytes32)) = 0xd4350e1f25ecd62a35b50e8cd1e00bc34331ae8c728ee4dbb69ecf1023daecf7
UPDATE_USER_RISK_PREMIUM_TYPEHASH: public(constant(bytes32)) = 0x915106098e3eee1fbe90aebcbfd68e931c539495af63e24066ebeebb638d3023
UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH: public(constant(bytes32)) = 0x4a168dd8b32d260d07d6f0be832e23035a65a47f788675b0b02270c68b987886
WITHDRAW_PERMIT_TYPEHASH: public(constant(bytes32)) = 0x9e6642fd4c06a4c1a5e201f1e41c6b7892fcf06859c796b054c510b80e2a0a3f
BORROW_PERMIT_TYPEHASH: public(constant(bytes32)) = 0x14236ea048da65ffb52a9b32a2c840f24ab374cc31f65faeb7877d22ceca144e
SET_GLOBAL_PERMISSION_PERMIT_TYPEHASH: public(constant(bytes32)) = 0x299f4d5a5eae147b6a362cf3fa36b918afed95d6cc1674d468aa1ba1f75f9313
SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH: public(constant(bytes32)) = 0xf91d20e8b46551cc1f73f5de65a9636c103bf0c6bdcf78bae18e7e31917bbd3a
SET_CAN_UPDATE_USER_RISK_PREMIUM_PERMISSION_PERMIT_TYPEHASH: public(constant(bytes32)) = 0xa9be2c91fce8dae5daef47eb13dddcc78011c3146f9e066896a58fa093b6fbe6
SET_CAN_UPDATE_USER_DYNAMIC_CONFIG_PERMISSION_PERMIT_TYPEHASH: public(constant(bytes32)) = 0x0e3c243284d61e86328d1f15e6b7e5a0f56e428e94005a97dc033c4a5809ac3f


@pure
def hash_action(typehash: bytes32, spoke: address, reserve_id: uint256, amount: uint256, on_behalf_of: address, nonce: uint256, deadline: uint256) -> bytes32:
    return keccak256(abi_encode(typehash, spoke, reserve_id, amount, on_behalf_of, nonce, deadline))


@pure
def hash_collateral(spoke: address, reserve_id: uint256, status: bool, on_behalf_of: address, nonce: uint256, deadline: uint256) -> bytes32:
    return keccak256(abi_encode(SET_USING_AS_COLLATERAL_TYPEHASH, spoke, reserve_id, status, on_behalf_of, nonce, deadline))


@pure
def hash_update(typehash: bytes32, spoke: address, on_behalf_of: address, nonce: uint256, deadline: uint256) -> bytes32:
    return keccak256(abi_encode(typehash, spoke, on_behalf_of, nonce, deadline))


@pure
def hash_reserve_permit(typehash: bytes32, spoke: address, reserve_id: uint256, owner: address, spender: address, amount: uint256, nonce: uint256, deadline: uint256) -> bytes32:
    return keccak256(abi_encode(typehash, spoke, reserve_id, owner, spender, amount, nonce, deadline))


@pure
def hash_permission(typehash: bytes32, spoke: address, delegator: address, delegatee: address, status: bool, nonce: uint256, deadline: uint256) -> bytes32:
    return keccak256(abi_encode(typehash, spoke, delegator, delegatee, status, nonce, deadline))
