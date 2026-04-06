/**

Verification of the PositionStatusMap.sol library.
Use summarization of the LibBit.sol library that is verified in LibBit.spec.

To run this spec file:
 certoraRun certora/conf/PositionStatus.conf 

The rules here are used as axioms in the SymbolicPositionStatus.spec file.

**/

methods {
    function setBorrowing(uint256 reserveId, bool borrowing) external envfree;
    function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) external envfree   ;
    function isUsingAsCollateralOrBorrowing(uint256 reserveId) external  returns (bool) envfree;
    function isBorrowing(uint256 reserveId) external  returns (bool) envfree;
    function isUsingAsCollateral(uint256 reserveId) external  returns (bool) envfree;
    function collateralCount(uint256 reserveCount) external  returns (uint256) envfree;
    function next(uint256 startReserveId) external  returns (uint256, bool, bool) envfree;
    function nextBorrowing(uint256 startReserveId) external  returns (uint256) envfree;
    function nextCollateral(uint256 startReserveId) external  returns (uint256) envfree;
    function getBucketWord(uint256 reserveId) external  returns (uint256) envfree;

    function _.fls(uint256 word) internal => flsResult(word) expect uint256;

}


///@dev flsResult(word) is the position of the last (most significant) set bit in word.
// Represented as a ghost based on proof in LibBit.spec rule fls_integrity
ghost flsResult(uint256) returns uint256 {
    // zero case 
    axiom forall uint256 word.  word == 0 <=> flsResult(word) == 256;
    axiom forall uint256 word. word != 0 => word >> flsResult(word) == 1;
}


function getBorrowingBitId(uint256 reserveId) returns uint256 {
    return require_uint256(reserveId % 128) << 1;
}

function getUsingAsCollateralBitId(uint256 reserveId) returns uint256 {
    return require_uint256((require_uint256(reserveId % 128) << 1) + 1);
}

/** @title prove that setBorrowing preserves the flags for any other reserve
and sets the borrowing flag for the given reserve to the given value
**/
rule setBorrowing(uint256 reserveId1, bool borrowing) {
    uint256 reserveId2; uint256 reserveId3;
    bool before = isBorrowing(reserveId2);
    bool collateralFlag = isUsingAsCollateral(reserveId3);
    setBorrowing(reserveId1, borrowing);
    bool after = isBorrowing(reserveId2);
    assert(reserveId1 != reserveId2 => before == after);
    assert(reserveId1 == reserveId2 => borrowing == after);
    assert(collateralFlag == isUsingAsCollateral(reserveId3));
}

/** @title prove that setUsingAsCollateral preserves the flags for any other reserve
and sets the usingAsCollateral flag for the given reserve to the given value
**/
rule setUsingAsCollateral(uint256 reserveId1, bool usingAsCollateral) {
    uint256 reserveId2; uint256 reserveId3;
    bool before = isUsingAsCollateral(reserveId2);
    bool borrowingFlag = isBorrowing(reserveId3);

    setUsingAsCollateral(reserveId1, usingAsCollateral);
    bool after = isUsingAsCollateral(reserveId2);
    assert(reserveId1 != reserveId2 => before == after);
    assert(reserveId1 == reserveId2 => usingAsCollateral == after);
    assert(borrowingFlag == isBorrowing(reserveId3));
}

/** @title prove that isUsingAsCollateralOrBorrowing returns true if the reserve is using as collateral or borrowing
**/
rule isUsingAsCollateralOrBorrowing(uint256 reserveId) {
    assert isUsingAsCollateralOrBorrowing(reserveId) <=> ( isUsingAsCollateral(reserveId) || isBorrowing(reserveId));
}

/** @title prove that collateralCount returns the correct number of reserves due to setUsingAsCollateral
**/
rule collateralCount(uint256 reserveCount, bool usingAsCollateral, uint256 reserveId) {
    /// todo prove in spoke that reserveCount is correct
    require reserveId < reserveCount;
    uint256 countBefore = collateralCount(reserveCount);
    bool flagBefore = isUsingAsCollateral(reserveId);
    setUsingAsCollateral(reserveId, usingAsCollateral);
    uint256 countAfter = collateralCount(reserveCount);
    assert(usingAsCollateral == flagBefore => countBefore == countAfter);
    assert(usingAsCollateral != flagBefore => countAfter == countBefore + (usingAsCollateral ? 1 : -1));
}

