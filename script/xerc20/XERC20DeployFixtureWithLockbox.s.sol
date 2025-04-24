// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "./XERC20RootDeployFixture.s.sol";

abstract contract XERC20DeployFixtureWithLockbox is XERC20RootDeployFixture {
    using CreateXLibrary for bytes11;

    /// @dev Override to deploy XERC20 and Lockbox separately
    function deploy() internal override {
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

        rootXERC20 = XERC20(rootXFactory.deployXERC20());

        // Deploy the XERC20 Lockbox manually
        rootLockbox = new XERC20Lockbox(address(rootXERC20), _params.rootToken);
    }
}
