import "./SpokeBase.spec";
import "./symbolicRepresentation/SymbolicHub.spec";

// Methods block for Spoke contract for proving that health factor is checked after updates to the user position which can reduce the health factor
// Note that this does not prove the health check logic itself 
methods {
    
    function Spoke._processUserAccountData(address user, bool refreshConfig) internal returns (ISpoke.UserAccountData memory) => processUserAccountDataCVL(user, refreshConfig);


    // proved in Spoke.spec that this function does not change the user position
    // rule updateUserDynamicConfig_noChangeToDebtValue
    function UserPositionUtils.applyPremiumDelta(ISpoke.UserPosition storage userPosition, IHubBase.PremiumDelta memory premiumDelta) internal => NONDET;
}

persistent ghost mapping(address => uint256) ghostHealthFactor {
    init_state axiom forall address user. ghostHealthFactor[user] == 0;
}

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].drawnShares uint120 newValue (uint120 oldValue) {
    needHealthCheck(user);
}   

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].suppliedShares uint120 newValue (uint120 oldValue) {
    if (isUsingAsCollateral[user][reserveId]) {
        needHealthCheck(user);
    }
}              

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].premiumShares uint120 newValue (uint120 oldValue) {
    needHealthCheck(user);
}
   
hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].premiumOffsetRay int200 newValue (int200 oldValue) {
    needHealthCheck(user);
}

hook Sstore  _positionStatus[KEY address user].map[KEY uint256 slot] uint256 value {
    needHealthCheck(user);
}

function needHealthCheck(address user) {
    uint256 newHealthFactor;
    ghostHealthFactor[user] = newHealthFactor;
}

function processUserAccountDataCVL(address user, bool refreshConfig) returns (ISpoke.UserAccountData) {
    ISpoke.UserAccountData userAccountData;
    require userAccountData.healthFactor == ghostHealthFactor[user];
    return userAccountData;
}

rule userHealthStaysAboveThreshold(method f) filtered {f -> !outOfScopeFunctions(f) && !increaseCollateralOrReduceDebtFunctions(f)}  {
    uint256 HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 10 ^ 18;
    // Get the user address from the method call
    address user;
    env e;
    setup();
    require userGhost == user;
    
    // Check health factor before the operation
    require ghostHealthFactor[user] >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    
    // Execute the operation 
    calldataarg args;
    f(e, args);
    
    // If the operation succeeded, check health factor after
    assert ghostHealthFactor[user] >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
}
