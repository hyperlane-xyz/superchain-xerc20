// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../DeployFixture.sol";

import {XERC20Factory} from "src/xerc20/XERC20Factory.sol";
import {XERC20} from "src/xerc20/XERC20.sol";
import {XERC20Lockbox} from "src/xerc20/XERC20Lockbox.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

abstract contract XERC20DeployFixtureWithLockbox is DeployFixture {
    using CreateXLibrary for bytes11;

    struct DeploymentParameters {
        address rootToken;
        address tokenAdmin;
        string outputFilename;
    }

    DeploymentParameters internal _params;

    // ethereum superchain contracts
    XERC20Factory public rootXFactory;
    XERC20 public rootXERC20;
    XERC20Lockbox public rootXERC20Lockbox;

    /// @dev Used by tests to disable logging of output
    bool public isTest;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        rootXFactory = XERC20Factory(
            cx.deployCreate3({
                salt: XERC20_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(XERC20Factory).creationCode,
                    abi.encode(
                        _params.tokenAdmin, // xerc20 owner
                        _params.rootToken // erc20 address
                    )
                )
            })
        );
        checkAddress({_entropy: XERC20_FACTORY_ENTROPY, _output: address(rootXFactory)});

        rootXERC20 = XERC20(rootXFactory.deployXERC20());

        // Finally for non-celo chains we need to deploy the XERC20 Lockbox manually
        rootXERC20Lockbox = new XERC20Lockbox(address(rootXERC20), _params.rootToken);
    }

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }

    /// @dev Used by tests to set the deployment parameters
    function setParams(DeploymentParameters memory _params_) external {
        _params = _params_;
    }

    function logParams() internal view override {
        console.log("XERC20Factory: ", address(rootXFactory));
        console.log("XERC20: ", address(rootXERC20));
        console.log("XERC20Lockbox: ", address(rootXERC20Lockbox));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory dirPath = string(abi.encodePacked(root, "/deployment-addresses"));
        string memory path = string(abi.encodePacked(dirPath, "/", _params.outputFilename));

        // Create directory if it doesn't exist
        if (!vm.exists(dirPath)) {
            vm.createDir(dirPath, true);
        }

        /// @dev This might overwrite an existing output file
        vm.writeJson(vm.serializeAddress("", "XERC20Factory", address(rootXFactory)), path);
        vm.writeJson(vm.serializeAddress("", "XERC20", address(rootXERC20)), path);
        vm.writeJson(vm.serializeAddress("", "XERC20Lockbox", address(rootXERC20Lockbox)), path);
    }
}
