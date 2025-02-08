// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {XERC20RootDeployFixture} from "../../xerc20/XERC20RootDeployFixture.s.sol";

contract DeployRootBase is XERC20RootDeployFixture {
    function setUp() public override {
        _params = XERC20RootDeployFixture.RootDeploymentParameters({
            tokenAdmin: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            rootToken: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58,
            outputFilename: "optimism.json"
        });
    }
}
