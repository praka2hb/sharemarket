// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Fixture} from "../utils/Fixture.sol";
import {VaultHandler} from "./VaultHandler.sol";
import {PieceToken} from "../../src/PieceToken.sol";
import "../../src/libraries/SeriesTypes.sol";

/// @notice Vault safety properties from Technical Plan section 3, checked after every random action.
contract VaultInvariantTest is Fixture {
    VaultHandler internal handler;

    function setUp() public override {
        super.setUp();
        uint256[] memory ids = new uint256[](3);
        ids[0] = _createSeries("26Q3", uint64(block.timestamp + 1 days));
        ids[1] = _createSeries("26Q4", uint64(block.timestamp + 3 days));
        ids[2] = _createSeries("27Q1", uint64(block.timestamp + 6 days));

        address[] memory actors = new address[](3);
        actors[0] = alice;
        actors[1] = bob;
        actors[2] = carol;

        handler = new VaultHandler(vault, resolver, googl, usdc, address(this), guardian, arbiter, actors, ids);
        // The handler owns the mock token so it can change the multiplier and pause.
        googl.transferOwnership(address(handler));
        targetContract(address(handler));
    }

    /// Before Final: collateral == $CLOUD supply == $SERVICES supply.
    /// After Final: collateral covers every holder's claim (exactly, in real numbers).
    function invariant_seriesBacking() public view {
        for (uint256 i = 1; i <= vault.seriesCount(); i++) {
            Series memory s = vault.getSeries(i);
            uint256 cs = PieceToken(s.cloud).totalSupply();
            uint256 ss = PieceToken(s.services).totalSupply();
            if (s.state != State.Final) {
                assertEq(s.collateral, cs, "collateral != cloud supply");
                assertEq(s.collateral, ss, "collateral != services supply");
            } else {
                assertGe(s.collateral * PPM, cs * s.cloudPpm + ss * (PPM - s.cloudPpm), "under-collateralised");
            }
        }
    }

    /// The vault's GOOGLc balance covers every series' collateral.
    function invariant_balanceCoversCollateral() public view {
        uint256 sum;
        for (uint256 i = 1; i <= vault.seriesCount(); i++) {
            sum += vault.getSeries(i).collateral;
        }
        assertGe(googl.balanceOf(address(vault)), sum);
    }

    /// A Final series never changes its share.
    function invariant_finalPpmNeverChanges() public view {
        for (uint256 i = 1; i <= vault.seriesCount(); i++) {
            if (handler.ghostFinal(i)) {
                assertEq(uint8(vault.getSeries(i).state), uint8(State.Final));
                assertEq(vault.getSeries(i).cloudPpm, handler.ghostPpm(i));
            }
        }
    }

    /// Total GOOGLc paid out never exceeds total deposited.
    function invariant_paidOutNeverExceedsDeposited() public view {
        assertLe(handler.ghostPaidOut(), handler.ghostDeposited());
        assertEq(googl.balanceOf(address(vault)), handler.ghostDeposited() - handler.ghostPaidOut());
    }

    /// The resolver holds only bonds for live proposals.
    function invariant_resolverHoldsOnlyLiveBonds() public view {
        uint256 live;
        for (uint256 i = 1; i <= vault.seriesCount(); i++) {
            ResolverState st = resolver.stateOf(i);
            if (st == ResolverState.Proposed || st == ResolverState.Disputed) {
                live += BOND;
                if (resolver.getProposal(i).challenger != address(0)) live += BOND;
            }
        }
        assertEq(usdc.balanceOf(address(resolver)), live);
    }
}
