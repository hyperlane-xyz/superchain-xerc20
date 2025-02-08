// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../DeployFixture.sol";

import {XERC20Lockbox} from "src/xerc20/XERC20Lockbox.sol";
import {XERC20Factory} from "src/xerc20/XERC20Factory.sol";
import {XERC20} from "src/xerc20/XERC20.sol";

abstract contract XERC20RootDeployFixture is DeployFixture {
    using CreateXLibrary for bytes11;

    struct RootDeploymentParameters {
        address rootToken;
        address tokenAdmin;
        string outputFilename;
    }

    RootDeploymentParameters internal _params;

    // root superchain contracts
    XERC20Factory public rootXFactory;
    XERC20 public rootXERC20;

    // root-only contracts
    XERC20Lockbox public rootLockbox;

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
                        _params.tokenAdmin, // xerc20 owner address
                        _params.rootToken // erc20 address
                    )
                )
            })
        );
        checkAddress({_entropy: XERC20_FACTORY_ENTROPY, _output: address(rootXFactory)});

        (address _xERC20, address _lockbox) = rootXFactory.deployXERC20WithLockbox();
        rootXERC20 = XERC20(_xERC20);
        rootLockbox = XERC20Lockbox(_lockbox);
    }

    function params() external view returns (RootDeploymentParameters memory) {
        return _params;
    }

    /// @dev Used by tests to set the deployment parameters
    function setParams(RootDeploymentParameters memory _params_) external {
        _params = _params_;
    }

    function logParams() internal view override {
        console.log("rootXFactory: ", address(rootXFactory));
        console.log("rootXERC20: ", address(rootXERC20));
        console.log("rootLockbox: ", address(rootLockbox));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        vm.writeJson(vm.serializeAddress("", "rootXFactory", address(rootXFactory)), path);
        vm.writeJson(vm.serializeAddress("", "rootXERC20", address(rootXERC20)), path);
        vm.writeJson(vm.serializeAddress("", "rootLockbox", address(rootLockbox)), path);
    }
}
