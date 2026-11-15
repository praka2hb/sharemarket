// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/test/shared/HookMiner.sol";
import {SegmentVault} from "../src/SegmentVault.sol";
import {FilingResolver} from "../src/FilingResolver.sol";
import {CloseHook} from "../src/CloseHook.sol";
import {SegmentRouter} from "../src/SegmentRouter.sol";
import {MockPolicyRegistry} from "../src/mocks/MockPolicyRegistry.sol";
import {MockB20} from "../src/mocks/MockB20.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {Faucet, IMintable} from "../src/mocks/Faucet.sol";

/// @notice Deploys the whole testnet stack on Base Sepolia: mocks, faucet, vault, resolver,
///         CloseHook (address mined for its permission flags) and router.
///         Writes every address to DEPLOYMENTS_FILE (default ../deployments/base-sepolia.json).
/// @dev Testnet settings: admin and guardian are the deploying wallet, dispute window 15 minutes,
///      fallback delay 1 hour. ARBITER defaults to the deploying wallet.
///      Run with your own signer, e.g. `--account <keystore-name>`; this script never reads a key.
contract DeployTestnet is Script {
    /// Uniswap v4 PoolManager on Base Sepolia (checked in G0).
    address internal constant POOL_MANAGER_SEPOLIA = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    /// Deterministic CREATE2 deployer used by forge scripts.
    address internal constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    uint64 internal constant DISPUTE_WINDOW = 15 minutes;
    uint64 internal constant FALLBACK_DELAY = 1 hours;

    struct Deployed {
        address me;
        address arbiter;
        IPoolManager manager;
        MockPolicyRegistry registry;
        MockB20 googl;
        MockUSDC usdc;
        Faucet faucet;
        SegmentVault vault;
        FilingResolver resolver;
        CloseHook hook;
        SegmentRouter router;
    }

    function run() external {
        string memory out = vm.envOr("DEPLOYMENTS_FILE", string("../deployments/base-sepolia.json"));
        Deployed memory d;
        d.manager = IPoolManager(vm.envOr("POOL_MANAGER", POOL_MANAGER_SEPOLIA));
        require(address(d.manager).code.length > 0, "no PoolManager at that address on this chain");

        vm.startBroadcast();
        (, d.me,) = vm.readCallers();
        d.arbiter = vm.envOr("ARBITER", d.me);
        _deployMocks(d);
        _deployCore(d);
        vm.stopBroadcast();

        _write(d, out);
    }

    function _deployMocks(Deployed memory d) internal {
        d.registry = new MockPolicyRegistry(d.me);
        d.googl = new MockB20(d.me, d.registry, d.registry.BLOCKLIST_POLICY());
        d.usdc = new MockUSDC(d.me);
        d.faucet = new Faucet(IMintable(address(d.googl)), IMintable(address(d.usdc)));
        d.googl.setMinter(address(d.faucet), true);
        d.usdc.setMinter(address(d.faucet), true);
    }

    function _deployCore(Deployed memory d) internal {
        d.vault = new SegmentVault(IERC20(address(d.googl)), d.me, d.me);
        d.resolver =
            new FilingResolver(d.vault, IERC20(address(d.usdc)), d.me, d.arbiter, DISPUTE_WINDOW, FALLBACK_DELAY);
        d.vault.setResolver(address(d.resolver));

        uint160 flags = uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG);
        (address predicted, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER, flags, type(CloseHook).creationCode, abi.encode(d.manager, d.vault)
        );
        d.hook = new CloseHook{salt: salt}(d.manager, d.vault);
        require(address(d.hook) == predicted, "hook address mismatch");

        d.router = new SegmentRouter(d.manager, d.vault, d.hook);
    }

    function _write(Deployed memory d, string memory out) internal {
        string memory k = "deployment";
        vm.serializeUint(k, "chainId", block.chainid);
        vm.serializeAddress(k, "deployer", d.me);
        vm.serializeAddress(k, "arbiter", d.arbiter);
        vm.serializeAddress(k, "poolManager", address(d.manager));
        vm.serializeAddress(k, "policyRegistry", address(d.registry));
        vm.serializeAddress(k, "googl", address(d.googl));
        vm.serializeAddress(k, "usdc", address(d.usdc));
        vm.serializeAddress(k, "faucet", address(d.faucet));
        vm.serializeAddress(k, "vault", address(d.vault));
        vm.serializeAddress(k, "resolver", address(d.resolver));
        vm.serializeAddress(k, "hook", address(d.hook));
        string memory json = vm.serializeAddress(k, "router", address(d.router));
        vm.writeJson(json, out);

        console2.log("vault   ", address(d.vault));
        console2.log("resolver", address(d.resolver));
        console2.log("hook    ", address(d.hook));
        console2.log("router  ", address(d.router));
        console2.log("written to", out);
    }
}
