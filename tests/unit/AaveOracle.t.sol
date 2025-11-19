// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract AaveOracleTest is Base {
  using SafeCast for uint256;

  AaveOracle public oracle;

  uint8 private constant _oracleDecimals = 8;
  string private constant _description = 'Spoke 1 (USD)';

  address private _source1 = makeAddr('SOURCE1');
  address private _source2 = makeAddr('SOURCE2');

  address private user = makeAddr('USER');

  uint256 private constant reserveId1 = 0;
  uint256 private constant reserveId2 = 1;

  function setUp() public override {
    deployFixtures();
    oracle = new AaveOracle(address(spoke1), _oracleDecimals, _description);
  }

  function test_deploy_revertsWith_InvalidAddress() public {
    vm.expectRevert(IAaveOracle.InvalidAddress.selector);
    new AaveOracle(address(0), uint8(vm.randomUint()), string(vm.randomBytes(64)));
  }

  function test_constructor() public {
    oracle = new AaveOracle(address(spoke1), _oracleDecimals, _description);

    test_spoke();
    testDECIMALS();
    test_description();
  }

  function test_fuzz_constructor(uint8 decimals) public {
    decimals = bound(decimals, 0, 18).toUint8();
    oracle = new AaveOracle(address(spoke1), decimals, _description);

    test_spoke();
    assertEq(oracle.DECIMALS(), decimals);
    test_description();
  }

  function test_spoke() public view {
    assertEq(oracle.SPOKE(), address(spoke1));
  }

  function testDECIMALS() public view {
    assertEq(oracle.DECIMALS(), _oracleDecimals);
  }

  function test_description() public view {
    assertEq(oracle.DESCRIPTION(), _description);
  }

  function test_setReserveSource_revertsWith_OnlySpoke() public {
    vm.expectRevert(IPriceOracle.OnlySpoke.selector);

    vm.prank(user);
    oracle.setReserveSource(reserveId1, address(0));
  }

  function test_setReserveSource_revertsWith_InvalidSourceDecimals() public {
    _mockSourceDecimals(_source1, _oracleDecimals + 1);

    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidSourceDecimals.selector, reserveId1));

    vm.prank(address(spoke1));
    oracle.setReserveSource(reserveId1, _source1);
  }

  function test_setReserveSource_revertsWith_InvalidSource() public {
    _mockSourceDecimals(address(0), _oracleDecimals);

    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidSource.selector, reserveId1));

    vm.prank(address(spoke1));
    oracle.setReserveSource(reserveId1, address(0));
  }

  function test_setReserveSource_revertsWith_InvalidPrice() public {
    _mockSourceDecimals(_source1, _oracleDecimals);
    _mockSourceLatestRoundData(_source1, -1e8);
    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidPrice.selector, reserveId1));
    vm.prank(address(spoke1));
    oracle.setReserveSource(reserveId1, _source1);

    _mockSourceLatestRoundData(_source1, 0);
    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidPrice.selector, reserveId1));
    vm.prank(address(spoke1));
    oracle.setReserveSource(reserveId1, _source1);

    _mockSourceLatestRoundData(_source1, -100e18);
    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidPrice.selector, reserveId1));
    vm.prank(address(spoke1));
    oracle.setReserveSource(reserveId1, _source1);
  }

  function test_setReserveSource() public {
    _mockSourceDecimals(_source1, _oracleDecimals);
    _mockSourceLatestRoundData(_source1, 1e8);

    vm.expectEmit();
    emit IAaveOracle.UpdateReserveSource(reserveId1, _source1);
    vm.expectCall(_source1, abi.encodeCall(AggregatorV3Interface.latestRoundData, ()));

    vm.prank(address(spoke1));
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
    _mockSourceDecimals(_source1, _oracleDecimals);
    _mockSourceLatestRoundData(_source1, 1e8);

    vm.prank(address(spoke1));
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
    _mockSourceDecimals(_source1, _oracleDecimals);
    _mockSourceLatestRoundData(_source1, 1e8);

    vm.prank(address(spoke1));
    oracle.setReserveSource(reserveId1, _source1);

    uint256[] memory reserveIds = new uint256[](2); // todo: use reserveIds
    reserveIds[0] = reserveId1;
    reserveIds[1] = reserveId2;

    vm.expectRevert(abi.encodeWithSelector(IAaveOracle.InvalidSource.selector, reserveId2));
    oracle.getReservesPrices(reserveIds);
  }

  function test_getReservePrices() public {
    _mockSourceDecimals(_source1, _oracleDecimals);
    _mockSourceLatestRoundData(_source1, 1e8);
    _mockSourceDecimals(_source2, _oracleDecimals);
    _mockSourceLatestRoundData(_source2, 2e8);

    vm.prank(address(spoke1));
    oracle.setReserveSource(reserveId1, _source1);
    vm.prank(address(spoke1));
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
        uint80(vm.getBlockTimestamp()),
        price,
        vm.getBlockTimestamp(),
        vm.getBlockTimestamp(),
        uint80(vm.getBlockTimestamp())
      )
    );
  }
}
