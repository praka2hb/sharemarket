// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Fixture} from "./utils/Fixture.sol";
import {FilingResolver} from "../src/FilingResolver.sol";
import "../src/libraries/SeriesTypes.sol";

contract FilingResolverTest is Fixture {
    address internal constant BURN = 0x000000000000000000000000000000000000dEaD;

    // A wrong proposal: Cloud typed as 20,709 instead of 30,709. Inside the sanity band.
    uint256 internal constant WRONG_CLOUD = 20_709;
    string internal constant WRONG_ACCESSION = "0001652044-26-000079";

    uint256 internal id;

    function setUp() public override {
        super.setUp();
        id = _createSeries("26Q3", _closeAt());
        vm.prank(alice);
        vault.split(id, 10 * ONE);
    }

    function _close() internal {
        vm.warp(vault.getSeries(id).tradingCloseAt);
    }

    function _proposeReal(address who) internal {
        vm.prank(who);
        resolver.propose(id, Q3_CLOUD, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);
    }

    function _proposeWrong(address who) internal {
        vm.prank(who);
        resolver.propose(id, WRONG_CLOUD, Q3_SERVICES, WRONG_ACCESSION, bytes32("wrong"));
    }

    function _rstate() internal view returns (uint8) {
        return uint8(resolver.stateOf(id));
    }

    // ---------------- ppm ----------------

    function test_computePpm_realQ3() public view {
        assertEq(resolver.computePpm(Q3_CLOUD, Q3_SERVICES), Q3_PPM);
    }

    function test_computePpm_rejectsZeroAndHuge() public {
        vm.expectRevert(FilingResolver.BadFigures.selector);
        resolver.computePpm(0, 0);
        vm.expectRevert(FilingResolver.BadFigures.selector);
        resolver.computePpm(1e16, 1);
    }

    // ---------------- propose -> settle ----------------

    function test_proposeThenSettle() public {
        _close();
        uint256 bobBefore = usdc.balanceOf(bob);
        _proposeReal(bob);
        assertEq(_rstate(), uint8(ResolverState.Proposed));
        assertEq(usdc.balanceOf(bob), bobBefore - BOND);

        vm.expectRevert(FilingResolver.WindowOpen.selector);
        resolver.settle(id);

        vm.warp(block.timestamp + WINDOW);
        resolver.settle(id);
        assertEq(_rstate(), uint8(ResolverState.Done));
        assertEq(uint8(vault.stateOf(id)), uint8(State.Final));
        assertEq(vault.getSeries(id).cloudPpm, Q3_PPM);
        assertEq(usdc.balanceOf(bob), bobBefore, "bond returned");
    }

    function test_proposeRevertsWhileTrading() public {
        vm.prank(bob);
        vm.expectRevert(WrongState.selector);
        resolver.propose(id, Q3_CLOUD, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);
    }

    function test_proposeAllowedAfterCloseEarly() public {
        vm.prank(guardian);
        vault.closeEarly(id);
        _proposeReal(bob);
        assertEq(_rstate(), uint8(ResolverState.Proposed));
    }

    function test_onlyOneProposalAtATime() public {
        _close();
        _proposeReal(bob);
        vm.prank(carol);
        vm.expectRevert(WrongState.selector);
        resolver.propose(id, Q3_CLOUD, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);
    }

    // ---------------- sanity band ----------------

    function test_outsideSanityBand_goesStraightToDisputed() public {
        _close();
        // Cloud share ~40% vs fallback 18.26%: 21.8 points away.
        vm.prank(bob);
        resolver.propose(id, 64_000, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);
        assertEq(_rstate(), uint8(ResolverState.Disputed));

        // No settle path; the arbiter must decide.
        vm.warp(block.timestamp + WINDOW);
        vm.expectRevert(WrongState.selector);
        resolver.settle(id);

        // Arbiter can confirm the proposer even without a challenger; bond comes back.
        uint256 before = usdc.balanceOf(bob);
        vm.prank(arbiter);
        resolver.decide(id, FilingResolver.Choice.Proposer);
        assertEq(usdc.balanceOf(bob), before + BOND);
    }

    function test_honestQ3MoveIsInsideBand() public {
        // Q3 2026 (24.18%) vs a fallback from Q1 2026 (18.26%): 5.9 points, inside 10.
        _close();
        _proposeReal(bob);
        assertEq(_rstate(), uint8(ResolverState.Proposed));
    }

    function test_decideChallengerWithoutChallengerReverts() public {
        _close();
        vm.prank(bob);
        resolver.propose(id, 64_000, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);
        vm.prank(arbiter);
        vm.expectRevert(FilingResolver.NoChallenger.selector);
        resolver.decide(id, FilingResolver.Choice.Challenger);
    }

    // ---------------- challenge ----------------

    /// CUJ 4: wrong proposal, challenged with the real figures, arbiter sides with the challenger.
    function test_cuj4_challengerWins_takesBothBonds() public {
        _close();
        uint256 bobBefore = usdc.balanceOf(bob);
        uint256 carolBefore = usdc.balanceOf(carol);
        _proposeWrong(bob);

        vm.prank(carol);
        resolver.challenge(id, Q3_CLOUD, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);
        assertEq(_rstate(), uint8(ResolverState.Disputed));

        vm.prank(arbiter);
        resolver.decide(id, FilingResolver.Choice.Challenger);

        assertEq(vault.getSeries(id).cloudPpm, Q3_PPM);
        assertEq(usdc.balanceOf(bob), bobBefore - BOND);
        assertEq(usdc.balanceOf(carol), carolBefore + BOND);
        assertEq(usdc.balanceOf(address(resolver)), 0);

        // CUJ 5: 10 $CLOUD redeems for exactly 2.41782000 GOOGLc.
        vm.prank(alice);
        assertEq(vault.redeem(id, 10 * ONE, 0, alice), 241_782_000);
    }

    function test_proposerWins_takesBothBonds() public {
        _close();
        uint256 bobBefore = usdc.balanceOf(bob);
        _proposeReal(bob);
        vm.prank(carol);
        resolver.challenge(id, WRONG_CLOUD, Q3_SERVICES, WRONG_ACCESSION, bytes32("wrong"));
        vm.prank(arbiter);
        resolver.decide(id, FilingResolver.Choice.Proposer);
        assertEq(vault.getSeries(id).cloudPpm, Q3_PPM);
        assertEq(usdc.balanceOf(bob), bobBefore + BOND);
    }

    function test_reject_burnsAllBonds_thenNewProposalGetsFreshWindow() public {
        _close();
        _proposeWrong(bob);
        vm.prank(carol);
        resolver.challenge(id, 25_000, Q3_SERVICES, "x", bytes32("x"));

        vm.prank(arbiter);
        resolver.decide(id, FilingResolver.Choice.Reject);
        assertEq(usdc.balanceOf(BURN), 2 * BOND);
        assertEq(_rstate(), uint8(ResolverState.Open));
        assertEq(resolver.getProposal(id).proposer, address(0));

        vm.warp(block.timestamp + 10 minutes);
        _proposeReal(alice);
        uint256 t = block.timestamp;
        vm.warp(t + WINDOW - 1);
        vm.expectRevert(FilingResolver.WindowOpen.selector);
        resolver.settle(id);
        vm.warp(t + WINDOW);
        resolver.settle(id);
        assertEq(vault.getSeries(id).cloudPpm, Q3_PPM);
    }

    function test_oneChallengeOnly() public {
        _close();
        _proposeWrong(bob);
        vm.prank(carol);
        resolver.challenge(id, Q3_CLOUD, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);
        vm.prank(alice);
        vm.expectRevert(FilingResolver.AlreadyChallenged.selector);
        resolver.challenge(id, 30_000, Q3_SERVICES, "y", bytes32("y"));
    }

    function test_challengeNeedsDifferentFigures() public {
        _close();
        _proposeReal(bob);
        vm.prank(carol);
        vm.expectRevert(FilingResolver.SameFigures.selector);
        resolver.challenge(id, Q3_CLOUD, Q3_SERVICES, "other", bytes32("other"));
    }

    function test_windowEdges() public {
        _close();
        _proposeWrong(bob);
        uint256 t = block.timestamp;

        vm.warp(t + WINDOW - 1);
        vm.expectRevert(FilingResolver.WindowOpen.selector);
        resolver.settle(id);

        vm.warp(t + WINDOW);
        vm.prank(carol);
        vm.expectRevert(FilingResolver.WindowClosed.selector);
        resolver.challenge(id, Q3_CLOUD, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);
        resolver.settle(id);
    }

    function test_onlyRecordedArbiterDecides() public {
        _close();
        _proposeWrong(bob);
        vm.prank(carol);
        resolver.challenge(id, Q3_CLOUD, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);

        vm.prank(bob);
        vm.expectRevert(FilingResolver.NotArbiter.selector);
        resolver.decide(id, FilingResolver.Choice.Proposer);
    }

    function test_setArbiterDuringLiveDispute_oldArbiterStillDecides() public {
        _close();
        _proposeWrong(bob);
        vm.prank(carol);
        resolver.challenge(id, Q3_CLOUD, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);

        address newArbiter = makeAddr("newArbiter");
        vm.prank(admin);
        resolver.setArbiter(newArbiter);

        vm.prank(newArbiter);
        vm.expectRevert(FilingResolver.NotArbiter.selector);
        resolver.decide(id, FilingResolver.Choice.Proposer);

        vm.prank(arbiter);
        resolver.decide(id, FilingResolver.Choice.Challenger);
        assertEq(vault.getSeries(id).cloudPpm, Q3_PPM);
    }

    // ---------------- fallback ----------------

    function test_fallback_settlesAtConfiguredShare_returnsBonds() public {
        _close();
        _proposeWrong(bob);
        vm.prank(carol);
        resolver.challenge(id, Q3_CLOUD, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);
        uint256 bobBefore = usdc.balanceOf(bob);
        uint256 carolBefore = usdc.balanceOf(carol);

        vm.expectRevert(FilingResolver.FallbackNotDue.selector);
        resolver.fallbackFinalize(id);

        vm.warp(resolver.fallbackAt(id));
        resolver.fallbackFinalize(id);
        assertEq(vault.getSeries(id).cloudPpm, FALLBACK_PPM);
        assertEq(usdc.balanceOf(bob), bobBefore + BOND);
        assertEq(usdc.balanceOf(carol), carolBefore + BOND);
        assertEq(usdc.balanceOf(address(resolver)), 0);
    }

    function test_fallbackFromOpen_noProposals() public {
        vm.warp(resolver.fallbackAt(id));
        resolver.fallbackFinalize(id);
        assertEq(uint8(vault.stateOf(id)), uint8(State.Final));
        assertEq(vault.getSeries(id).cloudPpm, FALLBACK_PPM);
    }

    function test_proposeAfterFallbackDeadlineReverts() public {
        vm.warp(resolver.fallbackAt(id));
        vm.prank(bob);
        vm.expectRevert(FilingResolver.FallbackPassed.selector);
        resolver.propose(id, Q3_CLOUD, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);
    }

    function test_twoSeries_finalizingOlderDoesNotTouchNewer() public {
        // Newer series opens with its own fallback (2026Q2 share) and a later close.
        vm.prank(admin);
        uint256 id2 = vault.createSeries("26Q4", uint64(block.timestamp + 90 days), keccak256("26Q4"));
        vm.prank(admin);
        resolver.configureSeries(id2, 207_597, BOND);

        vm.warp(resolver.fallbackAt(id));
        resolver.fallbackFinalize(id);

        (uint32 fb2,, ResolverState st2,) = resolver.configOf(id2);
        assertEq(fb2, 207_597);
        assertEq(uint8(st2), uint8(ResolverState.Open));
        assertEq(uint8(vault.stateOf(id2)), uint8(State.Trading));
    }

    // ---------------- configuration and access ----------------

    function test_configureSeries_onceOnly_adminOnly_knownSeries() public {
        vm.prank(admin);
        vm.expectRevert(FilingResolver.AlreadyConfigured.selector);
        resolver.configureSeries(id, FALLBACK_PPM, BOND);

        vm.prank(bob);
        vm.expectRevert(NotAdmin.selector);
        resolver.configureSeries(id, FALLBACK_PPM, BOND);

        vm.prank(admin);
        vm.expectRevert(UnknownSeries.selector);
        resolver.configureSeries(99, FALLBACK_PPM, BOND);
    }

    function test_unconfiguredSeries_cannotPropose_butMergeWorks() public {
        vm.prank(admin);
        uint256 id2 = vault.createSeries("26Q4", _closeAt(), keccak256("26Q4"));
        vm.prank(alice);
        vault.split(id2, ONE);
        vm.warp(block.timestamp + 1 days);

        vm.prank(bob);
        vm.expectRevert(FilingResolver.NotConfigured.selector);
        resolver.propose(id2, Q3_CLOUD, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);

        vm.prank(alice);
        vault.merge(id2, ONE, alice);
    }

    function test_setArbiterOnlyAdmin() public {
        vm.prank(bob);
        vm.expectRevert(NotAdmin.selector);
        resolver.setArbiter(bob);
    }

    function test_nothingAfterDone() public {
        _close();
        _proposeReal(bob);
        vm.warp(block.timestamp + WINDOW);
        resolver.settle(id);

        vm.expectRevert(WrongState.selector);
        resolver.settle(id);
        vm.prank(carol);
        vm.expectRevert(WrongState.selector);
        resolver.propose(id, Q3_CLOUD, Q3_SERVICES, Q3_ACCESSION, Q3_DOC_HASH);
        vm.prank(carol);
        vm.expectRevert(WrongState.selector);
        resolver.challenge(id, 1, 2, "z", bytes32("z"));
        vm.prank(arbiter);
        vm.expectRevert(WrongState.selector);
        resolver.decide(id, FilingResolver.Choice.Reject);
        vm.warp(resolver.fallbackAt(id));
        vm.expectRevert(WrongState.selector);
        resolver.fallbackFinalize(id);
    }
}
