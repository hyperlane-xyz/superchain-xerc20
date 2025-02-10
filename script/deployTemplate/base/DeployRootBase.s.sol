// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {XERC20RootDeployFixture} from "../../xerc20/XERC20RootDeployFixture.s.sol";

contract DeployRootBase is XERC20RootDeployFixture {
    function setUp() public override {
        _params = XERC20RootDeployFixture.RootDeploymentParameters({
            tokenAdmin: 0xa7ECcdb9Be08178f896c26b7BbD8C3D4E844d9Ba,
            rootToken: 0xcebA9300f2b948710d2653dD7B07f33A8B32118C,
            outputFilename: "base.json"
        });
    }
}
