// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {XERC20DeployFixture} from "../../xerc20/XERC20DeployFixture.s.sol";

contract DeployBase is XERC20DeployFixture {
    function setUp() public override {
        _params = XERC20DeployFixture.DeploymentParameters({
            tokenAdmin: 0x6fF6F4485375C4D194c3C6F3FC15D53409697FcA,
            outputFilename: "metal.json"
        });
    }
}
