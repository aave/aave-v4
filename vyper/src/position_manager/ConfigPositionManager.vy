# pragma version 0.5.0b1

from position_manager import PositionManagerBase
from position_manager.libraries import ConfigPermissionsMap
from position_manager.libraries import EIP712Hash
from utils import NoncesKeyed

initializes: PositionManagerBase
initializes: ConfigPermissionsMap
initializes: EIP712Hash
initializes: NoncesKeyed
exports: PositionManagerBase.__interface__
exports: NoncesKeyed.__interface__


struct Permit:
    spoke: address
    delegator: address
    delegatee: address
    status: bool
    nonce: uint256
    deadline: uint256

interface ISpoke:
    def getUserReserveStatus(reserveId: uint256, user: address) -> (bool, bool): view
    def setUsingAsCollateral(reserveId: uint256, usingAsCollateral: bool, onBehalfOf: address): nonpayable
    def updateUserRiskPremium(onBehalfOf: address): nonpayable
    def updateUserDynamicConfig(onBehalfOf: address): nonpayable


event UpdateConfigPermissions:
    spoke: indexed(address)
    delegator: indexed(address)
    delegatee: indexed(address)
    oldPermissions: uint8
    newPermissions: uint8

event SetUsingAsCollateralOnBehalfOf:
    spoke: indexed(address)
    caller: indexed(address)
    onBehalfOf: indexed(address)
    reserveId: uint256
    usingAsCollateral: bool

event UpdateUserRiskPremiumOnBehalfOf:
    spoke: indexed(address)
    caller: indexed(address)
    onBehalfOf: indexed(address)

event UpdateUserDynamicConfigOnBehalfOf:
    spoke: indexed(address)
    caller: indexed(address)
    onBehalfOf: indexed(address)


SET_GLOBAL_PERMISSION_PERMIT_TYPEHASH: public(constant(bytes32)) = 0x299f4d5a5eae147b6a362cf3fa36b918afed95d6cc1674d468aa1ba1f75f9313
SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH: public(constant(bytes32)) = 0xf91d20e8b46551cc1f73f5de65a9636c103bf0c6bdcf78bae18e7e31917bbd3a
SET_CAN_UPDATE_USER_RISK_PREMIUM_PERMISSION_PERMIT_TYPEHASH: public(constant(bytes32)) = 0xa9be2c91fce8dae5daef47eb13dddcc78011c3146f9e066896a58fa093b6fbe6
SET_CAN_UPDATE_USER_DYNAMIC_CONFIG_PERMISSION_PERMIT_TYPEHASH: public(constant(bytes32)) = 0x0e3c243284d61e86328d1f15e6b7e5a0f56e428e94005a97dc033c4a5809ac3f
DOMAIN_TYPEHASH: constant(bytes32) = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
NAME_HASH: constant(bytes32) = keccak256("ConfigPositionManager")
VERSION_HASH: constant(bytes32) = keccak256("1")

config: HashMap[address, HashMap[address, HashMap[address, uint8]]]


@deploy
def __init__(initialOwner: address):
    PositionManagerBase._initialize_owner(initialOwner)


@pure
@override(PositionManagerBase)
def _multicall_enabled() -> bool:
    return True


@internal
@view
def _domain_separator() -> bytes32:
    return keccak256(abi_encode(DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, chain.id, self))


@internal
def _verify(signer: address, intent_hash: bytes32, nonce: uint256, deadline: uint256, signature: Bytes[INF]):
    if block.timestamp > deadline or len(signature) != 65:
        raw_revert(method_id("InvalidSignature()"))
    digest: bytes32 = keccak256(concat(b"\x19\x01", self._domain_separator(), intent_hash))
    r: bytes32 = convert(slice(signature, 0, 32), bytes32)
    s: bytes32 = convert(slice(signature, 32, 32), bytes32)
    v: uint256 = convert(slice(signature, 64, 1), uint256)
    recovered: address = ecrecover(digest, v, r, s)
    if recovered == empty(address) or recovered != signer:
        raw_revert(method_id("InvalidSignature()"))
    NoncesKeyed._use_checked_nonce(signer, nonce)


