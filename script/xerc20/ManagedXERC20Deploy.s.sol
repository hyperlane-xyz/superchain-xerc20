// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {Script} from "forge-std/src/Script.sol";
import {ManagedXERC20Lockbox} from "src/xerc20/ManagedXERC20Lockbox.sol";

contract ManagedXERC20Deploy is Script {
    address erc20 = vm.envAddress("ERC20");
    address xerc20 = vm.envAddress("XERC20");
    address manager = vm.envAddress("MANAGER");

    function run() public {
        address admin = msg.sender;
        vm.startBroadcast();
        ManagedXERC20Lockbox lockbox = new ManagedXERC20Lockbox(
            xerc20,
            erc20,
            admin
        );
        lockbox.grantRole(lockbox.MANAGER(), manager);
        vm.stopBroadcast();
    }
}
