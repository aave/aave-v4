# pragma version 0.5.0b2

from position_manager.libraries import ConfigPermissionsMap

struct ConfigPermissionValues:
    canSetUsingAsCollateral: bool
    canUpdateUserRiskPremium: bool
    canUpdateUserDynamicConfig: bool


@external
@pure
def setGlobalPermissions(status: bool) -> uint8:
    return ConfigPermissionsMap.set_global_permissions(status)


@external
@pure
def setCanSetUsingAsCollateral(permissions: uint8, status: bool) -> uint8:
    return ConfigPermissionsMap.set_can_set_using_as_collateral(permissions, status)


@external
@pure
def setCanUpdateUserRiskPremium(permissions: uint8, status: bool) -> uint8:
    return ConfigPermissionsMap.set_can_update_user_risk_premium(permissions, status)


@external
@pure
def setCanUpdateUserDynamicConfig(permissions: uint8, status: bool) -> uint8:
    return ConfigPermissionsMap.set_can_update_user_dynamic_config(permissions, status)


@external
@pure
def canSetUsingAsCollateral(permissions: uint8) -> bool:
    return ConfigPermissionsMap.can_set_using_as_collateral(permissions)


@external
@pure
def canUpdateUserRiskPremium(permissions: uint8) -> bool:
    return ConfigPermissionsMap.can_update_user_risk_premium(permissions)


@external
@pure
def canUpdateUserDynamicConfig(permissions: uint8) -> bool:
    return ConfigPermissionsMap.can_update_user_dynamic_config(permissions)


@external
@pure
def getConfigPermissionValues(permissions: uint8) -> ConfigPermissionValues:
    return ConfigPermissionValues(
        canSetUsingAsCollateral=ConfigPermissionsMap.can_set_using_as_collateral(permissions),
        canUpdateUserRiskPremium=ConfigPermissionsMap.can_update_user_risk_premium(permissions),
        canUpdateUserDynamicConfig=ConfigPermissionsMap.can_update_user_dynamic_config(permissions),
    )


@external
@pure
def CAN_SET_USING_AS_COLLATERAL_MASK() -> uint8:
    return ConfigPermissionsMap.CAN_SET_USING_AS_COLLATERAL_MASK


@external
@pure
def CAN_UPDATE_USER_RISK_PREMIUM_MASK() -> uint8:
    return ConfigPermissionsMap.CAN_UPDATE_USER_RISK_PREMIUM_MASK


@external
@pure
def CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK() -> uint8:
    return ConfigPermissionsMap.CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK


@external
@pure
def GLOBAL_PERMISSIONS_MASK() -> uint8:
    return ConfigPermissionsMap.GLOBAL_PERMISSIONS_MASK
