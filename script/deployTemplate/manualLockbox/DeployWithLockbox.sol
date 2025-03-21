// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {XERC20DeployFixtureWithLockbox} from "../../xerc20/XERC20DeployFixtureWithLockbox.s.sol";

contract DeployWithLockbox is XERC20DeployFixtureWithLockbox {
    function setUp() public override {
        _params = XERC20DeployFixtureWithLockbox.DeploymentParameters({
            tokenAdmin: 0xa7ECcdb9Be08178f896c26b7BbD8C3D4E844d9Ba,
            rootToken: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
            outputFilename: "ethereum.json"
        });
    }
}
