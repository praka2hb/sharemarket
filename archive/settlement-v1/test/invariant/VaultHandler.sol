// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SegmentVault} from "../../src/SegmentVault.sol";
import {FilingResolver} from "../../src/FilingResolver.sol";
import {PieceToken} from "../../src/PieceToken.sol";
import {MockB20} from "../../src/mocks/MockB20.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import "../../src/libraries/SeriesTypes.sol";

/// @notice Random actions across several series and actors: split, merge, redeem, piece transfers,
///         multiplier changes, pause/unpause, time jumps, early close, propose, challenge, decide,
///         settle and fallback. Reverts are swallowed so the run keeps going.
contract VaultHandler is Test {
    SegmentVault public vault;
    FilingResolver public resolver;
    MockB20 public googl;
    MockUSDC public usdc;
    address public tokenOwner;
    address public guardian;
    address public arbiter;

    address[] public actors;
    uint256[] public seriesIds;

    uint256 public ghostDeposited;
    uint256 public ghostPaidOut;
    mapping(uint256 => bool) public ghostFinal;
    mapping(uint256 => uint32) public ghostPpm;

    constructor(
        SegmentVault vault_,
        FilingResolver resolver_,
        MockB20 googl_,
        MockUSDC usdc_,
        address tokenOwner_,
        address guardian_,
        address arbiter_,
        address[] memory actors_,
        uint256[] memory seriesIds_
    ) {
        vault = vault_;
        resolver = resolver_;
        googl = googl_;
        usdc = usdc_;
        tokenOwner = tokenOwner_;
        guardian = guardian_;
        arbiter = arbiter_;
        actors = actors_;
        seriesIds = seriesIds_;
    }

    function seriesCount() external view returns (uint256) {
        return seriesIds.length;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function _series(uint256 seed) internal view returns (uint256) {
        return seriesIds[seed % seriesIds.length];
    }

    function _afterFinalCheck(uint256 id) internal {
        if (!ghostFinal[id] && vault.stateOf(id) == State.Final) {
            ghostFinal[id] = true;
            ghostPpm[id] = vault.getSeries(id).cloudPpm;
        }
    }

    // ---------------- user actions ----------------

    function split(uint256 actorSeed, uint256 seriesSeed, uint256 amount) external {
        address a = _actor(actorSeed);
        uint256 id = _series(seriesSeed);
        amount = bound(amount, 1, 50e8);
        vm.prank(a);
        try vault.split(id, amount) {
            ghostDeposited += amount;
        } catch {}
    }

    function merge(uint256 actorSeed, uint256 seriesSeed, uint256 amount) external {
        address a = _actor(actorSeed);
        uint256 id = _series(seriesSeed);
        Series memory s = vault.getSeries(id);
        uint256 maxAmt = _min(PieceToken(s.cloud).balanceOf(a), PieceToken(s.services).balanceOf(a));
        if (maxAmt == 0) return;
        amount = bound(amount, 1, maxAmt);
        vm.prank(a);
        try vault.merge(id, amount, a) {
            ghostPaidOut += amount;
        } catch {}
    }

    function redeem(uint256 actorSeed, uint256 seriesSeed, uint256 c, uint256 v) external {
        address a = _actor(actorSeed);
        uint256 id = _series(seriesSeed);
        Series memory s = vault.getSeries(id);
        c = bound(c, 0, PieceToken(s.cloud).balanceOf(a));
        v = bound(v, 0, PieceToken(s.services).balanceOf(a));
        vm.prank(a);
        try vault.redeem(id, c, v, a) returns (uint256 paid) {
            ghostPaidOut += paid;
        } catch {}
    }

    function transferPiece(uint256 fromSeed, uint256 toSeed, uint256 seriesSeed, bool cloud, uint256 amount)
        external
    {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        Series memory s = vault.getSeries(_series(seriesSeed));
        PieceToken t = PieceToken(cloud ? s.cloud : s.services);
        uint256 bal = t.balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);
        vm.prank(from);
        t.transfer(to, amount);
    }

    // ---------------- issuer / environment ----------------

    function setMultiplier(uint256 m) external {
        m = bound(m, 0.5e18, 2e18);
        googl.setMultiplier(m); // handler owns the mock token
    }

    function togglePause(bool on) external {
        if (on) googl.pause();
        else googl.unpause();
    }

    function warp(uint256 secs) external {
        secs = bound(secs, 1, 2 days);
        vm.warp(block.timestamp + secs);
    }

    function closeEarly(uint256 seriesSeed) external {
        vm.prank(guardian);
        try vault.closeEarly(_series(seriesSeed)) {} catch {}
    }

    // ---------------- settlement ----------------

    function propose(uint256 actorSeed, uint256 seriesSeed, uint256 cloudRev, uint256 servicesRev) external {
        uint256 id = _series(seriesSeed);
        cloudRev = bound(cloudRev, 0, 200_000);
        servicesRev = bound(servicesRev, 0, 200_000);
        vm.prank(_actor(actorSeed));
        try resolver.propose(id, cloudRev, servicesRev, "acc", bytes32("doc")) {} catch {}
    }

    function challenge(uint256 actorSeed, uint256 seriesSeed, uint256 cloudRev, uint256 servicesRev) external {
        uint256 id = _series(seriesSeed);
        cloudRev = bound(cloudRev, 0, 200_000);
        servicesRev = bound(servicesRev, 0, 200_000);
        vm.prank(_actor(actorSeed));
        try resolver.challenge(id, cloudRev, servicesRev, "acc2", bytes32("doc2")) {} catch {}
    }

    function decide(uint256 seriesSeed, uint8 choice) external {
        uint256 id = _series(seriesSeed);
        vm.prank(arbiter);
        try resolver.decide(id, FilingResolver.Choice(choice % 3)) {} catch {}
        _afterFinalCheck(id);
    }

    function settle(uint256 seriesSeed) external {
        uint256 id = _series(seriesSeed);
        try resolver.settle(id) {} catch {}
        _afterFinalCheck(id);
    }

    function fallbackFinalize(uint256 seriesSeed) external {
        uint256 id = _series(seriesSeed);
        try resolver.fallbackFinalize(id) {} catch {}
        _afterFinalCheck(id);
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
