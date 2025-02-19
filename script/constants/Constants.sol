// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

/// @notice Constants used by Create3 deployment scripts
abstract contract Constants {
    bytes11 public constant XERC20_FACTORY_ENTROPY = 0x0000000000000001111111;

    // used by factory
    bytes11 public constant XERC20_ENTROPY = 0x0000000000000000000000;
    bytes11 public constant LOCKBOX_ENTROPY = 0x0000000000000000000001;
}
