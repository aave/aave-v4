# pragma version 0.5.0a3

from spoke.libraries import SpokeUtils

initializes: SpokeUtils


struct Reserve:
    underlying: address
    hub: address
    assetId: uint16
    decimals: uint8
    collateralRisk: uint24
    flags: uint8
    dynamicConfigKey: uint32


reserves: HashMap[uint256, Reserve]


@external
def setReserve(reserveId: uint256, reserve: Reserve):
    self.reserves[reserveId] = reserve


@external
@view
def get(reserveId: uint256) -> Reserve:
    reserve: Reserve = self.reserves[reserveId]
    if reserve.hub == empty(address):
        raw_revert(method_id("ReserveNotListed()"))
    return reserve


@external
@pure
def toValue(amount: uint256, decimals: uint256, price: uint256) -> uint256:
    return SpokeUtils.to_value(amount, decimals, price)
