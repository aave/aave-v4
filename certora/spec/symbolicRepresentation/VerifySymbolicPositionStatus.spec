import "./SymbolicPositionStatus.spec";
import "../libs/PositionStatus.spec";

use rule setBorrowing;
use rule setUsingAsCollateral;
use rule isUsingAsCollateralOrBorrowing;
use rule collateralCount;
use rule next;
use rule nextBorrowing;
use rule nextCollateral;


/*
methods {
    function isBorrowing(uint256 reserveId) external returns (bool) envfree;
    function setBorrowing(uint256 reserveId, bool borrowing) external envfree;
}
rule setBorrowing(uint256 reserveId1, bool borrowing) {
    uint256 reserveId2;
    bool before = isBorrowing(reserveId2);
    setBorrowing(reserveId1, borrowing);
    bool after = isBorrowing(reserveId2);
    assert(reserveId1 != reserveId2 => before == after);
    assert(reserveId1 == reserveId2 => borrowing == after);
}*/