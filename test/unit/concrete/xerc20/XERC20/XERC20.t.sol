// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

import "@openzeppelin5/contracts/proxy/transparent/ProxyAdmin.sol";

abstract contract XERC20Test is BaseFixture {
    function test_InitialState() public view {
        assertEq(xVelo.name(), "OpenUSDT");
        assertEq(xVelo.symbol(), "USDT");
        assertEq(xVelo.owner(), users.owner);
        assertEq(xVelo.lockbox(), address(lockbox));
        assertEq(xVelo.SUPERCHAIN_ERC20_BRIDGE(), SUPERCHAIN_ERC20_BRIDGE);

        assertEq(ProxyAdmin(_admin()).owner(), users.owner);
        assertNotEq(_implementation(), address(xVelo));
        assertNotEq(_implementation(), address(0));
    }
}
