// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

import {IAccessControl} from "@openzeppelin5/contracts/access/IAccessControl.sol";

import {ManagedXERC20Lockbox} from "src/xerc20/ManagedXERC20Lockbox.sol";

contract ManagedXERC20LockboxTest is BaseFixture {
    using SafeCast for uint256;

    bytes32 MANAGER = keccak256("MANAGER");
    bytes32 DEFAULT_ADMIN_ROLE = 0x00;

    address public manager;
    address public admin;

    ManagedXERC20Lockbox public managedLockbox;

    function setUp() public override {
        super.setUp();

        manager = makeAddr("manager");
        admin = makeAddr("admin");

        managedLockbox = new ManagedXERC20Lockbox(address(xVelo), address(rewardToken), admin);

        vm.prank(admin);
        managedLockbox.grantRole(MANAGER, manager);

        uint112 bufferCap = (TOKEN_1 * 5_000).toUint112();
        uint128 rateLimitPerSecond = ((bufferCap / 2) / DAY).toUint128(); // replenish limits in 1 day

        vm.prank(users.owner);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bufferCap: bufferCap,
                bridge: address(managedLockbox),
                rateLimitPerSecond: rateLimitPerSecond
            })
        );
    }

    function test_initialState() public view {
        assertEq(address(managedLockbox.ERC20()), address(rewardToken));
        assertEq(address(managedLockbox.XERC20()), address(xVelo));
        assertEq(managedLockbox.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
        assertEq(managedLockbox.hasRole(MANAGER, manager), true);
    }

    function test_enableDeposits() public {
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        managedLockbox.enableDeposits();

        vm.expectEmit();
        emit ManagedXERC20Lockbox.DepositsEnabled();
        vm.prank(admin);
        managedLockbox.enableDeposits();
        assertEq(managedLockbox.depositsEnabled(), true);
    }

    function test_disableDeposits() public {
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        managedLockbox.disableDeposits();

        vm.expectEmit();
        emit ManagedXERC20Lockbox.DepositsDisabled();
        vm.prank(admin);
        managedLockbox.disableDeposits();
        assertEq(managedLockbox.depositsEnabled(), false);
    }

    function test_deposit() public {
        uint256 amount = TOKEN_1 * 1_000;
        deal(address(rewardToken), users.alice, amount);
        vm.prank(users.alice);
        rewardToken.approve(address(managedLockbox), amount);

        vm.prank(admin);
        managedLockbox.disableDeposits();

        vm.prank(users.alice);
        vm.expectRevert("Deposits are disabled");
        managedLockbox.deposit(amount);

        vm.prank(admin);
        managedLockbox.enableDeposits();

        vm.prank(users.alice);
        managedLockbox.deposit(amount);
    }

    function test_withdraw() public {
        uint256 amount = TOKEN_1 * 1_000;
        deal(address(xVelo), manager, amount);
        deal(address(rewardToken), address(managedLockbox), amount);

        vm.startPrank(manager);
        xVelo.approve(address(managedLockbox), amount);
        managedLockbox.withdraw(amount);
        vm.stopPrank();

        vm.prank(users.alice);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        managedLockbox.withdraw(amount);
    }

    function test_withdrawTo() public {
        uint256 amount = TOKEN_1 * 1_000;
        deal(address(xVelo), manager, amount);
        deal(address(rewardToken), address(managedLockbox), amount);

        vm.startPrank(manager);
        xVelo.approve(address(managedLockbox), amount);
        managedLockbox.withdrawTo(users.alice, amount);
        vm.stopPrank();

        vm.prank(users.alice);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        managedLockbox.withdrawTo(users.bob, amount);
    }
}
