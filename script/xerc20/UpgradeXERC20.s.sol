// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {Script, console} from "forge-std/src/Script.sol";
import {ManagedXERC20Lockbox} from "src/xerc20/ManagedXERC20Lockbox.sol";
import {XERC20} from "src/xerc20/XERC20.sol";
import {ProxyAdmin} from "@openzeppelin5/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin5/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ERC1967Utils} from "@openzeppelin5/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {RateLimitMidPoint} from "src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol";

import {ICreateX} from "createX/ICreateX.sol";
import {CreateXLibrary} from "src/libraries/CreateXLibrary.sol";

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

interface Safe {
    function getThreshold() external view returns (uint256);
    function isOwner(address owner) external view returns (bool);
    function getOwners() external view returns (address[] memory);
}

interface WarpRoute {
    function transferRemote(
        uint32 _destination,
        bytes32 _recipient,
        uint256 _amountOrId
    ) external payable;
    function quoteGasPayment(
        uint32 _destinationDomain
    ) external view returns (uint256);
}

// This is copied from ERC20Upgradeable
contract ERC20NameSymbolSetter is ERC20Upgradeable, ERC20PermitUpgradeable {
    bytes32 private constant ERC20StorageLocation =
        0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;
        bytes32 private constant EIP712StorageLocation = 0xa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d100;
    event NameAndSymbolSet(string name, string symbol);

    function getERC20Storage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }

     function getEIP712Storage() private pure returns (EIP712Storage storage $) {
        assembly {
            $.slot := EIP712StorageLocation
        }
    }

    function setNameAndSymbol(
        string memory _newName,
        string memory _newSymbol
    ) external {
        ERC20Storage storage $ = getERC20Storage();
        $._name = _newName;
        $._symbol = _newSymbol;
        EIP712Storage storage $712 = getEIP712Storage();
        $712._name = _newName;
        emit NameAndSymbolSet(_newName, _newSymbol);
    }
}

contract UpgradeXERC20 is Script {
    address proxiedXERC20Address = vm.envAddress("XERC20");
    XERC20 proxiedXERC20 = XERC20(proxiedXERC20Address);

    address warpRouteAddress = vm.envAddress("WARP_ROUTE");

    // Return the current limit configuration
    function assertInvariants(
        string memory name,
        string memory symbol,
        address lockbox
    ) private returns (RateLimitMidPoint memory limits) {
        // make assertions
        require(
            keccak256(bytes(proxiedXERC20.name())) == keccak256(bytes(name)),
            "Name mismatch"
        );
        require(
            keccak256(bytes(proxiedXERC20.symbol())) ==
                keccak256(bytes(symbol)),
            "Symbol mismatch"
        );

        require(proxiedXERC20.lockbox() == lockbox, "Lockbox mismatch");

        // Test that the warp route can transfer
        vm.prank(lockbox);
        proxiedXERC20.mint(address(this), 1);
        vm.stopPrank();
        proxiedXERC20.approve(warpRouteAddress, 1);
        uint256 gasPayment = WarpRoute(warpRouteAddress).quoteGasPayment(42220);
        vm.deal(address(this), gasPayment);
        WarpRoute(warpRouteAddress).transferRemote{value: gasPayment}(
            42220,
            bytes32(uint256(uint160(address(this)))),
            1
        );

        return proxiedXERC20.rateLimits(warpRouteAddress);
    }

    function logOwnership(address owner) public view {
        console.log("Proxy admin owner: ", owner);
        require(owner.code.length > 0, "Proxy admin owner is not a safe");
        // get threshold
        uint256 threshold = Safe(owner).getThreshold();
        console.log("Safe threshold: ", threshold);
        // get owners
        address[] memory owners = Safe(owner).getOwners();
        // Log owners
        for (uint256 i = 0; i < owners.length; i++) {
            console.log("Owner: ", owners[i]);
        }
    }

    function run() public {
        // This script works roughly in two phases:
        // 1. Assert the current state of the XERC20 contract
        // 2. Deploy a temporary implementation of ERC20NameSymbolSetter which allows to set name and symbol
        // 3. Upgrade the proxy to the temporary implementation, call setNameAndSymbol, and then revert back to the old implementation (needs to be done by Safes, but simulated in here to assert the outcome of the proposed calldata)
        // 4. Assert the new state of the XERC20 contract

        // store previous owner
        address previousOwner = proxiedXERC20.owner();
        address lockbox = proxiedXERC20.lockbox();
        RateLimitMidPoint memory previousRateLimits = assertInvariants(
            "Super USDT",
            "USDT",
            lockbox
        );

        // assert that lockbox is 0x0 on non-celo chains
        if (block.chainid != 42220) {
            require(lockbox == address(0), "Lockbox is not 0x0");
        } else {
            require(lockbox != address(0), "Lockbox is 0x0");
        }

        // get old implementation
        address oldImplementation = address(
            uint160(
                uint256(
                    vm.load(
                        proxiedXERC20Address,
                        ERC1967Utils.IMPLEMENTATION_SLOT
                    )
                )
            )
        );
        console.log("Old implementation: ", oldImplementation);

        vm.startBroadcast();
        address temporaryImplementation = address(new ERC20NameSymbolSetter());
        console.log("New implementation: ", temporaryImplementation);
        vm.stopBroadcast();

        // Gather proxy admin info
        ProxyAdmin proxyAdmin = ProxyAdmin(
            address(
                uint160(
                    uint256(
                        vm.load(proxiedXERC20Address, ERC1967Utils.ADMIN_SLOT)
                    )
                )
            )
        );

        console.log("Proxy admin: ", address(proxyAdmin));
        address owner = proxyAdmin.owner();
        logOwnership(owner);

        // Do the upgrade
        vm.startPrank(owner);
        // Log the calldata for the upgrade
        // console.log("Run Upgrade: upgradeAndCall(address,address,bytes)");
        // console.log("proxiedXERC20Address: ", proxiedXERC20Address);
        // console.log("newImplementation: ", address(newImplementation));
        // console.log("Calldata:");
        // console.logBytes(
        //     abi.encodeWithSignature(
        //         "upgradeAndCall(address,address,bytes)",
        //         proxiedXERC20Address,
        //         address(newImplementation),
        //         ""
        //     )
        // );

        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(proxiedXERC20Address),
            address(temporaryImplementation),
            ""
        );
        ERC20NameSymbolSetter(proxiedXERC20Address).setNameAndSymbol(
            "OpenUSDT",
            "USDT"
        );
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(proxiedXERC20Address),
            oldImplementation,
            ""
        );
        vm.stopPrank();

        // Post-flight check upgraded contract
        RateLimitMidPoint memory newRateLimits = assertInvariants(
            "OpenUSDT",
            "USDT",
            lockbox
        );
        require(
            previousRateLimits.bufferCap == newRateLimits.bufferCap,
            "Buffer cap mismatch"
        );
        require(
            previousRateLimits.rateLimitPerSecond ==
                newRateLimits.rateLimitPerSecond,
            "Rate limit mismatch"
        );
        // compare owners
        require(previousOwner == proxiedXERC20.owner(), "Owner mismatch");
        // check that the old implementation is the current implementation
        require(
            oldImplementation ==
                address(
                    uint160(
                        uint256(
                            vm.load(
                                proxiedXERC20Address,
                                ERC1967Utils.IMPLEMENTATION_SLOT
                            )
                        )
                    )
                ),
            "Implementation mismatch"
        );
        console.log("Upgrade complete");
    }
}
