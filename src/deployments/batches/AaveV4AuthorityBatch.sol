// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4AccessManagerEnumerableDeployProcedure} from 'src/deployments/procedures/deploy/AaveV4AccessManagerEnumerableDeployProcedure.sol';

contract AaveV4AuthorityBatch is AaveV4AccessManagerEnumerableDeployProcedure {
  BatchReports.AuthorityBatchReport internal _report;

  constructor(address admin_, bytes32 salt_) {
    address accessManager = _deployAccessManagerEnumerable(admin_, salt_);
    _report = BatchReports.AuthorityBatchReport({accessManager: accessManager});
  }

  function getReport() external view returns (BatchReports.AuthorityBatchReport memory) {
    return _report;
  }
}
