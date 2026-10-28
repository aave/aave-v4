// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Create2TestHelper} from 'tests/utils/Create2TestHelper.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {SpokeDeployUtils} from 'scripts/utils/SpokeDeployUtils.sol';

contract SpokeDeployUtilsTest is Create2TestHelper {
  address internal constant CANONICAL_LIQUIDATION_LOGIC =
    0x88dF535473C5adf1f57789734A05E555F7Deb8DB;

  function setUp() public {
    _etchCreate2Factory();
  }

  function test_deployLiquidationLogic_canonicalAddress() public {
    assertEq(
      SpokeDeployUtils.deployLiquidationLogic(SpokeDeployUtils.LIQUIDATION_LOGIC_SALT),
      CANONICAL_LIQUIDATION_LOGIC
    );
  }

  function test_deployLiquidationLogic_reusesExisting() public {
    address first = SpokeDeployUtils.deployLiquidationLogic(
      SpokeDeployUtils.LIQUIDATION_LOGIC_SALT
    );
    address second = SpokeDeployUtils.deployLiquidationLogic(
      SpokeDeployUtils.LIQUIDATION_LOGIC_SALT
    );
    assertEq(second, first);
  }

  function test_deployBabylonLiquidationLogic_linksGivenLiquidationLogic() public {
    address liquidationLogic = SpokeDeployUtils.deployLiquidationLogic(
      SpokeDeployUtils.LIQUIDATION_LOGIC_SALT
    );
    address babylonLiquidationLogic = SpokeDeployUtils.deployBabylonLiquidationLogic(
      SpokeDeployUtils.LIQUIDATION_LOGIC_SALT,
      liquidationLogic
    );

    bytes memory code = SpokeDeployUtils.getLinkedBabylonLiquidationLogicCode(liquidationLogic);
    assertEq(
      babylonLiquidationLogic,
      Create2Utils.computeCreate2Address({
        salt: SpokeDeployUtils.LIQUIDATION_LOGIC_SALT,
        bytecode: code
      })
    );
    assertGt(babylonLiquidationLogic.code.length, 0);
    (bool success, bytes memory linked) = babylonLiquidationLogic.staticcall(
      abi.encodeWithSignature('getLiquidationLogic()')
    );
    assertTrue(success);
    assertEq(abi.decode(linked, (address)), liquidationLogic);

    uint256[] memory starts = _liquidationLogicLinkStarts();
    assertGt(starts.length, 0);
    for (uint256 i; i < starts.length; ++i) {
      assertEq(_addressAt(code, starts[i]), liquidationLogic);
    }
  }

  function test_deployBabylonLiquidationLogic_reusesExisting() public {
    address liquidationLogic = SpokeDeployUtils.deployLiquidationLogic(
      SpokeDeployUtils.LIQUIDATION_LOGIC_SALT
    );
    address first = SpokeDeployUtils.deployBabylonLiquidationLogic(
      SpokeDeployUtils.LIQUIDATION_LOGIC_SALT,
      liquidationLogic
    );
    address second = SpokeDeployUtils.deployBabylonLiquidationLogic(
      SpokeDeployUtils.LIQUIDATION_LOGIC_SALT,
      liquidationLogic
    );
    assertEq(second, first);
  }

  function test_deployBabylonLiquidationLogic_addressDependsOnLinkedLiquidationLogic() public {
    address canonical = SpokeDeployUtils.deployLiquidationLogic(
      SpokeDeployUtils.LIQUIDATION_LOGIC_SALT
    );
    address other = SpokeDeployUtils.deployLiquidationLogic(bytes32(0));
    assertNotEq(
      SpokeDeployUtils.deployBabylonLiquidationLogic(
        SpokeDeployUtils.LIQUIDATION_LOGIC_SALT,
        canonical
      ),
      SpokeDeployUtils.deployBabylonLiquidationLogic(SpokeDeployUtils.LIQUIDATION_LOGIC_SALT, other)
    );
  }

  function test_getLinkedBabylonLiquidationLogicCode_revertsWith_liquidationLogicNotDeployed()
    public
  {
    vm.expectRevert('liquidation logic not deployed');
    this.getLinkedBabylonLiquidationLogicCode(makeAddr('noCode'));
  }

  function getLinkedBabylonLiquidationLogicCode(
    address liquidationLogic
  ) external view returns (bytes memory) {
    return SpokeDeployUtils.getLinkedBabylonLiquidationLogicCode(liquidationLogic);
  }

  function _liquidationLogicLinkStarts() internal view returns (uint256[] memory starts) {
    string memory json = vm.readFile(SpokeDeployUtils.BABYLON_LIQUIDATION_LOGIC_ARTIFACT);
    string
      memory base = '.bytecode.linkReferences["src/spoke/libraries/LiquidationLogic.sol"].LiquidationLogic';
    uint256 count;
    while (vm.keyExistsJson(json, string.concat(base, '[', vm.toString(count), ']'))) ++count;
    starts = new uint256[](count);
    for (uint256 i; i < count; ++i) {
      starts[i] = vm.parseJsonUint(json, string.concat(base, '[', vm.toString(i), '].start'));
    }
  }

  function _addressAt(bytes memory code, uint256 start) internal pure returns (address a) {
    assembly {
      a := shr(96, mload(add(add(code, 0x20), start)))
    }
  }
}
