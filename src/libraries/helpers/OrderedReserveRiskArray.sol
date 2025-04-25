// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

library OrderedReserveRiskArray {
  error ReserveNotFound(uint256 reserveId);

  function insert(
    DataTypes.ReserveRiskConfig[] storage array,
    DataTypes.ReserveRiskConfig memory value
  ) internal {
    _insert(array, value, _upper_bound(array, value));
  }

  function update(
    DataTypes.ReserveRiskConfig[] storage array,
    DataTypes.ReserveRiskConfig memory value
  ) internal {
    _remove(array, _find(array, value));
    _insert(array, value, _upper_bound(array, value));
  }

  function _upper_bound(
    DataTypes.ReserveRiskConfig[] storage array,
    DataTypes.ReserveRiskConfig memory value
  ) private view returns (uint256) {
    uint256 index = array.length;
    while (index > 0 && array[index - 1].liquidityPremium > value.liquidityPremium) {
      index -= 1;
    }
    return index;
  }

  function _find(
    DataTypes.ReserveRiskConfig[] storage array,
    DataTypes.ReserveRiskConfig memory value
  ) private view returns (uint256) {
    for (uint256 i = 0; i < array.length; i += 1) {
      if (array[i].reserveId == value.reserveId) {
        return i;
      }
    }

    revert ReserveNotFound(value.reserveId);
  }

  function _insert(
    DataTypes.ReserveRiskConfig[] storage array,
    DataTypes.ReserveRiskConfig memory value,
    uint256 index
  ) private {
    // insert value just to increase the length of the array
    array.push(value);

    for (uint256 i = array.length - 1; i > index; i -= 1) {
      array[i] = array[i - 1];
    }
    array[index] = value;
  }

  function _remove(DataTypes.ReserveRiskConfig[] storage array, uint256 index) private {
    uint256 length = array.length;
    for (uint256 i = index; i < length - 1; i += 1) {
      array[i] = array[i + 1];
    }

    array.pop();
  }
}
