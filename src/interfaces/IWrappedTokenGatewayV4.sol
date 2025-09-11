// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

interface IWrappedTokenGatewayV4 {
  error InvalidAddress();
  error InvalidAmount();
  error InvalidReserveId();
  error NativeAmountMismatch();
  error NativeTransferFailed();
  error FallbackForbidden();
  error ReceiveNotAllowed();

  /**
   * @notice Wraps the native asset and supply in the Spoke.
   * @param reserveId Reserve Id for the wrapped asset.
   * @param amount Amount to wrap and supply.
   **/
  function supplyNative(uint256 reserveId, uint256 amount) external payable;

  /**
   * @notice Withdraws the wrapped asset from the Spoke and unwraps it back to the native asset.
   * @param reserveId Reserve Id for the wrapped asset.
   * @param amount Amount to withdraw and unwrap.
   * @param receiver Address that will receive the unwrapped native asset.
   **/
  function withdrawNative(uint256 reserveId, uint256 amount, address receiver) external payable;

  /**
   * @notice Borrows the wrapped asset from the Spoke and unwraps it back to the native asset.
   * @param reserveId Reserve Id for the wrapped asset.
   * @param amount Amount to borrow and unwrap.
   * @param receiver Address that will receive the unwrapped native asset.
   **/
  function borrowNative(uint256 reserveId, uint256 amount, address receiver) external payable;

  /**
   * @notice Wraps the native asset and repay debt on the Spoke.
   * @param reserveId Reserve Id for the wrapped asset.
   * @param amount Amount to wrap and repay.
   **/
  function repayNative(uint256 reserveId, uint256 amount) external payable;

  /**
   * @notice Calls `setUsingAsCollateral` on the spoke on behalf of the user.
   * @param reserveId The reserve identifier of the underlying asset as registered on the spoke.
   * @param usingAsCollateral True if the user wants to use the supply as collateral, false otherwise.
   */
  function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) external payable;

  /**
   * @notice Allows this contract to approve or revoke approval as a positionManager using a signature.
   * @param user The address of the user on whose behalf position manager can act.
   * @param approve True if user wants to approve position manager, false otherwise.
   * @param deadline The deadline for the signature.
   */
  function setUserPositionManagerWithSig(
    address user,
    bool approve,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external payable;

  /**
   * @notice Renounces the positionManager approval given by the caller.
   */
  function renouncePositionManagerRole() external payable;

  /**
   * @notice Renounces the positionManager approval given by an user.
   * @param user The address of the user.
   */
  function renouncePositionManagerRoleForUser(address user) external;

  /**
   * @notice Recovers ERC20 tokens sent to this contract.
   * @param token Address of the ERC20 token to recover.
   * @param to Address to send the recovered tokens to.
   **/
  function recoverToken(address token, address to) external;

  /**
   * @notice Recovers native asset left in this contract.
   * @param to Address to send the recovered native asset to.
   * @param amount Amount of native asset to recover.
   **/
  function recoverNative(address to, uint256 amount) external;
}
