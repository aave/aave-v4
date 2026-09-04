# pragma version 0.5.0b2
from spoke import SpokeInstance
from spoke.libraries import ReserveFlagsMap
from hub.interfaces import IHub
from spoke.interfaces import ISpoke

initializes: SpokeInstance
exports: SpokeInstance.__interface__

@deploy
def __init__(liquidationLogic_: address, oracle_: address, maxUserReservesLimit_: uint16):
    SpokeInstance.__init__(liquidationLogic_, oracle_, maxUserReservesLimit_)


@external
def borrowWithoutHfCheck(reserveId: uint256, amount: uint256, onBehalfOf: address) -> (uint256, uint256):
    SpokeInstance._enter_nonreentrant()
    SpokeInstance._only_position_manager(onBehalfOf)
    reserve: ISpoke.Reserve = SpokeInstance._require_reserve(reserveId)
    if ReserveFlagsMap.paused(reserve.flags):
        raise ISpoke.ReservePaused()
    if ReserveFlagsMap.frozen(reserve.flags):
        raise ISpoke.ReserveFrozen()
    if not ReserveFlagsMap.borrowable(reserve.flags):
        raise ISpoke.ReserveNotBorrowable()
    drawn_shares: uint256 = extcall IHub(reserve.hub).draw(convert(reserve.assetId, uint256), amount, msg.sender)
    position: ISpoke.UserPosition = SpokeInstance._load_user_position(onBehalfOf, reserveId)
    position.drawnShares = SpokeInstance._u120(convert(position.drawnShares, uint256) + drawn_shares)
    SpokeInstance._store_user_position(onBehalfOf, reserveId, position)
    borrowing: bool = False
    _collateral: bool = False
    borrowing, _collateral = SpokeInstance._reserve_status(onBehalfOf, reserveId)
    if not borrowing:
        if SpokeInstance.MAX_USER_RESERVES_LIMIT != max_value(uint16) and SpokeInstance._borrow_count(onBehalfOf) >= convert(SpokeInstance.MAX_USER_RESERVES_LIMIT, uint256):
            raise ISpoke.MaximumUserReservesExceeded()
        SpokeInstance._set_borrowing(onBehalfOf, reserveId, True)
    SpokeInstance._refresh_configs(onBehalfOf)
    account: ISpoke.UserAccountData = SpokeInstance._account_data(onBehalfOf)
    log ISpoke.RefreshAllUserDynamicConfig(user=onBehalfOf)
    SpokeInstance._notify_risk_premium(onBehalfOf, account.riskPremium)
    log ISpoke.Borrow(reserveId=reserveId, caller=msg.sender, user=onBehalfOf, drawnShares=drawn_shares, drawnAmount=amount)
    SpokeInstance._exit_nonreentrant()
    return drawn_shares, amount


@external
def calculateUserAccountData(user: address, refreshConfig: bool) -> ISpoke.UserAccountData:
    if refreshConfig:
        SpokeInstance._refresh_configs(user)
    return SpokeInstance._account_data(user)


@external
def setReserveDynamicConfigKey(reserveId: uint256, configKey: uint32):
    reserve: ISpoke.Reserve = SpokeInstance._load_reserve(reserveId)
    reserve.dynamicConfigKey = configKey
    SpokeInstance._store_reserve(reserveId, reserve)
