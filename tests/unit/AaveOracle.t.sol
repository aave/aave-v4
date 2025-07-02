// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {AggregatorV3Interface} from 'src/dependencies/chainlink/AggregatorV3Interface.sol';
import 'tests/Base.t.sol';

contract AaveOracleTest is Base {
  AaveOracle public oracle;

  uint8 private constant _decimals = 8;
  string private constant _description = 'Spoke 1 (USD)';

  address private _source1 = makeAddr('SOURCE1');
  address private _source2 = makeAddr('SOURCE2');

  address private user = makeAddr('USER');

  uint256 private constant reserveId1 = 0;
  uint256 private constant reserveId2 = 1;

  function setUp() public override {
    super.setUp();

    oracle = new AaveOracle(address(accessManager), _decimals, _description);

    bytes4[] memory oracleSelectors = new bytes4[](1);
    oracleSelectors[0] = IAaveOracle.setReserveSource.selector;
    vm.prank(ADMIN);
    accessManager.setTargetFunctionRole(address(oracle), oracleSelectors, Roles.ORACLE_ADMIN_ROLE);
  }

  function test_constructor() public {
    vm.expectEmit();
    emit IAaveOracle.AaveOracleCreated(_decimals, _description);
    oracle = new AaveOracle(address(accessManager), _decimals, _description);

    test_decimals();
    test_description();
    test_authority();
  }

  function test_decimals() public {
    assertEq(oracle.DECIMALS(), _decimals);
  }

  function test_description() public {
    assertEq(oracle.DESCRIPTION(), _description);
  }

  function test_authority() public {
    assertEq(oracle.authority(), address(accessManager));
  }

  function test_setReserveSource_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, user)
    );

    vm.prank(user);
    oracle.setReserveSource(reserveId1, address(0));
  }

  function test_setReserveSource_revertsWith_InvalidSourceDecimals() public {
    _mockSourceDecimals(_source1, _decimals + 1);

    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidSourceDecimals.selector, reserveId1));

    vm.prank(ORACLE_ADMIN);
    oracle.setReserveSource(reserveId1, _source1);
  }

  function test_setReserveSource_revertsWith_InvalidSource() public {
    _mockSourceDecimals(address(0), _decimals);

    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidSource.selector, reserveId1));

    vm.prank(ORACLE_ADMIN);
    oracle.setReserveSource(reserveId1, address(0));
  }

  function test_setReserveSource_revertsWith_InvalidPrice() public {
    _mockSourceDecimals(_source1, _decimals);
    _mockSourceLatestRoundData(_source1, -1e8);
    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidPrice.selector, reserveId1));
    vm.prank(ORACLE_ADMIN);
    oracle.setReserveSource(reserveId1, _source1);

    _mockSourceLatestRoundData(_source1, 0);
    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidPrice.selector, reserveId1));
    vm.prank(ORACLE_ADMIN);
    oracle.setReserveSource(reserveId1, _source1);

    _mockSourceLatestRoundData(_source1, -100e18);
    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidPrice.selector, reserveId1));
    vm.prank(ORACLE_ADMIN);
    oracle.setReserveSource(reserveId1, _source1);
  }

  function test_setReserveSource() public {
    _mockSourceDecimals(_source1, _decimals);
    _mockSourceLatestRoundData(_source1, 1e8);

    vm.expectEmit();
    emit IAaveOracle.ReserveSourceUpdated(reserveId1, _source1);
    vm.expectCall(_source1, abi.encodeCall(AggregatorV3Interface.latestRoundData, ()));

    vm.prank(ORACLE_ADMIN);
    oracle.setReserveSource(reserveId1, _source1);
  }

  function test_getReserveSource() public {
    assertEq(oracle.getReserveSource(reserveId1), address(0));
    test_setReserveSource();
    assertEq(oracle.getReserveSource(reserveId1), _source1);
  }

  function test_getReservePrice_revertsWith_InvalidSource() public {
    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidSource.selector, reserveId1));
    oracle.getReservePrice(reserveId1);
  }

  function test_getReservePrice_revertsWith_InvalidPrice() public {
    _mockSourceDecimals(_source1, _decimals);
    _mockSourceLatestRoundData(_source1, 1e8);

    vm.prank(ORACLE_ADMIN);
    oracle.setReserveSource(reserveId1, _source1);

    _mockSourceLatestRoundData(_source1, -1e8);

    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidPrice.selector, reserveId1));
    oracle.getReservePrice(reserveId1);
  }

  function test_getReservePrice() public {
    test_setReserveSource();

    vm.expectCall(_source1, abi.encodeCall(AggregatorV3Interface.latestRoundData, ()));
    assertEq(oracle.getReservePrice(reserveId1), 1e8);
  }

  function test_getReservePrices_revertsWith_InvalidSource() public {
    _mockSourceDecimals(_source1, _decimals);
    _mockSourceLatestRoundData(_source1, 1e8);

    vm.prank(ORACLE_ADMIN);
    oracle.setReserveSource(reserveId1, _source1);

    uint256[] memory reserveIds = new uint256[](2);
    reserveIds[0] = reserveId1;
    reserveIds[1] = reserveId2;

    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidSource.selector, reserveId2));
    oracle.getReservesPrices(reserveIds);
  }

  function test_getReservePrices() public {
    _mockSourceDecimals(_source1, _decimals);
    _mockSourceLatestRoundData(_source1, 1e8);
    _mockSourceDecimals(_source2, _decimals);
    _mockSourceLatestRoundData(_source2, 2e8);

    vm.prank(ORACLE_ADMIN);
    oracle.setReserveSource(reserveId1, _source1);
    vm.prank(ORACLE_ADMIN);
    oracle.setReserveSource(reserveId2, _source2);

    uint256[] memory reserveIds = new uint256[](2);
    reserveIds[0] = reserveId1;
    reserveIds[1] = reserveId2;

    uint256[] memory prices = oracle.getReservesPrices(reserveIds);
    assertEq(prices[0], 1e8);
    assertEq(prices[1], 2e8);
  }

  function _mockSourceDecimals(address source, uint8 decimals) internal {
    vm.mockCall(source, abi.encodeCall(AggregatorV3Interface.decimals, ()), abi.encode(decimals));
  }

  function _mockSourceLatestRoundData(address source, int256 price) internal {
    vm.mockCall(
      source,
      abi.encodeCall(AggregatorV3Interface.latestRoundData, ()),
      abi.encode(
        uint80(block.timestamp),
        price,
        block.timestamp,
        block.timestamp,
        uint80(block.timestamp)
      )
    );
  }
}
