
/** 
@title This file represents multiple erc20 tokens. 
The functionality it summarize:
- balanceOf
- transfer
- transferFrom 

it simulates the behavior of erc20 tokens including reverting/returning false cases.
**/
methods {
    function _.transfer(address to, uint256 amount) external with (env e)
        => transferCVL(calledContract, e.msg.sender, to, amount) expect bool;
    function _.transferFrom(address from, address to, uint256 amount) external with (env e) 
        => transferFromCVL(calledContract, e.msg.sender, from, to, amount) expect bool;

    function _.safeTransfer(address token, address to, uint256 amount) internal with (env e)
        => safeTransferCVL(token, executingContract, to, amount) expect bool;
    function _.safeTransferFrom(address token, address from, address to, uint256 amount) internal with (env e)
        => safeTransferFromCVL(token, executingContract, from, to, amount) expect bool;
    function _.balanceOf(address account) external => 
        tokenBalanceOf(calledContract, account) expect uint256;
    function _.balanceOf(address token, address account) internal => balanceByToken[token][account] expect uint256;

    function _.permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external => NONDET ALL;

}



/// CVL simple implementations of IERC20:
/// token => account => balance
ghost mapping(address => mapping(address => uint256)) balanceByToken;
/// token => owner => spender => allowance
ghost mapping(address => mapping(address => mapping(address => uint256))) allowanceByToken;


function tokenBalanceOf(address token, address account) returns uint256 {
    return balanceByToken[token][account];
}


function revertOn(bool b) {
    if(b) {
        revert();
    }
}

function transferFromCVL(address token, address spender, address from, address to, uint256 amount) returns bool {
    revertOn(allowanceByToken[token][from][spender] < amount);
    bool success = transferCVL(token, from, to, amount);
    if(success) {
        allowanceByToken[token][from][spender] = assert_uint256(allowanceByToken[token][from][spender] - amount);
    }
    return success;
}

ghost bool revertOrReturnFalse; 
function transferCVL(address token, address from, address to, uint256 amount) returns bool {
    revertOn(token == 0);

    if (balanceByToken[token][from] < amount) {
        if(revertOrReturnFalse) {
             revert();
        }
        else { 
            return false; 
        }
    } 
    balanceByToken[token][from] = assert_uint256(balanceByToken[token][from] - amount);
    balanceByToken[token][to] = require_uint256(balanceByToken[token][to] + amount);  // We neglect overflows.
    return true;
}

function safeTransferCVL(address token, address from, address to, uint256 amount) returns bool {
    if (balanceByToken[token][from] < amount) {
             revert();
    }
    balanceByToken[token][from] = require_uint256(balanceByToken[token][from] - amount);
    balanceByToken[token][to] = require_uint256(balanceByToken[token][to] + amount);  // We neglect overflows.

    return true;
}

function safeTransferFromCVL(address token, address spender, address from, address to, uint256 amount) returns bool {
    bool success = safeTransferCVL(token, from, to, amount);
    if (allowanceByToken[token][from][spender] < amount){
             revert();
    }
    allowanceByToken[token][from][spender] = require_uint256(allowanceByToken[token][from][spender] - amount);
    return true;
}