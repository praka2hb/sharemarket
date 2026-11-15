// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {MarketFixture} from "../utils/MarketFixture.sol";
import {VaultHandler} from "./VaultHandler.sol";

/// @notice Vault safety properties, checked after every random action (including swaps).
contract VaultInvariantTest is MarketFixture {
    VaultHandler internal handler;
    uint256 internal seeded; // stock tokens the fixture split before the handler starts

    function setUp() public override {
        super.setUp();
        seeded = googl.balanceOf(address(vault));

        address[] memory actors = new address[](3);
        actors[0] = alice;
        actors[1] = bob;
        actors[2] = carol;
        handler = new VaultHandler(vault, router, googl, actors);
        // The handler owns the mock token so it can change the multiplier and pause.
        googl.transferOwnership(address(handler));
        targetContract(address(handler));
    }

    /// Every full set is backed: stock held == supply of every piece.
    function invariant_fullyBacked() public view {
        uint256 held = googl.balanceOf(address(vault));
        for (uint256 i; i < 3; i++) {
            assertEq(held, pieces[i].totalSupply(), "stock != piece supply");
        }
    }

    /// Stock only leaves through merge: held == seeded + deposited - withdrawn.
    function invariant_accounting() public view {
        assertEq(
            googl.balanceOf(address(vault)), seeded + handler.ghostDeposited() - handler.ghostWithdrawn(), "accounting"
        );
    }

    /// The router never keeps anything between calls.
    function invariant_routerEmpty() public view {
        _assertRouterEmpty();
    }

    /// The random run must actually exercise every path, not just revert.
    function afterInvariant() public view {
        assertGt(handler.okSplits(), 0, "no split succeeded");
        assertGt(handler.okMerges(), 0, "no merge succeeded");
        assertGt(handler.okSwaps(), 0, "no swap succeeded");
    }
}
