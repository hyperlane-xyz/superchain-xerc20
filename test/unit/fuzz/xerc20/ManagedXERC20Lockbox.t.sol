// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseFixture.sol";

import {DepositUnitFuzzTest} from "./XERC20Lockbox/deposit/deposit.t.sol";
import {WithdrawUnitFuzzTest} from "./XERC20Lockbox/withdraw/withdraw.t.sol";
import {WithdrawToUnitFuzzTest} from "./XERC20Lockbox/withdrawTo/withdrawTo.t.sol";
import {ManagedXERC20Lockbox} from "src/xerc20/ManagedXERC20Lockbox.sol";

contract ManagedXERC20LockboxTest is
    DepositUnitFuzzTest,
    WithdrawUnitFuzzTest,
    WithdrawToUnitFuzzTest
{
    function setUp() public override {
        super.setUp();
        ManagedXERC20Lockbox lockbox = new ManagedXERC20Lockbox(
            address(xVelo),
            address(rewardToken)
        );
        bridge = address(lockbox);
    }
}