/** @title prove that max_uint256 is not a valid reserve id
**/
invariant maxUintNotValidReserveId() 
    !isBorrowing(max_uint256) && !isUsingAsCollateral(max_uint256) {
        preserved setBorrowing(uint256 _reserveId, bool _borrowing) {
            require _reserveId != max_uint256;
        }
        preserved setUsingAsCollateral(uint256 _reserveId, bool _usingAsCollateral) {
            require _reserveId != max_uint256;
        }
    }


/** @title prove that next returns the next reserve id using as collateral or borrowing.
1. compare with nextBorrowing and nextCollateral
2. make sure that any reserve id between the startReserveId and the next reserve id is not using as collateral or borrowing
**/

rule next(uint256 startReserveId) {
    uint256 NOT_FOUND = max_uint256;
    uint256 reserveId;
    bool borrowing;
    bool collateral;
    requireInvariant maxUintNotValidReserveId();
    
    reserveId, borrowing, collateral = next(startReserveId);
    
    uint256 nextBorrowingId = nextBorrowing(startReserveId);
    
    uint256 nextCollateralId = nextCollateral(startReserveId);


    assert(reserveId == NOT_FOUND <=> (nextBorrowingId == NOT_FOUND && nextCollateralId == NOT_FOUND));
    assert(reserveId != NOT_FOUND => (nextBorrowingId == reserveId || nextCollateralId == reserveId));
    assert(reserveId != NOT_FOUND => reserveId < startReserveId);

    uint256 reserveIdBetween;
    
    assert (reserveIdBetween < startReserveId && reserveIdBetween > reserveId)=>(!isBorrowing(reserveIdBetween) && !isUsingAsCollateral(reserveIdBetween));

    assert(reserveId != NOT_FOUND => (borrowing <=> isBorrowing(reserveId)));
    assert(reserveId != NOT_FOUND => (collateral <=> isUsingAsCollateral(reserveId)));
    assert(reserveId != NOT_FOUND => (borrowing <=> nextBorrowingId == reserveId));
    assert(reserveId != NOT_FOUND => (collateral <=> nextCollateralId == reserveId));
}

/** @title prove that nextBorrowing returns the next reserve id borrowing.
1. make sure that any reserve id between the startReserveId and the next reserve id is not borrowing
2. make sure that the next reserve id is borrowing
**/
rule nextBorrowing(uint256 startReserveId) {
    uint256 NOT_FOUND = max_uint256;
    uint256 reserveId;
    requireInvariant maxUintNotValidReserveId();
    reserveId = nextBorrowing(startReserveId);
    assert(reserveId != NOT_FOUND => reserveId < startReserveId);
    assert(reserveId != NOT_FOUND <=> isBorrowing(reserveId));

    uint256 reserveIdBetween;
    assert (reserveIdBetween < startReserveId && reserveIdBetween > reserveId) => !isBorrowing(reserveIdBetween);
    

}

/** @title prove that nextCollateral returns the next reserve id using as collateral.
1. make sure that any reserve id between the startReserveId and the next reserve id is not using as collateral
2. make sure that the next reserve id is using as collateral
**/
rule nextCollateral(uint256 startReserveId, uint256 reserveCount) {
    uint256 NOT_FOUND = max_uint256;
    uint256 reserveId;
    requireInvariant maxUintNotValidReserveId();
    reserveId = nextCollateral(startReserveId);
    assert(reserveId != NOT_FOUND => reserveId < startReserveId); 
    assert(reserveId != NOT_FOUND <=> isUsingAsCollateral(reserveId));

    uint256 reserveIdBetween;
    assert (reserveIdBetween < startReserveId && reserveIdBetween > reserveId) => !isUsingAsCollateral(reserveIdBetween);
}


/** @title prove that all functions of the PositionStatusMap.sol should never revert.
**/
rule neverReverts(method f) {
    env e;
    calldataarg args;
    require e.msg.value == 0;
    f@withrevert(e, args);
    assert !lastReverted;
}
    
    

