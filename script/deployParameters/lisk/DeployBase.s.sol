// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {XERC20DeployFixture} from "../../xerc20/XERC20DeployFixture.s.sol";

contract DeployBase is XERC20DeployFixture {
    function setUp() public override {
        _params = XERC20DeployFixture.DeploymentParameters({
            tokenAdmin: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            outputFilename: "lisk.json"
        });
    }
}
