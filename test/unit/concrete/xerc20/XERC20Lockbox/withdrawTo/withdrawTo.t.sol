// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20Lockbox.t.sol";
import {IERC20Errors} from "@openzeppelin5/contracts/interfaces/draft-IERC6093.sol";

contract WithdrawToUnitConcreteTest is XERC20LockboxTest {
    function test_GivenAnyAmount() external {
        // It should burn the amount of XERC20 tokens from the caller
        // It should transfer the amount of ERC20 tokens from the lockbox to the user
        // It should emit a {Withdraw} event
        uint256 amount = TOKEN_1 * 100_000;
        deal(address(rewardToken), users.alice, amount);

        vm.startPrank(users.alice);
        rewardToken.approve(address(lockbox), amount);

        lockbox.deposit(amount);

        xVelo.approve(address(lockbox), amount);

        vm.expectEmit(address(lockbox));
        emit IXERC20Lockbox.Withdraw({_sender: users.alice, _amount: amount});
        lockbox.withdrawTo(users.alice, amount);

        assertEq(rewardToken.balanceOf(users.alice), amount);
        assertEq(rewardToken.balanceOf(address(lockbox)), 0);
        assertEq(xVelo.balanceOf(users.alice), 0);
    }

    function test_GivenUserIsZeroAddress() external {
        // It should revert with the error {ERC20InvalidReceiver}
        uint256 amount = TOKEN_1 * 100_000;
        deal(address(rewardToken), users.alice, amount);

        vm.startPrank(users.alice);
        rewardToken.approve(address(lockbox), amount);

        lockbox.deposit(amount);

        xVelo.approve(address(lockbox), amount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InvalidReceiver.selector,
                address(0)
            )
        );
        lockbox.withdrawTo(address(0), amount);
    }

    function testGas() external {
        uint256 amount = TOKEN_1 * 100_000;
        deal(address(rewardToken), users.alice, amount);

        vm.startPrank(users.alice);
        rewardToken.approve(address(lockbox), amount);

        lockbox.deposit(amount);

        xVelo.approve(address(lockbox), amount);
        lockbox.withdrawTo(users.alice, amount);
        snapLastCall("XERC20Lockbox_withdrawTo");
    }
}
