// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {XERC20DeployFixture} from "../../xerc20/XERC20DeployFixture.s.sol";

contract DeployBase is XERC20DeployFixture {
    function setUp() public override {
        _params = XERC20DeployFixture.DeploymentParameters({
            tokenAdmin: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            outputFilename: "fraxtal.json"
        });
    }
}
