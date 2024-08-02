// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {VmSafe} from "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin5/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin5/contracts/proxy/Clones.sol";

import {IPool, Pool} from "src/pools/Pool.sol";
import {IPoolFactory, PoolFactory} from "src/pools/PoolFactory.sol";
import {IRouter, Router} from "src/Router.sol";
import {IXERC20, XERC20} from "src/xerc20/XERC20.sol";
import {IXERC20Lockbox, XERC20Lockbox} from "src/xerc20/XERC20Lockbox.sol";
import {IXERC20Factory, XERC20Factory} from "src/xerc20/XERC20Factory.sol";
import {VelodromeTimeLibrary} from "src/libraries/VelodromeTimeLibrary.sol";
import {IGauge} from "src/interfaces/gauges/IGauge.sol";
import {CreateXLibrary} from "src/libraries/CreateXLibrary.sol";

import {Users} from "test/utils/Users.sol";
import {Constants} from "test/utils/Constants.sol";
import {MockWETH} from "test/mocks/MockWETH.sol";
import {TestERC20} from "test/mocks/TestERC20.sol";
import {CreateX} from "test/mocks/CreateX.sol";

abstract contract BaseFixture is Test, Constants {
    using SafeERC20 for TestERC20;

    Pool public poolImplementation;
    PoolFactory public poolFactory;
    Router public router;

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

        address deployer = users.deployer;
        xFactory = XERC20Factory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: XERC20_FACTORY_ENTROPY, _deployer: deployer}),
                initCode: abi.encodePacked(
                    type(XERC20Factory).creationCode,
                    abi.encode(
                        address(cx), // create x address
                        users.owner // xerc20 owner address
                    )
                )
            })
        );
        snapshot = vm.snapshot();
        (address _xVelo, address _lockbox) = xFactory.deployXERC20WithLockbox({_erc20: address(rewardToken)});
        xVelo = XERC20(_xVelo);
        lockbox = XERC20Lockbox(_lockbox);

        poolImplementation = Pool(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: POOL_ENTROPY, _deployer: deployer}),
                initCode: abi.encodePacked(type(Pool).creationCode)
            })
        );
        poolFactory = PoolFactory(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: POOL_FACTORY_ENTROPY, _deployer: deployer}),
                initCode: abi.encodePacked(
                    type(PoolFactory).creationCode,
                    abi.encode(
                        address(poolImplementation), // pool implementation
                        users.owner, // pool admin
                        users.owner, // pauser
                        users.feeManager // fee manager
                    )
                )
            })
        );

        router = Router(
            payable(
                cx.deployCreate3({
                    salt: CreateXLibrary.calculateSalt({_entropy: ROUTER_ENTROPY, _deployer: deployer}),
                    initCode: abi.encodePacked(
                        type(Router).creationCode,
                        abi.encode(
                            address(poolFactory), // pool factory
                            address(weth) // weth contract
                        )
                    )
                })
            )
        );

        deal(address(token0), users.alice, TOKEN_1 * 1e9);
        deal(address(token1), users.alice, TOKEN_1 * 1e9);
        deal(address(token0), users.bob, TOKEN_1 * 1e9);
        deal(address(token1), users.bob, TOKEN_1 * 1e9);

        labelContracts();

        skipToNextEpoch(0);
    }

    function labelContracts() public virtual {
        vm.label(address(poolImplementation), "Pool Implementation");
        vm.label(address(poolFactory), "Pool Factory");
        vm.label(address(router), "Router");
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
            deployer: createUser("Deployer")
        });
    }

    function createUser(string memory name) internal returns (address payable user) {
        user = payable(makeAddr({name: name}));
        vm.deal({account: user, newBalance: TOKEN_1 * 1_000});
    }

    /// @dev Helper utility to forward time to next week
    ///      note epoch requires at least one second to have
    ///      passed into the new epoch
    function skipToNextEpoch(uint256 offset) internal {
        uint256 nextEpoch = VelodromeTimeLibrary.epochNext(block.timestamp);
        uint256 newTimestamp = nextEpoch + offset;
        uint256 diff = newTimestamp - block.timestamp;
        vm.warp(newTimestamp);
        vm.roll(block.number + diff / 2);
    }

    function skipAndRoll(uint256 timeOffset) public {
        skip(timeOffset);
        vm.roll(block.number + timeOffset / 2);
    }

    /// @dev Helper function to add rewards to gauge
    function addRewardToGauge(address _gauge, uint256 _amount) internal prank(users.owner) {
        deal(address(rewardToken), users.owner, _amount);
        rewardToken.safeIncreaseAllowance(_gauge, _amount);
        IGauge(_gauge).notifyRewardAmount(_amount);
    }

    /// @dev Helper function to deposit liquidity into pool
    function addLiquidityToPool(
        address _owner,
        address _token0,
        address _token1,
        bool _stable,
        uint256 _amount0,
        uint256 _amount1
    ) internal prank(_owner) {
        bytes32 salt = keccak256(abi.encodePacked(_token0, _token1, _stable));
        address pool = Clones.predictDeterministicAddress({
            implementation: address(poolImplementation),
            salt: salt,
            deployer: address(poolFactory)
        });
        TestERC20(_token0).safeTransfer(pool, _amount0);
        TestERC20(_token1).safeTransfer(pool, _amount1);
        IPool(pool).mint(_owner);
    }

    modifier prank(address _caller) {
        vm.startPrank(_caller);
        _;
        vm.stopPrank();
    }
}
