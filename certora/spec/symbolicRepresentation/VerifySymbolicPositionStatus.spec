/**
Verification of the summarization of the PositionStatus.spec library.
All rules of PositionStatus.spec are verified to hold also on the summarization .

To run this spec file:
 certoraRun certora/conf/VerifySymbolicPositionStatus.conf 
**/

import "./SymbolicPositionStatus.spec";
import "../libs/PositionStatus.spec";

use rule setBorrowing;
use rule setUsingAsCollateral;
use rule isUsingAsCollateralOrBorrowing;
use rule collateralCount;
use rule next;
use rule nextBorrowing;
use rule nextCollateral;

