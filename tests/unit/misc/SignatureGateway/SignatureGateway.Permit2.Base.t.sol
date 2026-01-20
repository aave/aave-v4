// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';
import {ISignatureTransfer} from 'lib/permit2/src/interfaces/ISignatureTransfer.sol';
import {DeployPermit2} from 'lib/permit2/test/utils/DeployPermit2.sol';
import {EIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';

contract SignatureGatewayPermit2BaseTest is SignatureGatewayBaseTest, DeployPermit2 {
  bytes32 internal constant _TOKEN_PERMISSIONS_TYPEHASH =
    keccak256('TokenPermissions(address token,uint256 amount)');

  bytes32 internal constant _FULL_SUPPLY_WITNESS_TYPEHASH =
    keccak256(
      'PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,Supply witness)Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)'
    );

  bytes32 internal constant _FULL_REPAY_WITNESS_TYPEHASH =
    keccak256(
      'PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,Repay witness)Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)'
    );

  bytes32 internal PERMIT2_DOMAIN_SEPARATOR;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();
    address permit2 = deployPermit2();
    gateway = ISignatureGateway(new SignatureGateway(ADMIN, permit2));
    (alice, alicePk) = makeAddrAndKey('alice');

    vm.prank(address(ADMIN));
    gateway.registerSpoke(address(spoke1), true);

    PERMIT2_DOMAIN_SEPARATOR = ISignatureTransfer(permit2).DOMAIN_SEPARATOR();

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), true);
  }

  function _permit2SupplyData(
    ISpoke spoke,
    address who,
    uint256 deadline
  )
    internal
    returns (
      ISignatureTransfer.PermitTransferFrom memory permit,
      ISignatureGateway.Supply memory params
    )
  {
    uint256 reserveId = _randomReserveId(spoke);
    uint256 amount = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    address underlying = address(_underlying(spoke, reserveId));
    uint256 nonce = gateway.nonces(who, _randomNonceKey());

    permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({token: underlying, amount: amount}),
      nonce: _randomUnusedPermit2Nonce(who),
      deadline: deadline
    });

    params = ISignatureGateway.Supply({
      spoke: address(spoke),
      reserveId: reserveId,
      amount: amount,
      onBehalfOf: who,
      nonce: nonce,
      deadline: deadline
    });
  }

  function _permit2RepayData(
    ISpoke spoke,
    address who,
    uint256 deadline
  )
    internal
    returns (
      ISignatureTransfer.PermitTransferFrom memory permit,
      ISignatureGateway.Repay memory params
    )
  {
    uint256 reserveId = _randomReserveId(spoke);
    uint256 amount = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    address underlying = address(_underlying(spoke, reserveId));
    uint256 nonce = gateway.nonces(who, _randomNonceKey());

    permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({token: underlying, amount: amount}),
      nonce: _randomUnusedPermit2Nonce(who),
      deadline: deadline
    });

    params = ISignatureGateway.Repay({
      spoke: address(spoke),
      reserveId: reserveId,
      amount: amount,
      onBehalfOf: who,
      nonce: nonce,
      deadline: deadline
    });
  }

  function _getPermit2SupplySignature(
    ISignatureTransfer.PermitTransferFrom memory permit,
    ISignatureGateway.Supply memory params,
    uint256 privateKey
  ) internal view returns (bytes memory) {
    bytes32 witness = _getSupplyWitnessHash(params);
    return _getPermit2WitnessSignature(permit, witness, _FULL_SUPPLY_WITNESS_TYPEHASH, privateKey);
  }

  function _getPermit2RepaySignature(
    ISignatureTransfer.PermitTransferFrom memory permit,
    ISignatureGateway.Repay memory params,
    uint256 privateKey
  ) internal view returns (bytes memory) {
    bytes32 witness = _getRepayWitnessHash(params);
    return _getPermit2WitnessSignature(permit, witness, _FULL_REPAY_WITNESS_TYPEHASH, privateKey);
  }

  function _getPermit2WitnessSignature(
    ISignatureTransfer.PermitTransferFrom memory permit,
    bytes32 witness,
    bytes32 fullTypehash,
    uint256 privateKey
  ) internal view returns (bytes memory) {
    return
      _getPermit2WitnessSignatureForSpender(
        permit,
        witness,
        fullTypehash,
        privateKey,
        address(gateway)
      );
  }

  function _getPermit2WitnessSignatureForSpender(
    ISignatureTransfer.PermitTransferFrom memory permit,
    bytes32 witness,
    bytes32 fullTypehash,
    uint256 privateKey,
    address spender
  ) internal view returns (bytes memory) {
    bytes32 tokenPermissionsHash = keccak256(
      abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted.token, permit.permitted.amount)
    );

    bytes32 structHash = keccak256(
      abi.encode(
        fullTypehash,
        tokenPermissionsHash,
        spender,
        permit.nonce,
        permit.deadline,
        witness
      )
    );

    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', PERMIT2_DOMAIN_SEPARATOR, structHash));

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
    return abi.encodePacked(r, s, v);
  }

  function _getSupplyWitnessHash(
    ISignatureGateway.Supply memory params
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          EIP712Hash.SUPPLY_TYPEHASH,
          params.spoke,
          params.reserveId,
          params.amount,
          params.onBehalfOf,
          params.nonce,
          params.deadline
        )
      );
  }

  function _getRepayWitnessHash(
    ISignatureGateway.Repay memory params
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          EIP712Hash.REPAY_TYPEHASH,
          params.spoke,
          params.reserveId,
          params.amount,
          params.onBehalfOf,
          params.nonce,
          params.deadline
        )
      );
  }

  function _approvePermit2(ISpoke spoke, uint256 reserveId, address who) internal {
    address underlying = address(_underlying(spoke, reserveId));
    vm.startPrank(who);
    IERC20(underlying).approve(gateway.PERMIT2(), type(uint256).max);
    vm.stopPrank();
  }

  /// @dev Returns a random unused Permit2 nonce for the given owner.
  /// Permit2 uses unordered nonces with a bitmap - nonce is split into wordPos (upper 248 bits)
  /// and bitPos (lower 8 bits). A nonce is unused if its bit is 0 in the bitmap.
  function _randomUnusedPermit2Nonce(address owner) internal returns (uint256) {
    ISignatureTransfer permit2 = ISignatureTransfer(gateway.PERMIT2());
    uint256 nonce;
    uint256 wordPos;
    uint256 bitPos;
    uint256 bitmap;

    // Generate random nonces until we find an unused one
    do {
      nonce = vm.randomUint();
      wordPos = uint248(nonce >> 8);
      bitPos = uint8(nonce);
      bitmap = permit2.nonceBitmap(owner, wordPos);
    } while ((bitmap & (1 << bitPos)) != 0);

    return nonce;
  }

  /// @dev Asserts that a Permit2 nonce has been consumed (bit is set in bitmap).
  function _assertPermit2NonceConsumed(address owner, uint256 nonce) internal view {
    ISignatureTransfer permit2 = ISignatureTransfer(gateway.PERMIT2());
    uint256 wordPos = uint248(nonce >> 8);
    uint256 bitPos = uint8(nonce);
    uint256 bitmap = permit2.nonceBitmap(owner, wordPos);
    assertTrue((bitmap & (1 << bitPos)) != 0, 'Permit2 nonce not consumed');
  }

  /// @dev Asserts that gateway has no allowance to/from Permit2 for any reserve underlying.
  function _assertGatewayHasNoPermit2Allowance(ISpoke spoke) internal view {
    address permit2 = gateway.PERMIT2();
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); ++reserveId) {
      IERC20 underlying = _underlying(spoke, reserveId);
      assertEq(
        underlying.allowance(address(gateway), permit2),
        0,
        'Gateway has allowance to Permit2'
      );
      assertEq(
        underlying.allowance(permit2, address(gateway)),
        0,
        'Permit2 has allowance to Gateway'
      );
    }
  }
}
