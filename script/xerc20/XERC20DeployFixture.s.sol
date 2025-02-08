// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../DeployFixture.sol";

import {XERC20Factory} from "src/xerc20/XERC20Factory.sol";
import {XERC20} from "src/xerc20/XERC20.sol";

abstract contract XERC20DeployFixture is DeployFixture {
    using CreateXLibrary for bytes11;

    struct DeploymentParameters {
        address tokenAdmin;
        string outputFilename;
    }

    DeploymentParameters internal _params;

    // leaf superchain contracts
    XERC20Factory public leafXFactory;
    XERC20 public leafXERC20;

    /// @dev Used by tests to disable logging of output
    bool public isTest;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        leafXFactory = XERC20Factory(
            cx.deployCreate3({
                salt: XERC20_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(XERC20Factory).creationCode,
                    abi.encode(
                        _params.tokenAdmin, // xerc20 owner
                        address(0) // erc20 address
                    )
                )
            })
        );
        checkAddress({_entropy: XERC20_FACTORY_ENTROPY, _output: address(leafXFactory)});

        leafXERC20 = XERC20(leafXFactory.deployXERC20());
    }

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }

    /// @dev Used by tests to set the deployment parameters
    function setParams(DeploymentParameters memory _params_) external {
        _params = _params_;
    }

    function logParams() internal view override {
        console.log("leafXFactory: ", address(leafXFactory));
        console.log("leafXERC20: ", address(leafXERC20));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        /// @dev This might overwrite an existing output file
        vm.writeJson(vm.serializeAddress("", "leafXFactory", address(leafXFactory)), path);
        vm.writeJson(vm.serializeAddress("", "leafXERC20", address(leafXERC20)), path);
    }
}
