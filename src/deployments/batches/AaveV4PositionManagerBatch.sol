// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4GiverPositionManagerDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4GiverPositionManagerDeployProcedure.sol';
import {AaveV4TakerPositionManagerDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4TakerPositionManagerDeployProcedure.sol';
import {AaveV4ConfigPositionManagerDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4ConfigPositionManagerDeployProcedure.sol';

contract AaveV4PositionManagerBatch is
  AaveV4GiverPositionManagerDeployProcedure,
  AaveV4TakerPositionManagerDeployProcedure,
  AaveV4ConfigPositionManagerDeployProcedure
{
  BatchReports.PositionManagerBatchReport internal _report;

  constructor(address owner_, bytes32 salt_) {
    _report = BatchReports.PositionManagerBatchReport({
      giverPositionManager: _deployGiverPositionManager({owner: owner_, salt: salt_}),
      takerPositionManager: _deployTakerPositionManager({owner: owner_, salt: salt_}),
      configPositionManager: _deployConfigPositionManager({owner: owner_, salt: salt_})
    });
  }

  function getReport() external view returns (BatchReports.PositionManagerBatchReport memory) {
    return _report;
  }
}