@internal
def _update_permissions(spoke: address, delegator: address, delegatee: address, old_permissions: uint8, new_permissions: uint8):
    if delegatee == empty(address):
        raw_revert(method_id("InvalidAddress()"))
    if old_permissions == new_permissions:
        return
    self.config[spoke][delegator][delegatee] = new_permissions
    log UpdateConfigPermissions(
        spoke=spoke,
        delegator=delegator,
        delegatee=delegatee,
        oldPermissions=old_permissions,
        newPermissions=new_permissions,
    )


@internal
def _set_global(spoke: address, delegator: address, delegatee: address, status: bool):
    old_permissions: uint8 = self.config[spoke][delegator][delegatee]
    new_permissions: uint8 = ConfigPermissionsMap.set_global_permissions(status)
    self._update_permissions(spoke, delegator, delegatee, old_permissions, new_permissions)


@internal
def _set_collateral(spoke: address, delegator: address, delegatee: address, status: bool):
    old_permissions: uint8 = self.config[spoke][delegator][delegatee]
    new_permissions: uint8 = ConfigPermissionsMap.set_can_set_using_as_collateral(old_permissions, status)
    self._update_permissions(spoke, delegator, delegatee, old_permissions, new_permissions)


@internal
def _set_risk(spoke: address, delegator: address, delegatee: address, status: bool):
    old_permissions: uint8 = self.config[spoke][delegator][delegatee]
    new_permissions: uint8 = ConfigPermissionsMap.set_can_update_user_risk_premium(old_permissions, status)
    self._update_permissions(spoke, delegator, delegatee, old_permissions, new_permissions)


@internal
def _set_dynamic(spoke: address, delegator: address, delegatee: address, status: bool):
    old_permissions: uint8 = self.config[spoke][delegator][delegatee]
    new_permissions: uint8 = ConfigPermissionsMap.set_can_update_user_dynamic_config(old_permissions, status)
    self._update_permissions(spoke, delegator, delegatee, old_permissions, new_permissions)


@internal
def _verify_permission(params: Permit, signature: Bytes[INF], typehash: bytes32):
    intent_hash: bytes32 = EIP712Hash.hash_permission(
        typehash,
        params.spoke,
        params.delegator,
        params.delegatee,
        params.status,
        params.nonce,
        params.deadline,
    )
    self._verify(params.delegator, intent_hash, params.nonce, params.deadline, signature)


@external
@view
def DOMAIN_SEPARATOR() -> bytes32:
    return self._domain_separator()


@external
@view
def eip712Domain() -> (bytes1, String[32], String[8], uint256, address, bytes32, DynArray[uint256, INF]):
    extensions: DynArray[uint256, INF] = []
    return 0x0f, "ConfigPositionManager", "1", chain.id, self, empty(bytes32), extensions


@external
def setGlobalPermission(spoke: address, delegatee: address, status: bool):
    PositionManagerBase._check_registered(spoke)
    self._set_global(spoke, msg.sender, delegatee, status)


@external
def setCanSetUsingAsCollateralPermission(spoke: address, delegatee: address, status: bool):
    PositionManagerBase._check_registered(spoke)
    self._set_collateral(spoke, msg.sender, delegatee, status)


@external
def setCanUpdateUserRiskPremiumPermission(spoke: address, delegatee: address, status: bool):
    PositionManagerBase._check_registered(spoke)
    self._set_risk(spoke, msg.sender, delegatee, status)


@external
def setCanUpdateUserDynamicConfigPermission(spoke: address, delegatee: address, status: bool):
    PositionManagerBase._check_registered(spoke)
    self._set_dynamic(spoke, msg.sender, delegatee, status)


@external
def setGlobalPermissionWithSig(params: Permit, signature: Bytes[INF]):
    PositionManagerBase._check_registered(params.spoke)
    self._verify_permission(params, signature, SET_GLOBAL_PERMISSION_PERMIT_TYPEHASH)
    self._set_global(params.spoke, params.delegator, params.delegatee, params.status)


@external
def setCanSetUsingAsCollateralPermissionWithSig(params: Permit, signature: Bytes[INF]):
    PositionManagerBase._check_registered(params.spoke)
    self._verify_permission(params, signature, SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH)
    self._set_collateral(params.spoke, params.delegator, params.delegatee, params.status)


