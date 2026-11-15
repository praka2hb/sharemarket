// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {SegmentVault} from "../src/SegmentVault.sol";
import {FilingResolver} from "../src/FilingResolver.sol";

/// @notice Opens one quarter: vault.createSeries, then resolver.configureSeries, from the admin wallet.
///         Env (all optional):
///           LABEL         default "26Q4"
///           CLOSE_AT      unix time trading closes; default now + 7 days
///           FALLBACK_PPM  default 241782 (Q3 2026, the latest final share)
///           BOND          default 1,000 mock USDC (1000e6)
///           RULE_FILE     default ../docs/rules/GOOGL-segment-rule-v1.md (its keccak256 is the ruleHash)
///         Appends the series id to DEPLOYMENTS_FILE's sibling: <file>.series-<LABEL>.json
contract CreateSeries is Script {
    function run() external {
        string memory file = vm.envOr("DEPLOYMENTS_FILE", string("../deployments/base-sepolia.json"));
        string memory dep = vm.readFile(file);
        SegmentVault vault = SegmentVault(vm.parseJsonAddress(dep, ".vault"));
        FilingResolver resolver = FilingResolver(vm.parseJsonAddress(dep, ".resolver"));

        string memory label = vm.envOr("LABEL", string("26Q4"));
        uint64 closeAt = uint64(vm.envOr("CLOSE_AT", block.timestamp + 7 days));
        uint32 fallbackPpm = uint32(vm.envOr("FALLBACK_PPM", uint256(241_782)));
        uint256 bond = vm.envOr("BOND", uint256(1_000e6));

        string memory ruleFile = vm.envOr("RULE_FILE", string("../docs/rules/GOOGL-segment-rule-v1.md"));
        bytes32 ruleHash;
        if (vm.exists(ruleFile)) {
            ruleHash = keccak256(bytes(vm.readFile(ruleFile)));
        } else {
            console2.log("WARNING: rule file not found, ruleHash = 0:", ruleFile);
        }

        vm.startBroadcast();
        uint256 id = vault.createSeries(label, closeAt, ruleHash);
        resolver.configureSeries(id, fallbackPpm, bond);
        vm.stopBroadcast();

        string memory k = "series";
        vm.serializeString(k, "label", label);
        vm.serializeUint(k, "id", id);
        vm.serializeUint(k, "tradingCloseAt", closeAt);
        vm.serializeUint(k, "fallbackPpm", fallbackPpm);
        vm.serializeUint(k, "bond", bond);
        vm.serializeBytes32(k, "ruleHash", ruleHash);
        vm.serializeAddress(k, "cloud", vault.getSeries(id).cloud);
        string memory json = vm.serializeAddress(k, "services", vault.getSeries(id).services);
        string memory out = string.concat(file, ".series-", label, ".json");
        vm.writeJson(json, out);

        console2.log("series id", id);
        console2.log("cloud    ", vault.getSeries(id).cloud);
        console2.log("written to", out);
    }
}
