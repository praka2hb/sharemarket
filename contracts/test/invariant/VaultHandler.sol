// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SegmentVault} from "../../src/SegmentVault.sol";
import {SegmentRouter} from "../../src/SegmentRouter.sol";
import {PieceToken} from "../../src/PieceToken.sol";
import {MockB20} from "../../src/mocks/MockB20.sol";

/// @notice Random actions by several users: split, merge, piece transfers, buys and sells of any
///         piece through the router, multiplier changes, pause/unpause and time jumps.
///         Reverts are swallowed so the run keeps going; counters record what actually succeeded.
contract VaultHandler is Test {
    SegmentVault public vault;
    SegmentRouter public router;
    MockB20 public stock;
    PieceToken[] internal pieces;
    address[] public actors;

    uint256 public ghostDeposited;
    uint256 public ghostWithdrawn;
    uint256 public okSplits;
    uint256 public okMerges;
    uint256 public okSwaps;

    constructor(SegmentVault vault_, SegmentRouter router_, MockB20 stock_, address[] memory actors_) {
        vault = vault_;
        router = router_;
        stock = stock_;
        actors = actors_;
        PieceToken[] memory ps = vault_.pieces();
        for (uint256 i; i < ps.length; i++) {
            pieces.push(ps[i]);
        }
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function _minPiece(address a) internal view returns (uint256 m) {
        m = type(uint256).max;
        for (uint256 i; i < pieces.length; i++) {
            uint256 b = pieces[i].balanceOf(a);
            if (b < m) m = b;
        }
    }

    function split(uint256 actorSeed, uint256 amount) external {
        address a = _actor(actorSeed);
        amount = bound(amount, 1, 50e8);
        vm.prank(a);
        try vault.split(amount, a) {
            ghostDeposited += amount;
            okSplits++;
        } catch {}
    }

    function merge(uint256 actorSeed, uint256 amount) external {
        address a = _actor(actorSeed);
        uint256 maxAmt = _minPiece(a);
        if (maxAmt == 0) return;
        amount = bound(amount, 1, maxAmt);
        vm.prank(a);
        try vault.merge(amount, a) {
            ghostWithdrawn += amount;
            okMerges++;
        } catch {}
    }

    function transferPiece(uint256 fromSeed, uint256 toSeed, uint256 index, uint256 amount) external {
        address from = _actor(fromSeed);
        PieceToken t = pieces[index % pieces.length];
        uint256 bal = t.balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);
        vm.prank(from);
        t.transfer(_actor(toSeed), amount);
    }

    function buy(uint256 actorSeed, uint256 index, uint256 amount) external {
        amount = bound(amount, 1e4, 20e8);
        vm.prank(_actor(actorSeed));
        try router.buy(index % pieces.length, amount, 0, block.timestamp) {
            okSwaps++;
        } catch {}
    }

    function sell(uint256 actorSeed, uint256 index, uint256 amount) external {
        address a = _actor(actorSeed);
        uint256 i = index % pieces.length;
        uint256 bal = pieces[i].balanceOf(a);
        if (bal < 1e4) return;
        amount = bound(amount, 1e4, bal);
        vm.prank(a);
        try router.sell(i, amount, 0, block.timestamp) {
            okSwaps++;
        } catch {}
    }

    function setMultiplier(uint256 m) external {
        stock.setMultiplier(bound(m, 0.5e18, 2e18)); // handler owns the mock token
    }

    function togglePause(bool on) external {
        if (on) stock.pause();
        else stock.unpause();
    }

    function warp(uint256 secs) external {
        vm.warp(block.timestamp + bound(secs, 1, 2 days));
    }
}
