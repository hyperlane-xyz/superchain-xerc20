// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {XERC20DeployFixture} from "../../xerc20/XERC20DeployFixture.s.sol";

contract DeployBase is XERC20DeployFixture {
    function setUp() public override {
        _params = XERC20DeployFixture.DeploymentParameters({
            tokenAdmin: 0xa7ECcdb9Be08178f896c26b7BbD8C3D4E844d9Ba,
            outputFilename: "worldchain.json"
        });
    }
}
