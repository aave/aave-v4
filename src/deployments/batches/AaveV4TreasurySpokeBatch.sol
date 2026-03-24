// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4TreasurySpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TreasurySpokeDeployProcedure.sol';

contract AaveV4TreasurySpokeBatch is AaveV4TreasurySpokeDeployProcedure {
  BatchReports.TreasurySpokeBatchReport internal _report;

  constructor(address owner_, bytes32 salt_) {
    address treasurySpoke = _deployTreasurySpoke({owner: owner_, salt: salt_});
    _report = BatchReports.TreasurySpokeBatchReport(treasurySpoke);
  }

  function getReport() external view returns (BatchReports.TreasurySpokeBatchReport memory) {
    return _report;
  }
}
