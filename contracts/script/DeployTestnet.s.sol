// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {SegmentVault} from "../src/SegmentVault.sol";
import {SegmentRouter} from "../src/SegmentRouter.sol";
import {PieceToken} from "../src/PieceToken.sol";
import {MockPolicyRegistry} from "../src/mocks/MockPolicyRegistry.sol";
import {MockB20} from "../src/mocks/MockB20.sol";
import {Faucet, IMintable} from "../src/mocks/Faucet.sol";

/// @notice Deploys the testnet stack on Base Sepolia:
///           - one blocklist registry and a faucet (20 GOOGLc + 20 NVDAc per address per day);
///           - GOOGL market: mock GOOGLc, vault with $SEARCH / $YOUTUBE / $CLOUD, router;
///           - NVDA market:  mock NVDAc, vault with $HYPERSCALE / $AICLOUD / $EDGE, router.
///         Writes every address to DEPLOYMENTS_FILE (default ../deployments/base-sepolia.json).
/// @dev No admin roles exist in the vaults or routers. The deploying wallet owns only the mock tokens.
///      Run with your own signer, e.g. `--account <keystore-name>`; this script never reads a key.
contract DeployTestnet is Script {
    /// Uniswap v4 PoolManager on Base Sepolia (checked in G0).
    address internal constant POOL_MANAGER_SEPOLIA = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;

    struct Market {
        MockB20 stock;
        SegmentVault vault;
        SegmentRouter router;
    }

    function run() external {
        string memory out = vm.envOr("DEPLOYMENTS_FILE", string("../deployments/base-sepolia.json"));
        IPoolManager manager = IPoolManager(vm.envOr("POOL_MANAGER", POOL_MANAGER_SEPOLIA));
        require(address(manager).code.length > 0, "no PoolManager at that address on this chain");

        vm.startBroadcast();
        (, address me,) = vm.readCallers();
        MockPolicyRegistry registry = new MockPolicyRegistry(me);

        Market memory g = _market(
            manager,
            new MockB20("Alphabet Inc. (mock)", "GOOGLc", me, registry, registry.BLOCKLIST_POLICY()),
            _googlSymbols(),
            _googlNames()
        );
        Market memory n = _market(
            manager,
            new MockB20("NVIDIA Corporation (mock)", "NVDAc", me, registry, registry.BLOCKLIST_POLICY()),
            _nvdaSymbols(),
            _nvdaNames()
        );

        IMintable[] memory toks = new IMintable[](2);
        toks[0] = IMintable(address(g.stock));
        toks[1] = IMintable(address(n.stock));
        uint256[] memory amts = new uint256[](2);
        amts[0] = 20e8;
        amts[1] = 20e8;
        Faucet faucet = new Faucet(toks, amts);
        g.stock.setMinter(address(faucet), true);
        n.stock.setMinter(address(faucet), true);
        vm.stopBroadcast();

        string memory root = "root";
        vm.serializeUint(root, "chainId", block.chainid);
        vm.serializeAddress(root, "deployer", me);
        vm.serializeAddress(root, "poolManager", address(manager));
        vm.serializeAddress(root, "policyRegistry", address(registry));
        vm.serializeAddress(root, "faucet", address(faucet));
        vm.serializeString(root, "GOOGL", _marketJson("GOOGL", g));
        string memory json = vm.serializeString(root, "NVDA", _marketJson("NVDA", n));
        vm.writeJson(json, out);
        console2.log("written to", out);
    }

    function _market(IPoolManager manager, MockB20 stock, string[] memory symbols, string[] memory names)
        internal
        returns (Market memory m)
    {
        m.stock = stock;
        m.vault = new SegmentVault(IERC20(address(stock)), symbols, names);
        m.router = new SegmentRouter(manager, m.vault);
    }

    function _marketJson(string memory key, Market memory m) internal returns (string memory) {
        PieceToken[] memory ps = m.vault.pieces();
        address[] memory addrs = new address[](ps.length);
        string[] memory syms = new string[](ps.length);
        for (uint256 i; i < ps.length; i++) {
            addrs[i] = address(ps[i]);
            syms[i] = ps[i].symbol();
            console2.log(key, syms[i], addrs[i]);
        }
        vm.serializeAddress(key, "stock", address(m.stock));
        vm.serializeAddress(key, "vault", address(m.vault));
        vm.serializeAddress(key, "router", address(m.router));
        vm.serializeString(key, "symbols", syms);
        return vm.serializeAddress(key, "pieces", addrs);
    }

    function _googlSymbols() internal pure returns (string[] memory s) {
        s = new string[](3);
        s[0] = "SEARCH-GOOGL";
        s[1] = "YOUTUBE-GOOGL";
        s[2] = "CLOUD-GOOGL";
    }

    function _googlNames() internal pure returns (string[] memory s) {
        s = new string[](3);
        s[0] = "Alphabet Search";
        s[1] = "Alphabet YouTube Ads";
        s[2] = "Alphabet Google Cloud";
    }

    function _nvdaSymbols() internal pure returns (string[] memory s) {
        s = new string[](3);
        s[0] = "HYPERSCALE-NVDA";
        s[1] = "AICLOUD-NVDA";
        s[2] = "EDGE-NVDA";
    }

    function _nvdaNames() internal pure returns (string[] memory s) {
        s = new string[](3);
        s[0] = "NVIDIA Hyperscale";
        s[1] = "NVIDIA AI Clouds, Industrial & Enterprise";
        s[2] = "NVIDIA Edge Computing";
    }
}
