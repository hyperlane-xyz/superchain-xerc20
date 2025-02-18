// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

import "@openzeppelin5/contracts/proxy/transparent/ProxyAdmin.sol";

abstract contract XERC20LockboxTest is BaseFixture {
    function testInitialState() public view {
        assertEq(address(lockbox.ERC20()), address(rewardToken));
        assertEq(address(lockbox.XERC20()), address(xVelo));

        assertEq(ProxyAdmin(_admin()).owner(), users.owner);
    }

    function test_upgrade(address lockbox) public {
        address newImpl = address(new XERC20(lockbox));

        assertNotEq(_implementation(), newImpl);

        vm.prank(users.owner);
        ProxyAdmin(_admin()).upgradeAndCall(ITransparentUpgradeableProxy(address(xVelo)), newImpl, "");

        assertEq(_implementation(), newImpl);
    }
}
