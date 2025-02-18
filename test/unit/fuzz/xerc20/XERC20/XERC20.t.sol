// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

abstract contract XERC20Test is BaseFixture {
    function test_decimals() external view {
        assertEq(xVelo.decimals(), 6);
    }
}
