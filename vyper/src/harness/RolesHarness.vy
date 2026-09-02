# pragma version 0.5.0b1

from deployments.utils.libraries import Roles

@external
@pure
def ACCESS_MANAGER_ADMIN_ROLE() -> uint64: return Roles.ACCESS_MANAGER_ADMIN_ROLE
@external
@pure
def HUB_DOMAIN_ADMIN_ROLE() -> uint64: return Roles.HUB_DOMAIN_ADMIN_ROLE
@external
@pure
def HUB_CONFIGURATOR_ROLE() -> uint64: return Roles.HUB_CONFIGURATOR_ROLE
@external
@pure
def HUB_FEE_MINTER_ROLE() -> uint64: return Roles.HUB_FEE_MINTER_ROLE
@external
@pure
def HUB_DEFICIT_ELIMINATOR_ROLE() -> uint64: return Roles.HUB_DEFICIT_ELIMINATOR_ROLE
@external
@pure
def HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE() -> uint64: return Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE
@external
@pure
def SPOKE_DOMAIN_ADMIN_ROLE() -> uint64: return Roles.SPOKE_DOMAIN_ADMIN_ROLE
@external
@pure
def SPOKE_CONFIGURATOR_ROLE() -> uint64: return Roles.SPOKE_CONFIGURATOR_ROLE
@external
@pure
def SPOKE_USER_POSITION_UPDATER_ROLE() -> uint64: return Roles.SPOKE_USER_POSITION_UPDATER_ROLE
@external
@pure
def SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE() -> uint64: return Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE
