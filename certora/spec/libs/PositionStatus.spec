/**
 * @title PositionStatus Library Specification
 * @notice Formal verification of the PositionStatusMap library.
 * @dev This spec verifies the management of user position flags (borrowing and collateral) using bitwise operations.
 * It relies on summaries of LibBit.sol, which are verified in LibBit.spec.
 * 
 * Verification Scope:
 * - Flag integrity: Ensuring setBorrowing and setUsingAsCollateral only affect the intended reserve.
 * - Search correctness: Verifying that next, nextBorrowing, and nextCollateral correctly find the next active reserve.
 * - Counter integrity: Ensuring collateralCount accurately reflects the number of active collateral positions.
 * - Revert safety: Ensuring all library functions are non-reverting.
 */

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    function setBorrowing(uint256 reserveId, bool borrowing) external envfree;
    function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) external envfree;
    function isUsingAsCollateralOrBorrowing(uint256 reserveId) external returns (bool) envfree;
    function isBorrowing(uint256 reserveId) external returns (bool) envfree;
    function isUsingAsCollateral(uint256 reserveId) external returns (bool) envfree;
    function collateralCount(uint256 reserveCount) external returns (uint256) envfree;
    function next(uint256 startReserveId) external returns (uint256, bool, bool) envfree;
    function nextBorrowing(uint256 startReserveId) external returns (uint256) envfree;
    function nextCollateral(uint256 startReserveId) external returns (uint256) envfree;
    function getBucketWord(uint256 reserveId) external returns (uint256) envfree;

    function _.fls(uint256 word) internal => flsResult(word) expect uint256;
}

////////////////////////////////////////////////////////////////////////////
//                                 GHOSTS                                 //
////////////////////////////////////////////////////////////////////////////

/**
 * @dev flsResult(word) is the position of the last (most significant) set bit in word.
 * Axiomatized based on LibBit.spec proofs.
 */
ghost flsResult(uint256) returns uint256 {
    axiom flsResult(0) == 256;
    axiom forall uint256 word. word != 0 => (word >> flsResult(word) == 1);
}

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title setBorrowing Integrity
 * @notice Verifies that setBorrowing correctly updates the target reserve's flag and preserves all other reserve flags.
 * @link_property PositionStatusMap integrity
 */
rule setBorrowing(uint256 reserveId, bool borrowing) {
    uint256 otherId;
    require reserveId != otherId;
    
    bool borrowingFlagOther = isBorrowing(otherId);
    bool collateralFlagOther = isUsingAsCollateral(otherId);
    
    setBorrowing(reserveId, borrowing);
    
    assert isBorrowing(otherId) == borrowingFlagOther, "Other reserve borrowing flag changed";
    assert isUsingAsCollateral(otherId) == collateralFlagOther, "Other reserve collateral flag changed";
    assert isBorrowing(reserveId) == borrowing, "Target reserve borrowing flag mismatch";
}

/**
 * @title setUsingAsCollateral Integrity
 * @notice Verifies that setUsingAsCollateral correctly updates the target reserve's flag and preserves all other reserve flags.
 * @link_property PositionStatusMap integrity
 */
rule setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) {
    uint256 otherId;
    require reserveId != otherId;
    
    bool borrowingFlagOther = isBorrowing(otherId);
    bool collateralFlagOther = isUsingAsCollateral(otherId);
    
    setUsingAsCollateral(reserveId, usingAsCollateral);
    
    assert isBorrowing(otherId) == borrowingFlagOther, "Other reserve borrowing flag changed";
    assert isUsingAsCollateral(otherId) == collateralFlagOther, "Other reserve collateral flag changed";
    assert isUsingAsCollateral(reserveId) == usingAsCollateral, "Target reserve collateral flag mismatch";
}

/**
 * @title isUsingAsCollateralOrBorrowing Logic
 * @notice Verifies that the combined check correctly reflects the individual borrowing and collateral flags.
 * @link_property PositionStatusMap integrity
 */
rule isUsingAsCollateralOrBorrowing(uint256 reserveId) {
    assert isUsingAsCollateralOrBorrowing(reserveId) <=> (isUsingAsCollateral(reserveId) || isBorrowing(reserveId)), "Combined flag mismatch";
}

/**
 * @title Collateral Count Integrity
 * @notice Verifies that the collateralCount is correctly incremented or decremented when a reserve's collateral status changes.
 * @link_property PositionStatusMap integrity
 */
rule collateralCount(uint256 reserveCount, bool usingAsCollateral, uint256 reserveId) {
    require reserveId < reserveCount;
    
    uint256 countBefore = collateralCount(reserveCount);
    bool flagBefore = isUsingAsCollateral(reserveId);
    
    setUsingAsCollateral(reserveId, usingAsCollateral);
    
    uint256 countAfter = collateralCount(reserveCount);
    
    if (usingAsCollateral == flagBefore) {
        assert countBefore == countAfter, "Count changed without flag change";
    } else {
        assert countAfter == countBefore + (usingAsCollateral ? 1 : -1), "Count delta mismatch";
    }
}

/**
 * @title Next Active Reserve Search
 * @notice Verifies that the 'next' function correctly finds the nearest active reserve (borrowing or collateral) below the start index.
 * @link_property PositionStatusMap integrity
 */
rule next(uint256 startReserveId) {
    uint256 NOT_FOUND = max_uint256;
    uint256 reserveId;
    bool borrowing;
    bool collateral;
    
    // Assume max_uint256 is not a valid reserve ID
    require !isBorrowing(max_uint256) && !isUsingAsCollateral(max_uint256);
    
    reserveId, borrowing, collateral = next(startReserveId);
    
    uint256 nextBorrowingId = nextBorrowing(startReserveId);
    uint256 nextCollateralId = nextCollateral(startReserveId);

    if (reserveId == NOT_FOUND) {
        assert nextBorrowingId == NOT_FOUND && nextCollateralId == NOT_FOUND, "Next found when individual searches failed";
        assert !borrowing && !collateral, "Flags set when no reserve found";
    } else {
        assert nextBorrowingId == reserveId || nextCollateralId == reserveId, "Next ID mismatch with individual searches";
        assert reserveId < startReserveId, "Next ID must be below start ID";
        
        // Ensure no active reserves exist between start and found ID
        uint256 reserveIdBetween;
        assert (reserveIdBetween < startReserveId && reserveIdBetween > reserveId) => 
               (!isBorrowing(reserveIdBetween) && !isUsingAsCollateral(reserveIdBetween)), "Skipped active reserve";

        assert borrowing == isBorrowing(reserveId), "Borrowing flag mismatch";
        assert collateral == isUsingAsCollateral(reserveId), "Collateral flag mismatch";
    }
}

/**
 * @title Next Borrowing Search
 * @notice Verifies that nextBorrowing correctly finds the nearest borrowing reserve below the start index.
 * @link_property PositionStatusMap integrity
 */
rule nextBorrowing(uint256 startReserveId) {
    uint256 NOT_FOUND = max_uint256;
    require !isBorrowing(max_uint256);
    
    uint256 reserveId = nextBorrowing(startReserveId);
    
    if (reserveId != NOT_FOUND) {
        assert reserveId < startReserveId, "Next ID must be below start ID";
        assert isBorrowing(reserveId), "Found reserve is not borrowing";
        
        uint256 reserveIdBetween;
        assert (reserveIdBetween < startReserveId && reserveIdBetween > reserveId) => !isBorrowing(reserveIdBetween), "Skipped borrowing reserve";
    } else {
        uint256 anyId;
        assert anyId < startReserveId => !isBorrowing(anyId), "Failed to find existing borrowing reserve";
    }
}

/**
 * @title Next Collateral Search
 * @notice Verifies that nextCollateral correctly finds the nearest collateral reserve below the start index.
 * @link_property PositionStatusMap integrity
 */
rule nextCollateral(uint256 startReserveId) {
    uint256 NOT_FOUND = max_uint256;
    require !isUsingAsCollateral(max_uint256);
    
    uint256 reserveId = nextCollateral(startReserveId);
    
    if (reserveId != NOT_FOUND) {
        assert reserveId < startReserveId, "Next ID must be below start ID";
        assert isUsingAsCollateral(reserveId), "Found reserve is not using as collateral";
        
        uint256 reserveIdBetween;
        assert (reserveIdBetween < startReserveId && reserveIdBetween > reserveId) => !isUsingAsCollateral(reserveIdBetween), "Skipped collateral reserve";
    } else {
        uint256 anyId;
        assert anyId < startReserveId => !isUsingAsCollateral(anyId), "Failed to find existing collateral reserve";
    }
}

/**
 * @title Revert Safety
 * @notice Ensures that all public/external functions in PositionStatusMap never revert.
 * @link_property PositionStatusMap integrity
 */
rule neverReverts(method f) {
    env e;
    calldataarg args;
    require e.msg.value == 0;
    f@withrevert(e, args);
    assert !lastReverted, "Function reverted";
}
