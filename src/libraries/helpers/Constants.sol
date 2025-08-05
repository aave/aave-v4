// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Constants {
  uint8 public constant MAX_ALLOWED_ASSET_DECIMALS = 18;
  uint56 internal constant MAX_CAP = type(uint56).max;
}
