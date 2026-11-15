// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";

/// G0 fork check (design file 20, day-1 part).
/// Answers, against the real GOOGLc B20 precompile on a Base mainnet fork:
///   - is GOOGLc a precompile, and what are its decimals;
///   - which transfer policy applies, and is it a blocklist;
///   - can a brand-new contract, the Uniswap v4 PoolManager and the Universal Router hold it;
///   - does a deposit -> withdraw round trip through a contract move exact amounts;
///   - is anything paused.
/// Needs Foundry >= 1.8.4 (B20 precompiles). Run:
///   BASE_RPC_URL=https://mainnet.base.org forge test --match-path test/fork/GOOGLcFork.t.sol -vv

interface IB20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function multiplier() external view returns (uint256);
    function pausedFeatures() external view returns (uint8[] memory);
    function TRANSFER_SENDER_POLICY() external view returns (bytes32);
    function TRANSFER_RECEIVER_POLICY() external view returns (bytes32);
    function TRANSFER_EXECUTOR_POLICY() external view returns (bytes32);
    function policyId(bytes32 scope) external view returns (uint64);
}

interface IPolicyRegistry {
    function isAuthorized(uint64 policyId, address account) external view returns (bool);
    function policyExists(uint64 policyId) external view returns (bool);
}

/// Stand-in for SegmentVault: pulls GOOGLc with transferFrom and pays it out with transfer,
/// which is exactly how split/merge/redeem will move collateral.
contract MiniVault {
    IB20 public immutable token;
    mapping(address => uint256) public deposited;

    constructor(IB20 token_) {
        token = token_;
    }

    function deposit(uint256 amount) external {
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        deposited[msg.sender] += amount;
    }

    function withdraw(uint256 amount, address to) external {
        deposited[msg.sender] -= amount;
        require(token.transfer(to, amount), "transfer failed");
    }
}

contract GOOGLcForkTest is Test {
    IB20 constant GOOGLC = IB20(0xb2000000000000000000002D0BA3164cc74f58B7);
    IPolicyRegistry constant REGISTRY = IPolicyRegistry(0x8453000000000000000000000000000000000002);
    address constant POOL_MANAGER = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
    address constant UNIVERSAL_ROUTER = 0x6fF5693b99212Da76ad316178A184AB56D299b43;
    /// Holds ~3,877 GOOGLc at the pinned block (found from Transfer logs).
    address constant HOLDER = 0x16c70F04C3080a127486Cdf5a4C33c066bBF47C3;
    uint256 constant FORK_BLOCK = 57_298_792;
    uint256 constant ONE = 1e8; // 8 decimals

    MiniVault vault;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")), FORK_BLOCK);
        vault = new MiniVault(GOOGLC);
    }

    function test_isPrecompileWith8Decimals() public view {
        bytes memory code = address(GOOGLC).code;
        console2.log("code length", code.length);
        console2.logBytes(code);
        assertEq(GOOGLC.decimals(), 8, "decimals");
        assertEq(GOOGLC.symbol(), "GOOGLc");
        console2.log("totalSupply", GOOGLC.totalSupply());
        console2.log("multiplier (WAD)", GOOGLC.multiplier());
    }

    function test_nothingPaused() public view {
        assertEq(GOOGLC.pausedFeatures().length, 0, "something is paused");
    }

    function test_transferPolicyIsBlocklistAndContractsAreAllowed() public {
        bytes32[3] memory scopes =
            [GOOGLC.TRANSFER_SENDER_POLICY(), GOOGLC.TRANSFER_RECEIVER_POLICY(), GOOGLC.TRANSFER_EXECUTOR_POLICY()];
        address[4] memory holders = [address(vault), POOL_MANAGER, UNIVERSAL_ROUTER, makeAddr("freshUser")];
        for (uint256 i; i < scopes.length; i++) {
            uint64 id = GOOGLC.policyId(scopes[i]);
            console2.log("scope", i, "policy id", id);
            assertTrue(REGISTRY.policyExists(id), "policy missing");
            // casting to 'uint8' is safe because id is uint64, so id >> 56 fits in 8 bits
            // forge-lint: disable-next-line(unsafe-typecast)
            assertEq(uint8(id >> 56), 0, "policy type is not BLOCKLIST");
            for (uint256 j; j < holders.length; j++) {
                assertTrue(REGISTRY.isAuthorized(id, holders[j]), "address not authorized");
            }
        }
    }

    function test_vaultRoundTripMovesExactAmounts() public {
        address user = makeAddr("user");
        uint256 amount = 10 * ONE;
        uint256 multiplierBefore = GOOGLC.multiplier();
        uint256 holderBefore = GOOGLC.balanceOf(HOLDER);
        assertGe(holderBefore, amount, "holder too small");

        // Holder approves the vault and deposits (vault is the executor of transferFrom).
        vm.startPrank(HOLDER);
        GOOGLC.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();

        assertEq(GOOGLC.balanceOf(address(vault)), amount, "vault balance after deposit");
        assertEq(GOOGLC.balanceOf(HOLDER), holderBefore - amount, "holder balance after deposit");

        // Holder withdraws to a fresh address (vault is the sender of transfer).
        vm.prank(HOLDER);
        vault.withdraw(amount, user);

        assertEq(GOOGLC.balanceOf(address(vault)), 0, "vault not empty");
        assertEq(GOOGLC.balanceOf(user), amount, "user balance after withdraw");
        assertEq(GOOGLC.multiplier(), multiplierBefore, "multiplier changed");
    }

    function test_canSendToPoolManagerAndRouter() public {
        vm.startPrank(HOLDER);
        assertTrue(GOOGLC.transfer(POOL_MANAGER, ONE));
        assertTrue(GOOGLC.transfer(UNIVERSAL_ROUTER, ONE));
        vm.stopPrank();
    }
}
