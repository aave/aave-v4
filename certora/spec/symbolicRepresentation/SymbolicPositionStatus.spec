/**
Symbolic representation of the PositionStatusMap.sol library.
The summarization of the PositionStatus.spec library is verified to obtain the rules of the PositionStatusMap.sol library.

This summary is used in the Spoke.spec file.

To run this spec file:
 certoraRun certora/conf/VerifySymbolicPositionStatus.conf 


**/

methods {
    function _.setBorrowing(ISpoke.PositionStatus storage positionStatus, uint256 reserveId, bool borrowing) internal => setBorrowingCVL(reserveId, borrowing) expect void;

    function _.setUsingAsCollateral(ISpoke.PositionStatus storage positionStatus, uint256 reserveId, bool usingAsCollateral) internal => setUsingAsCollateralCVL(reserveId, usingAsCollateral) expect void;

    function _.isUsingAsCollateralOrBorrowing(ISpoke.PositionStatus storage positionStatus, uint256 reserveId) internal => isUsingAsCollateralOrBorrowingCVL(reserveId) expect bool;
    
    function _.isBorrowing(ISpoke.PositionStatus storage positionStatus, uint256 reserveId) internal => isBorrowingCVL(reserveId) expect bool;
    
    function _.isUsingAsCollateral(ISpoke.PositionStatus storage positionStatus, uint256 reserveId) internal => isUsingAsCollateralCVL(reserveId) expect bool;
    
    function _.collateralCount(ISpoke.PositionStatus storage positionStatus, uint256 reserveCount) internal => collateralCountCVL(reserveCount) expect uint256;
    
    function _.next(ISpoke.PositionStatus storage positionStatus, uint256 startReserveId) internal => nextCVL(startReserveId) expect (uint256, bool, bool);
    
    function _.nextBorrowing(ISpoke.PositionStatus storage positionStatus, uint256 startReserveId) internal => nextBorrowingCVL(startReserveId) expect uint256;
    
    function _.nextCollateral(ISpoke.PositionStatus storage positionStatus, uint256 startReserveId) internal => nextCollateralCVL(startReserveId) expect uint256;
}

///@dev the user which is updated 
// it is safe to assume that there is only one user involved in each function call
// see  SpokeUserIntegrity.spec rule userIntegrity
persistent ghost address userGhost;

///@dev ghost mapping of the borrowing flags for the user
persistent ghost mapping(address /*user */ => mapping(uint256 /*reserveId*/ => bool /*borrowing*/)) isBorrowing {
    init_state axiom forall address user. forall uint256 reserveId. !isBorrowing[user][reserveId];

}

///@dev ghost mapping of the using as collateral flags for the user
persistent ghost mapping(address /*user */ => mapping(uint256 /*reserveId*/ => bool /*usingAsCollateral*/)) isUsingAsCollateral {
    init_state axiom forall address user. forall uint256 reserveId. !isUsingAsCollateral[user][reserveId];
}



persistent ghost uint256 reserveCountGhost {
    init_state axiom reserveCountGhost == 0;
}


function setBorrowingCVL(uint256 reserveId, bool borrowing) {
    if (borrowing != isBorrowing[userGhost][reserveId]) {
        reserveCountGhost = require_uint256(borrowing ? reserveCountGhost + 1 : reserveCountGhost - 1);
    
    }
    isBorrowing[userGhost][reserveId] = borrowing;
    
}

function isBorrowingCVL(uint256 reserveId) returns (bool) {
    return isBorrowing[userGhost][reserveId];
}

function setUsingAsCollateralCVL(uint256 reserveId, bool usingAsCollateral) {
    if (usingAsCollateral != isUsingAsCollateral[userGhost][reserveId]) {
        reserveCountGhost = require_uint256(usingAsCollateral ? reserveCountGhost + 1 : reserveCountGhost - 1);
    }
    isUsingAsCollateral[userGhost][reserveId] = usingAsCollateral;
    }


function isUsingAsCollateralCVL(uint256 reserveId) returns (bool) {
    return isUsingAsCollateral[userGhost][reserveId];
}

function isUsingAsCollateralOrBorrowingCVL(uint256 reserveId) returns (bool) {
    return isUsingAsCollateral[userGhost][reserveId] || isBorrowing[userGhost][reserveId];
}


function nextCVL(uint256 startReserveId) returns (uint256, bool, bool) {
    uint256 result;
    require (result < startReserveId && result >= startReserveId - 3 ) || result == max_uint256;
    require isUsingAsCollateral[userGhost][result] || isBorrowing[userGhost][result] || result == max_uint256;
    if (result != max_uint256) {
        uint256 between_1 = require_uint256(startReserveId - 1);
        require result < between_1  => (!isUsingAsCollateral[userGhost][between_1] && !isBorrowing[userGhost][between_1]);  
        uint256 between_2 = require_uint256(startReserveId - 2);
        require result < between_2  => (!isUsingAsCollateral[userGhost][between_2] && !isBorrowing[userGhost][between_2]);  
    } else {
        require startReserveId <= 3;
        int end_0 = 0;
        require startReserveId > 0  => (!isUsingAsCollateral[userGhost][0] && !isBorrowing[userGhost][0]); 
        require startReserveId > 1 => (!isUsingAsCollateral[userGhost][1] && !isBorrowing[userGhost][1]);  
        require startReserveId > 2 => (!isUsingAsCollateral[userGhost][2] && !isBorrowing[userGhost][2]);  
        
    }
    return (result, isBorrowing[userGhost][result], isUsingAsCollateral[userGhost][result]);
}

function nextBorrowingCVL(uint256 startReserveId) returns (uint256) {
    uint256 result;
    require result < startReserveId || result == max_uint256;
    require isBorrowing[userGhost][result] || result == max_uint256;
    require !isBorrowing[userGhost][max_uint256];
    if (result != max_uint256) {
        require forall uint256 i. i < startReserveId && i > result => !isBorrowing[userGhost][i];
    } else {
        // no more bits are set
        require forall uint256 i. i < startReserveId => !isBorrowing[userGhost][i];
    }
    return result;
}

function nextCollateralCVL(uint256 startReserveId) returns (uint256) {
    uint256 result;
    require result < startReserveId || result == max_uint256;
    require isUsingAsCollateral[userGhost][result] || result == max_uint256;
    
    require !isUsingAsCollateral[userGhost][max_uint256];
    if (result != max_uint256) {
        require forall uint256 i. i < startReserveId && i > result => !isUsingAsCollateral[userGhost][i];
    } else {
        // no more bits are set
        require forall uint256 i. i < startReserveId => !isUsingAsCollateral[userGhost][i];
    }
    return result;
}
function collateralCountCVL(uint256 ignore) returns (uint256) {
    return reserveCountGhost;
}