@external
def setCanUpdateUserRiskPremiumPermissionWithSig(params: Permit, signature: Bytes[INF]):
    PositionManagerBase._check_registered(params.spoke)
    self._verify_permission(params, signature, SET_CAN_UPDATE_USER_RISK_PREMIUM_PERMISSION_PERMIT_TYPEHASH)
    self._set_risk(params.spoke, params.delegator, params.delegatee, params.status)


@external
def setCanUpdateUserDynamicConfigPermissionWithSig(params: Permit, signature: Bytes[INF]):
    PositionManagerBase._check_registered(params.spoke)
    self._verify_permission(params, signature, SET_CAN_UPDATE_USER_DYNAMIC_CONFIG_PERMISSION_PERMIT_TYPEHASH)
    self._set_dynamic(params.spoke, params.delegator, params.delegatee, params.status)


@external
def renounceGlobalPermission(spoke: address, delegator: address):
    PositionManagerBase._check_registered(spoke)
    self._set_global(spoke, delegator, msg.sender, False)


@external
def renounceCanUpdateUsingAsCollateralPermission(spoke: address, delegator: address):
    PositionManagerBase._check_registered(spoke)
    self._set_collateral(spoke, delegator, msg.sender, False)


@external
def renounceCanUpdateUserRiskPremiumPermission(spoke: address, delegator: address):
    PositionManagerBase._check_registered(spoke)
    self._set_risk(spoke, delegator, msg.sender, False)


@external
def renounceCanUpdateUserDynamicConfigPermission(spoke: address, delegator: address):
    PositionManagerBase._check_registered(spoke)
    self._set_dynamic(spoke, delegator, msg.sender, False)


@external
def setUsingAsCollateralOnBehalfOf(spoke: address, reserveId: uint256, usingAsCollateral: bool, onBehalfOf: address):
    PositionManagerBase._check_registered(spoke)
    permissions: uint8 = self.config[spoke][onBehalfOf][msg.sender]
    if not ConfigPermissionsMap.can_set_using_as_collateral(permissions):
        raw_revert(method_id("DelegateeNotAllowed()"))
    current_status: bool = False
    borrowing: bool = False
    current_status, borrowing = staticcall ISpoke(spoke).getUserReserveStatus(reserveId, onBehalfOf)
    if current_status == usingAsCollateral:
        return
    extcall ISpoke(spoke).setUsingAsCollateral(reserveId, usingAsCollateral, onBehalfOf)
    log SetUsingAsCollateralOnBehalfOf(
        spoke=spoke,
        caller=msg.sender,
        onBehalfOf=onBehalfOf,
        reserveId=reserveId,
        usingAsCollateral=usingAsCollateral,
    )


@external
def updateUserRiskPremiumOnBehalfOf(spoke: address, onBehalfOf: address):
    PositionManagerBase._check_registered(spoke)
    if not ConfigPermissionsMap.can_update_user_risk_premium(self.config[spoke][onBehalfOf][msg.sender]):
        raw_revert(method_id("DelegateeNotAllowed()"))
    extcall ISpoke(spoke).updateUserRiskPremium(onBehalfOf)
    log UpdateUserRiskPremiumOnBehalfOf(spoke=spoke, caller=msg.sender, onBehalfOf=onBehalfOf)


@external
def updateUserDynamicConfigOnBehalfOf(spoke: address, onBehalfOf: address):
    PositionManagerBase._check_registered(spoke)
    if not ConfigPermissionsMap.can_update_user_dynamic_config(self.config[spoke][onBehalfOf][msg.sender]):
        raw_revert(method_id("DelegateeNotAllowed()"))
    extcall ISpoke(spoke).updateUserDynamicConfig(onBehalfOf)
    log UpdateUserDynamicConfigOnBehalfOf(spoke=spoke, caller=msg.sender, onBehalfOf=onBehalfOf)


@external
@view
def getConfigPermissions(spoke: address, delegatee: address, onBehalfOf: address) -> (bool, bool, bool):
    permissions: uint8 = self.config[spoke][onBehalfOf][delegatee]
    return (
        ConfigPermissionsMap.can_set_using_as_collateral(permissions),
        ConfigPermissionsMap.can_update_user_risk_premium(permissions),
        ConfigPermissionsMap.can_update_user_dynamic_config(permissions),
    )


@external
@payable
def __default__():
    pass
