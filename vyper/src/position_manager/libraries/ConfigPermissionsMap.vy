# pragma version 0.5.0a3

CAN_SET_USING_AS_COLLATERAL_MASK: public(constant(uint8)) = 1
CAN_UPDATE_USER_RISK_PREMIUM_MASK: public(constant(uint8)) = 2
CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK: public(constant(uint8)) = 4
GLOBAL_PERMISSIONS_MASK: public(constant(uint8)) = 7


@pure
def _set_status(permissions: uint8, mask: uint8, status: bool) -> uint8:
    if status:
        return permissions | mask
    return permissions & (255 ^ mask)


@pure
def set_global_permissions(status: bool) -> uint8:
    return GLOBAL_PERMISSIONS_MASK if status else 0


@pure
def set_can_set_using_as_collateral(permissions: uint8, status: bool) -> uint8:
    return self._set_status(permissions, CAN_SET_USING_AS_COLLATERAL_MASK, status)


@pure
def set_can_update_user_risk_premium(permissions: uint8, status: bool) -> uint8:
    return self._set_status(permissions, CAN_UPDATE_USER_RISK_PREMIUM_MASK, status)


@pure
def set_can_update_user_dynamic_config(permissions: uint8, status: bool) -> uint8:
    return self._set_status(permissions, CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK, status)


@pure
def can_set_using_as_collateral(permissions: uint8) -> bool:
    return permissions & CAN_SET_USING_AS_COLLATERAL_MASK != 0


@pure
def can_update_user_risk_premium(permissions: uint8) -> bool:
    return permissions & CAN_UPDATE_USER_RISK_PREMIUM_MASK != 0


@pure
def can_update_user_dynamic_config(permissions: uint8) -> bool:
    return permissions & CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK != 0
