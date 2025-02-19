// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {XERC20Lockbox} from "./XERC20Lockbox.sol";
import {AccessControl} from "@openzeppelin5/contracts/access/AccessControl.sol";

contract ManagedXERC20Lockbox is XERC20Lockbox, AccessControl {
    bytes32 public constant MANAGER = keccak256("MANAGER");

    event DepositsEnabled();
    event DepositsDisabled();

    bool public depositsEnabled = true;

    constructor(address _xerc20, address _erc20, address _admin) XERC20Lockbox(_xerc20, _erc20) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    modifier onlyWhenDepositsEnabled() {
        require(depositsEnabled, "Deposits are disabled");
        _;
    }

    function enableDeposits() external onlyRole(DEFAULT_ADMIN_ROLE) {
        depositsEnabled = true;
        emit DepositsEnabled();
    }

    function disableDeposits() external onlyRole(DEFAULT_ADMIN_ROLE) {
        depositsEnabled = false;
        emit DepositsDisabled();
    }

    function deposit(uint256 _amount) public override onlyWhenDepositsEnabled {
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
