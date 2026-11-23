/*
 * Summaries for the code the Prover's pointer analysis cannot handle.
 *
 * WHY THIS FILE EXISTS
 *   The pointer analysis fails on three pieces of code reached by BabylonSpoke.liquidationCall. In a
 *   function where it fails, the Prover resolves no external call, library delegatecalls included,
 *   so every call ends in a havoc. Each piece is replaced here by a summary that does the same
 *   thing. None of them invents or drops behaviour.
 *
 * REQUIRES
 *   The verified contract must be BabylonSpokeAccountDataHarness (for harnessAccountData), and the
 *   underlying tokens must be contracts of the scene.
 *
 * SUMMARIES
 *   1. KeyValueList.uncheckedAt => uncheckedAtExact.
 *      Why: it reads the array through Arrays.unsafeMemoryAccess, an unchecked assembly mload.
 *      Soundness: the CVL function reads the same element and unpacks it with the same shifts and
 *      mask as KeyValueList.unpack. It ASSERTS the index is in bounds, where the real code reads
 *      whatever memory is there.
 *   2. SafeERC20.safeTransferFrom / safeTransfer => the token's own transferFrom / transfer.
 *      Why: SafeERC20 builds the call in assembly.
 *      Soundness: the real token of the scene is called, with msg.sender set to the contract that
 *      runs SafeERC20 (the Spoke for the liquidation libraries, the Hub for Hub.remove). A false
 *      return is discarded like a revert, as SafeERC20 does. Not modelled: tokens that return
 *      nothing (the OpenZeppelin ERC20 always returns a bool).
 *   3. Spoke._calculateUserAccountData(user) => harnessAccountData(user), an external function of
 *      BabylonSpokeAccountDataHarness that returns _processUserAccountData(user, false).
 *      Why: BabylonSpoke.liquidationCall calls it inside a struct literal. The memory for the
 *      struct is allocated first and the call runs before the struct is filled; the pointer
 *      analysis gives up on that.
 *      Soundness: _calculateUserAccountData is defined as _processUserAccountData(user, false), so
 *      the same code runs on the same state, with the block and msg.sender of the call being
 *      checked. It reads state and calls the oracle and the Hub; it never reads msg.sender.
 */

methods {
    // Summary 1.
    function KeyValueList.uncheckedAt(KeyValueList.List memory list, uint256 idx) internal returns (uint256, uint256)
        => uncheckedAtExact(list, idx);

    // Summary 2. calledContract is the contract running SafeERC20.
    function SafeERC20.safeTransferFrom(address token, address from, address to, uint256 value) internal
        => tokenTransferFrom(calledContract, token, from, to, value);
    function SafeERC20.safeTransfer(address token, address to, uint256 value) internal
        => tokenTransfer(calledContract, token, to, value);

    // Summary 3. e is the environment of the Spoke call being run.
    function Spoke._calculateUserAccountData(address user) internal returns (ISpoke.UserAccountData memory) with (env e)
        => realAccountData(e, user);
}

// KeyValueList.uncheckedAt: element idx, unpacked as KeyValueList.unpack does.
// A packed entry is ((2^32 - 1 - key) << 224) | value, and the all-zero entry unpacks to (0, 0).
function uncheckedAtExact(KeyValueList.List list, uint256 idx) returns (uint256, uint256) {
    assert idx < list._inner.length, "uncheckedAt summary is only exact for an index in bounds";
    uint256 data = list._inner[idx];
    if (data == 0) {
        return (0, 0);
    }
    uint256 key = assert_uint256((2^32 - 1) - (data >> 224));
    uint256 value = data & 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    return (key, value);
}

// SafeERC20.safeTransferFrom: the token's transferFrom, called by `caller`.
function tokenTransferFrom(address caller, address token, address from, address to, uint256 value) {
    env e;
    require e.msg.sender == caller, "Not an assumption: the token is called by the contract running safeTransferFrom.";
    require e.msg.value == 0, "Not an assumption: safeTransferFrom sends no ether.";
    bool success = token.transferFrom(e, from, to, value);
    require success, "Not an assumption: SafeERC20 reverts when the token returns false.";
}

// SafeERC20.safeTransfer: the token's transfer, called by `caller`.
function tokenTransfer(address caller, address token, address to, uint256 value) {
    env e;
    require e.msg.sender == caller, "Not an assumption: the token is called by the contract running safeTransfer.";
    require e.msg.value == 0, "Not an assumption: safeTransfer sends no ether.";
    bool success = token.transfer(e, to, value);
    require success, "Not an assumption: SafeERC20 reverts when the token returns false.";
}

// Spoke._calculateUserAccountData: the real _processUserAccountData(user, false), run as its own call.
function realAccountData(env e, address user) returns ISpoke.UserAccountData {
    return currentContract.harnessAccountData(e, user);
}
