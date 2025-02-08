// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {XERC20RootDeployFixture} from "../../xerc20/XERC20RootDeployFixture.s.sol";

contract DeployRootBase is XERC20RootDeployFixture {
    function setUp() public override {
        _params = XERC20RootDeployFixture.RootDeploymentParameters({
            tokenAdmin: 0xa7ECcdb9Be08178f896c26b7BbD8C3D4E844d9Ba,
            rootToken: 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e,
            outputFilename: "base.json"
        });
    }
}
