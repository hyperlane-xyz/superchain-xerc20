// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {XERC20DeployFixture} from "../../xerc20/XERC20DeployFixture.s.sol";

contract DeployBase is XERC20DeployFixture {
    function setUp() public override {
        _params = XERC20DeployFixture.DeploymentParameters({
            tokenAdmin: 0x3B39854f29D7Ec7110afe806312E1d9893F00C83,
            outputFilename: "soneium.json"
        });
    }
}
