// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';
import {ISignatureTransfer} from 'lib/permit2/src/interfaces/ISignatureTransfer.sol';
import {DeployPermit2} from 'lib/permit2/test/utils/DeployPermit2.sol';
import {EIP712Types} from 'tests/mocks/EIP712Types.sol';

contract SignatureGatewayPermit2BaseTest is SignatureGatewayBaseTest, DeployPermit2 {
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
      ISignatureGateway.SupplyAction memory params
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

    params = ISignatureGateway.SupplyAction({
      onBehalfOf: who,
      nonce: nonce,
      deadline: deadline,
      params: ISignatureGateway.SupplyParams({
        spoke: address(spoke),
        reserveId: reserveId,
        amount: amount
      })
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
      ISignatureGateway.RepayAction memory params
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

    params = ISignatureGateway.RepayAction({
      onBehalfOf: who,
      nonce: nonce,
      deadline: deadline,
      params: ISignatureGateway.RepayParams({
        spoke: address(spoke),
        reserveId: reserveId,
        amount: amount
      })
    });
  }

  function _getPermit2SupplySignature(
    ISignatureTransfer.PermitTransferFrom memory permit,
    ISignatureGateway.SupplyAction memory action,
    uint256 privateKey
  ) internal view returns (bytes memory) {
    return _getPermit2SupplySignatureForSpender(permit, action, privateKey, address(gateway));
  }

  function _getPermit2SupplySignatureForSpender(
    ISignatureTransfer.PermitTransferFrom memory permit,
    ISignatureGateway.SupplyAction memory action,
    uint256 privateKey,
    address spender
  ) internal view returns (bytes memory) {
    EIP712Types.PermitWitnessTransferFromSupplyAction memory permitWitness = EIP712Types
      .PermitWitnessTransferFromSupplyAction({
        permitted: EIP712Types.TokenPermissions({
          token: permit.permitted.token,
          amount: permit.permitted.amount
        }),
        spender: spender,
        nonce: permit.nonce,
        deadline: permit.deadline,
        witness: EIP712Types.SupplyAction({
          onBehalfOf: action.onBehalfOf,
          nonce: action.nonce,
          deadline: action.deadline,
          params: EIP712Types.SupplyParams({
            spoke: action.params.spoke,
            reserveId: action.params.reserveId,
            amount: action.params.amount
          })
        })
      });

    bytes32 structHash = vm.eip712HashStruct(
      'PermitWitnessTransferFromSupplyAction',
      abi.encode(permitWitness)
    );

    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', PERMIT2_DOMAIN_SEPARATOR, structHash));

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
    return abi.encodePacked(r, s, v);
  }

  function _getPermit2RepaySignature(
    ISignatureTransfer.PermitTransferFrom memory permit,
    ISignatureGateway.RepayAction memory action,
    uint256 privateKey
  ) internal view returns (bytes memory) {
    return _getPermit2RepaySignatureForSpender(permit, action, privateKey, address(gateway));
  }

  function _getPermit2RepaySignatureForSpender(
    ISignatureTransfer.PermitTransferFrom memory permit,
    ISignatureGateway.RepayAction memory action,
    uint256 privateKey,
    address spender
  ) internal view returns (bytes memory) {
    EIP712Types.PermitWitnessTransferFromRepayAction memory permitWitness = EIP712Types
      .PermitWitnessTransferFromRepayAction({
        permitted: EIP712Types.TokenPermissions({
          token: permit.permitted.token,
          amount: permit.permitted.amount
        }),
        spender: spender,
        nonce: permit.nonce,
        deadline: permit.deadline,
        witness: EIP712Types.RepayAction({
          onBehalfOf: action.onBehalfOf,
          nonce: action.nonce,
          deadline: action.deadline,
          params: EIP712Types.RepayParams({
            spoke: action.params.spoke,
            reserveId: action.params.reserveId,
            amount: action.params.amount
          })
        })
      });

    bytes32 structHash = vm.eip712HashStruct(
      'PermitWitnessTransferFromRepayAction',
      abi.encode(permitWitness)
    );

    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', PERMIT2_DOMAIN_SEPARATOR, structHash));

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
    return abi.encodePacked(r, s, v);
  }

  function _getSupplyWitnessHash(
    ISignatureGateway.SupplyAction memory action
  ) internal pure returns (bytes32) {
    return vm.eip712HashStruct('SupplyAction', abi.encode(action));
  }

  function _getRepayWitnessHash(
    ISignatureGateway.RepayAction memory action
  ) internal pure returns (bytes32) {
    return vm.eip712HashStruct('RepayAction', abi.encode(action));
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
