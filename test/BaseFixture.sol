// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {VmSafe} from "forge-std/src/Vm.sol";
import "forge-std/src/Test.sol";
import "forge-std/src/console.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin5/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin5/contracts/utils/math/SafeCast.sol";
import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin5/contracts/utils/math/Math.sol";
import {Clones} from "@openzeppelin5/contracts/proxy/Clones.sol";

import {ICrosschainERC20, ISuperchainERC20, IXERC20, XERC20} from "src/xerc20/XERC20.sol";
import {IXERC20Lockbox, XERC20Lockbox} from "src/xerc20/XERC20Lockbox.sol";
import {IXERC20Factory, XERC20Factory} from "src/xerc20/XERC20Factory.sol";
import {RateLimitMidPoint} from "src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol";
import {CreateXLibrary} from "src/libraries/CreateXLibrary.sol";
import {MintLimits} from "src/xerc20/MintLimits.sol";

import {Users} from "test/utils/Users.sol";
import {TestConstants} from "test/utils/TestConstants.sol";
import {MockWETH} from "test/mocks/MockWETH.sol";
import {TestERC20} from "test/mocks/TestERC20.sol";
import {CreateX} from "test/mocks/CreateX.sol";

abstract contract BaseFixture is Test, TestConstants, GasSnapshot {
    using SafeERC20 for TestERC20;

    /// superchain contracts
    XERC20 public xVelo;
    XERC20Lockbox public lockbox;
    XERC20Factory public xFactory;
    address public bridge = address(1); // placeholder

    /// tokens
    TestERC20 public rewardToken;
    TestERC20 public token0;
    TestERC20 public token1;
    MockWETH public weth;

    /// mocks
    CreateX public cx = CreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    // used by xerc20 factory tests
    uint256 internal snapshot;

    Users internal users;

    function setUp() public virtual {
        // tests run as if chain id is 10 (optimism)
        vm.chainId(10);

        createUsers();

        // run deployments as address(this)
        // at end of deployment, address(this) should have no ownership
        rewardToken = new TestERC20("Reward Token", "RWRD", 18);

        TestERC20 tokenA = new TestERC20("Test Token A", "TTA", 18);
        TestERC20 tokenB = new TestERC20("Test Token B", "TTB", 6); // mimic USDC
        weth = new MockWETH();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        deployCreateX();

        console.logAddress(users.owner);

        address deployer = users.deployer;
        xFactory = XERC20Factory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: XERC20_FACTORY_ENTROPY, _deployer: deployer}),
                initCode: abi.encodePacked(
                    type(XERC20Factory).creationCode,
                    abi.encode(
                        users.owner, // xerc20 owner address
                        address(rewardToken) // erc20 address
                    )
                )
            })
        );
        snapshot = vm.snapshotState();
        (address _xVelo, address _lockbox) = xFactory.deployXERC20WithLockbox();
        xVelo = XERC20(_xVelo);
        lockbox = XERC20Lockbox(_lockbox);

        labelContracts();
    }

    function labelContracts() public virtual {
        vm.label(address(cx), "CreateX");
        vm.label(address(xVelo), "Superchain Velodrome");
        vm.label(address(lockbox), "Superchain Velodrome Lockbox");
        vm.label(address(xFactory), "Superchain Velodrome Token Factory");
    }

    function deployCreateX() internal {
        // identical to CreateX, with versions changed
        deployCodeTo("test/mocks/CreateX.sol", address(cx));
    }

    function createUsers() internal {
        users = Users({
            owner: createUser("Owner"),
            feeManager: createUser("FeeManager"),
            alice: createUser("Alice"),
            bob: createUser("Bob"),
            charlie: createUser("Charlie"),
            deployer: createUser("Deployer"),
            deployer2: createUser("Deployer2")
        });
    }

    function createUser(string memory name) internal returns (address payable user) {
        user = payable(makeAddr({name: name}));
        vm.deal({account: user, newBalance: TOKEN_1 * 1_000});
    }

    modifier prank(address _caller) {
        vm.startPrank(_caller);
        _;
        vm.stopPrank();
    }
}
