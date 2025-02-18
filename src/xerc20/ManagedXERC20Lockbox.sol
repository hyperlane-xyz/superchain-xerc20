// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {XERC20Lockbox} from "./XERC20Lockbox.sol";
import {AccessControl} from "@openzeppelin5/contracts/access/AccessControl.sol";

contract ManagedXERC20Lockbox is XERC20Lockbox, AccessControl {
    bytes32 public constant MANAGER = keccak256("MANAGER");

    bool public depositsEnabled = true;

    constructor(address _xerc20, address _erc20) XERC20Lockbox(_xerc20, _erc20) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier depositsAreEnabled() {
        require(depositsEnabled, "Deposits are disabled");
        _;
    }

    function enableDeposits() external onlyRole(MANAGER) {
        depositsEnabled = true;
    }

    function disableDeposits() external onlyRole(MANAGER) {
        depositsEnabled = false;
    }

    function deposit(uint256 _amount) public override depositsAreEnabled {
        XERC20Lockbox.deposit(_amount);
    }

    /// @inheritdoc XERC20Lockbox
    /// @dev Only the manager can withdraw
    function withdraw(uint256 _amount) public override onlyRole(MANAGER) {
        XERC20Lockbox.withdraw(_amount);
    }

    /// @inheritdoc XERC20Lockbox
    /// @dev Only the manager can withdraw to
    function withdrawTo(address _to, uint256 _amount) public override onlyRole(MANAGER) {
        XERC20Lockbox.withdrawTo(_to, _amount);
    }
}
