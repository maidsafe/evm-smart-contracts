// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/src/console.sol";

import "./Helper.sol";
import "../src/AppRegistry.sol";
import "../src/Phase1Voting.sol";
import "./DummyToken.sol";

contract Phase1VotingTest is Helper {
    AppRegistry public appRegistry;
    Phase1Voting public v;
    DummyToken public ant;

    bytes32 public appId1;
    bytes32 public appId2;
    bytes32 public appId3;
    bytes32 public appId4;

    uint256 public K = 2;

    bytes32[] public registeredApps;

    function setUp() public {
        vm.startPrank(dev);

        appRegistry = new AppRegistry(dev);
        ant = new DummyToken("Token", "T");
        v = new Phase1Voting(100 ether, K, appRegistry, ant, dev, 1, 2e18);

        ant.approve(address(v), type(uint256).max);

        vm.stopPrank();
    }

    function test_constructor_args() public {
        vm.startPrank(dev);

        vm.expectRevert(IPhase1Voting.BCantBeZero.selector);
        v = new Phase1Voting(0, K, appRegistry, ant, dev, 1, 2e18);

        vm.expectRevert(IPhase1Voting.KCantBeZero.selector);
        v = new Phase1Voting(100 ether, 0, appRegistry, ant, dev, 1, 2e18);

        vm.expectRevert(IPhase1Voting.ZeroAddress.selector);
        v = new Phase1Voting(100 ether, K, IAppRegistry(address(0)), ant, dev, 1, 2e18);

        vm.expectRevert(IPhase1Voting.ZeroAddress.selector);
        v = new Phase1Voting(100 ether, K, appRegistry, IERC20(address(0)), dev, 1, 2e18);

        vm.expectRevert(IPhase1Voting.ZeroAddress.selector);
        v = new Phase1Voting(100 ether, K, appRegistry, ant, address(0), 1, 2e18);

        vm.expectRevert(IPhase1Voting.InvalidMaxMultiplier.selector);
        v = new Phase1Voting(100 ether, K, appRegistry, ant, dev, 1, 1e17);

        vm.expectRevert(IPhase1Voting.InvalidVotingStartTime.selector);
        v = new Phase1Voting(100 ether, K, appRegistry, ant, dev, 0, 1e18);

        vm.stopPrank();
    }

    /* 
       ====================================== 
       =============== python ===============
       ======================================
    */
    // replicate the logic from the python test
    function test_costCalculations() public {
        // 1. register 4 apps
        _registerApps();

        vm.startPrank(dev);
        // 2. make sure that the initial prices are all 0.5
        assertEq(500000000000000000, v.instantaneousMarketPrice(appId1));
        assertEq(500000000000000000, v.instantaneousMarketPrice(appId2));
        assertEq(500000000000000000, v.instantaneousMarketPrice(appId3));
        assertEq(500000000000000000, v.instantaneousMarketPrice(appId4));
        // 3. make sure that the prices all sum to K
        assertEq(
            v.K() * 1e18,
            v.instantaneousMarketPrice(appId1) + v.instantaneousMarketPrice(appId2) + v.instantaneousMarketPrice(appId3)
                + v.instantaneousMarketPrice(appId4)
        );

        // --- Buying 1 Share of Candidate 0 ---

        // 4. Check that cOld 138.62943611198907 and cNew is 138.8803751735027
        assertApproxEqAbs(138629436111989070000, v.c(appRegistry.getAppIds(), bytes32(""), 0), 10000);
        assertApproxEqAbs(138880375173502700000, v.c(appRegistry.getAppIds(), appId1, 1 ether), 100000);

        // 5. Check that cost of buying 1 vote is ANT 0.501878
        assertApproxEqAbs(501878000000000000, v.userCost(appId1, 1 ether), 1000000000000);

        v.vote(appId1, 1 ether);

        // 6. Check Prices after buy: [0.50375937 0.49874688 0.49874688 0.49874688]
        assertApproxEqAbs(503759370000000000, v.instantaneousMarketPrice(appId1), 10000000000);
        assertApproxEqAbs(498746880000000000, v.instantaneousMarketPrice(appId2), 100000000000);
        assertApproxEqAbs(498746880000000000, v.instantaneousMarketPrice(appId3), 100000000000);
        assertApproxEqAbs(498746880000000000, v.instantaneousMarketPrice(appId4), 100000000000);

        // 7. Make sure they sum up to K
        assertApproxEqAbs(
            2 ether,
            v.instantaneousMarketPrice(appId1) + v.instantaneousMarketPrice(appId2) + v.instantaneousMarketPrice(appId3)
                + v.instantaneousMarketPrice(appId4),
            20
        );

        // --- Buying 10 Shares of Candidate 1 ---
        // 8. make sure cNew 141.46925593346094
        uint256 cNew = v.c(appRegistry.getAppIds(), appId2, 10 ether);
        assertApproxEqAbs(141469255933460940000, cNew, 10000);

        // 9. Check that the cost is 5.177762 ANT
        uint256 userCost = v.userCost(appId2, 10 ether);
        assertApproxEqAbs(5177762000000000000, userCost, 1000000000000);

        v.vote(appId2, 10 ether);

        // 10. Sum should always be K
        assertApproxEqAbs(
            2 ether,
            v.instantaneousMarketPrice(appId1) + v.instantaneousMarketPrice(appId2) + v.instantaneousMarketPrice(appId3)
                + v.instantaneousMarketPrice(appId4),
            20
        );

        vm.stopPrank();
    }

    function test_lowLiquidity() public {
        vm.startPrank(dev);
        Phase1Voting vLowLiquidity = new Phase1Voting(1 ether, 1, appRegistry, ant, dev, 1, 2e18);
        appId1 = appRegistry.registerApp(dev, "Test app 1", "This is test app no. 1", "https://autonomi.com");
        appId2 = appRegistry.registerApp(dev, "Test app 2", "This is test app no. 2", "https://autonomi.com");
        appId3 = appRegistry.registerApp(dev, "Test app 3", "This is test app no. 3", "https://autonomi.com");

        assertApproxEqAbs(vLowLiquidity.instantaneousMarketPrice(appId1), 333333333333333333, 10);
        assertApproxEqAbs(vLowLiquidity.instantaneousMarketPrice(appId2), 333333333333333333, 10);
        assertApproxEqAbs(vLowLiquidity.instantaneousMarketPrice(appId3), 333333333333333333, 10);

        uint256 cOld = vLowLiquidity.c(appRegistry.getAppIds(), bytes32(""), 0);
        assertApproxEqAbs(1098612288668109800, cOld, 1000);

        uint256 cNew = vLowLiquidity.c(appRegistry.getAppIds(), appId1, 1 ether);
        assertApproxEqAbs(1551444713932051000, cNew, 1000);

        uint256 userCost = vLowLiquidity.userCost(appId1, 1 ether);
        assertApproxEqAbs(452832000000000000, userCost, 1000000000000);

        ant.approve(address(vLowLiquidity), type(uint256).max);

        vLowLiquidity.vote(appId1, 1 ether);

        assertApproxEqAbs(576116880000000000, vLowLiquidity.instantaneousMarketPrice(appId1), 10000000000);
        assertApproxEqAbs(211941560000000000, vLowLiquidity.instantaneousMarketPrice(appId2), 10000000000);
        assertApproxEqAbs(211941560000000000, vLowLiquidity.instantaneousMarketPrice(appId3), 10000000000);

        vm.stopPrank();
    }

    /* 
       ====================================== 
       ================ vote ================
       ======================================
    */
    function test_vote() public {
        _registerApps();
        vm.startPrank(dev);

        vm.expectEmit(true, true, true, false);
        emit IPhase1Voting.Voted(dev, appId1, 1 ether);
        v.vote(appId1, 1 ether);

        uint256 votesForApp = v.votesForApp(appId1);
        assertEq(votesForApp, 1 ether);

        uint256 userTotalVotes = v.getUserTotalVotes(dev);
        assertEq(userTotalVotes, 1 ether);

        uint256 userVotesLength = v.getUserVotesLength(dev);
        assertEq(userVotesLength, 1);
        vm.stopPrank();
    }

    function test_cannot_vote_votingNotActive() public {
        _registerApps();
        vm.startPrank(dev);
        vm.warp(v.VOTING_START_TIME() + v.VOTING_DURATION() + 10);
        vm.expectRevert(IPhase1Voting.VotingNotActive.selector);
        v.vote(appId1, 1 ether);

        vm.warp(v.VOTING_START_TIME() - 1);
        vm.expectRevert(IPhase1Voting.VotingNotActive.selector);
        v.vote(appId1, 1 ether);

        vm.stopPrank();
    }

    function test_cannot_vote_invalidAppId() public {
        vm.expectRevert(IPhase1Voting.InvalidAppId.selector);
        v.vote(bytes32("asd"), 1 ether);
    }

    function test_cannot_vote_minimumOneVoteRequired() public {
        _registerApps();
        vm.startPrank(dev);

        vm.expectRevert(IPhase1Voting.MinimumOneVoteRequired.selector);
        v.vote(appId1, 1);

        vm.expectRevert(IPhase1Voting.MinimumOneVoteRequired.selector);
        v.vote(appId1, 999999999999999999);

        uint256 votesForApp = v.votesForApp(appId1);
        assertEq(votesForApp, 0);
    }

    function test_cannot_vote_noAnt() public {
        _registerApps();
        vm.prank(users[1]);
        vm.expectRevert();
        v.vote(appId1, 1 ether);
    }

    function test_cannot_vote_missingAntAllowance() public {
        _registerApps();
        vm.startPrank(dev);
        ant.approve(address(v), 0);
        vm.expectRevert();
        v.vote(appId1, 1 ether);
        vm.stopPrank();
    }

    /* 
       ====================================== 
       ========== getLeaderboard ============
       ======================================
    */
    function test_getLeaderboard() public {
        _registerApps();
        vm.startPrank(dev);
        v.vote(appId1, 1 ether);

        IPhase1Voting.Vote[] memory _leaderboard = v.getLeaderboard();
        assertEq(_leaderboard.length, appRegistry.getAppsLength());
        assertEq(_leaderboard[0].appId, appId1);
        assertEq(_leaderboard[0].votes, 1 ether);

        v.vote(appId2, 2 ether);
        _leaderboard = v.getLeaderboard();
        assertEq(_leaderboard.length, appRegistry.getAppsLength());
        assertEq(_leaderboard[0].appId, appId2);
        assertEq(_leaderboard[0].votes, 2 ether);
        assertEq(_leaderboard[1].appId, appId1);
        assertEq(_leaderboard[1].votes, 1 ether);

        v.vote(appId3, 10 ether);
        v.vote(appId4, 30 ether);
        v.vote(appId1, 4 ether);
        v.vote(appId2, 3 ether);

        _leaderboard = v.getLeaderboard();
        assertEq(_leaderboard.length, appRegistry.getAppsLength());
        assertEq(_leaderboard[0].appId, appId4);
        assertEq(_leaderboard[0].votes, 30 ether);
        assertEq(_leaderboard[1].appId, appId3);
        assertEq(_leaderboard[1].votes, 10 ether);

        assertEq(_leaderboard[2].appId, appId1);
        assertEq(_leaderboard[2].votes, 5 ether);
        assertEq(_leaderboard[3].appId, appId2);
        assertEq(_leaderboard[3].votes, 5 ether);
    }

    /* 
       ====================================== 
       ============ getUserVotes ============
       ======================================
    */
    function test_getUserVotes() public {
        _registerApps();
        vm.startPrank(dev);

        v.vote(appId1, 1 ether);

        IPhase1Voting.Vote[] memory userVotes = v.getUserVotes(dev);
        assertEq(userVotes.length, 1);
        assertEq(userVotes[0].appId, appId1);
        assertEq(userVotes[0].votes, 1 ether);

        v.vote(appId2, 1 ether);
        v.vote(appId3, 1 ether);
        v.vote(appId4, 1 ether);

        userVotes = v.getUserVotes(dev);
        assertEq(userVotes.length, 4);
        assertEq(userVotes[0].appId, appId1);
        assertEq(userVotes[0].votes, 1 ether);
        assertEq(userVotes[1].appId, appId2);
        assertEq(userVotes[1].votes, 1 ether);
        assertEq(userVotes[2].appId, appId3);
        assertEq(userVotes[2].votes, 1 ether);
        assertEq(userVotes[3].appId, appId4);
        assertEq(userVotes[3].votes, 1 ether);

        vm.stopPrank();
    }

    /* 
       ====================================== 
       ======== getUserVotesLength ==========
       ======================================
    */
    function test_getUserVotesLength() public {
        _registerApps();
        vm.startPrank(dev);
        v.vote(appId1, 1 ether);
        uint256 userVotesLength = v.getUserVotesLength(dev);
        assertEq(userVotesLength, 1);

        v.vote(appId1, 1 ether);
        userVotesLength = v.getUserVotesLength(dev);
        assertEq(userVotesLength, 2);

        v.vote(appId1, 1 ether);
        userVotesLength = v.getUserVotesLength(dev);
        assertEq(userVotesLength, 3);

        v.vote(appId1, 1 ether);
        userVotesLength = v.getUserVotesLength(dev);
        assertEq(userVotesLength, 4);

        v.vote(appId1, 1 ether);
        userVotesLength = v.getUserVotesLength(dev);
        assertEq(userVotesLength, 5);

        vm.stopPrank();
    }

    /* 
       ====================================== 
       ========= getUserTotalVotes ==========
       ======================================
    */
    function test_getUserTotalVotes() public {
        _registerApps();
        vm.startPrank(dev);

        v.vote(appId1, 1 ether);
        uint256 totalVotes = v.getUserTotalVotes(dev);
        assertEq(totalVotes, 1 ether);

        v.vote(appId2, 10 ether);
        totalVotes = v.getUserTotalVotes(dev);
        assertEq(totalVotes, 11 ether);

        v.vote(appId3, 9 ether);
        totalVotes = v.getUserTotalVotes(dev);
        assertEq(totalVotes, 20 ether);

        v.vote(appId4, 6 ether);
        totalVotes = v.getUserTotalVotes(dev);
        assertEq(totalVotes, 26 ether);

        v.vote(appId2, 10 ether);
        totalVotes = v.getUserTotalVotes(dev);
        assertEq(totalVotes, 36 ether);

        vm.stopPrank();
    }

    /* 
       ====================================== 
       ================= c ==================
       ======================================
    */
    function test_cc(uint256 voteCount) public {
        vm.assume(voteCount > 1);
        vm.assume(voteCount < 30);

        _registerApps();
        vm.startPrank(dev);

        uint256 baseIncrease = 250000000000000000;
        if (voteCount > 10) {
            baseIncrease = 270000000000000000;
        }
        if (voteCount > 20) {
            baseIncrease = 276300000000000000;
        }

        voteCount = voteCount * 1e18;

        uint256 oneVoteCost = 138880375173502722400;
        uint256 expectedIncrease = baseIncrease * ((voteCount / 1e18) - 1);

        uint256 cost = v.c(appRegistry.getAppIds(), appId1, voteCount);

        uint256 expectedCost = oneVoteCost + expectedIncrease;

        assertApproxEqAbs(expectedCost, cost, 100000000000000000);

        vm.stopPrank();
    }

    /* 
       ====================================== 
       ============== userCost ==============
       ======================================
    */
    function test_userCost() public {
        _registerApps();

        vm.startPrank(dev);

        assertApproxEqAbs(501878000000000000, v.userCost(appId1, 1 ether), 1000000000000);

        v.vote(appId1, 1 ether);

        uint256 userCost = v.userCost(appId2, 10 ether);
        assertApproxEqAbs(5177762000000000000, userCost, 1000000000000);

        vm.stopPrank();
    }

    function test_userCost_GtZero() public {
        uint256 appsCount = 49;
        uint256 votesCount = 5000;

        vm.pauseGasMetering();

        vm.startPrank(dev);

        v.setAntBeneficiary(users[5]);
        v.setB(3000 ether);

        _registerRandomApps(appsCount);

        for (uint256 i = 0; i < votesCount; i++) {
            uint256 appIdIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, votesCount, i)))
                % registeredApps.length;

            bytes32 appId = registeredApps[appIdIndex];

            uint256 voteAmount = (
                uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, appIdIndex, votesCount))) % 1000
                    + 1
            ) * 1e18;

            uint256 _userCost = v.userCost(appId, voteAmount);
            if (_userCost == 0) {
                vm.expectRevert(IPhase1Voting.ZeroUserCostNotAllowed.selector);
                v.vote(appId, voteAmount);

                console.log("zero user cost with vote amount: ", voteAmount);

                while (_userCost == 0) {
                    voteAmount = voteAmount * 2;
                    _userCost = v.userCost(appId, voteAmount);
                }
                console.log("new vote amount: ", voteAmount);
                console.log("new cost: ", v.userCost(appId, voteAmount));
            }

            assertGt(_userCost, 0);
            v.vote(appId, voteAmount);
        }

        uint256 antSpending = ant.balanceOf(users[5]);
        console.log("ANT SPENT TOTAL: ", antSpending);
    }

    function test_userCostWithTimeMultiplier() public {
        // Do a lot of votes
        uint256 voteStartTime = 1;
        vm.pauseGasMetering();
        vm.startPrank(dev);

        v = new Phase1Voting(3000 ether, 12, appRegistry, ant, dev, 1, 2.5e18);

        ant.approve(address(v), type(uint256).max);

        v.setAntBeneficiary(users[5]);

        _registerRandomApps(65);

        uint256 votesCount = 1000;

        for (uint256 i = 0; i < votesCount; i++) {
            uint256 appIdIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, votesCount, i)))
                % registeredApps.length;

            bytes32 appId = registeredApps[appIdIndex];

            uint256 voteAmount = (
                uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, appIdIndex, votesCount))) % 1000
                    + 1
            ) * 1e18;

            v.vote(appId, voteAmount);
        }

        IPhase1Voting.Vote[] memory _leaderboard = v.getLeaderboard();
        IPhase1Voting.Vote memory lastApp = _leaderboard[_leaderboard.length - 1];

        uint256 uCost = v.userCost(lastApp.appId, _leaderboard[0].votes);

        // move the timestamp forward so that t/T = 0.3 -> check that time multiplier is 0
        vm.warp(voteStartTime + 2.1 days);
        assertEq(1 ether, v.timeMultiplier());
        uint256 uCost2 = v.userCost(lastApp.appId, _leaderboard[0].votes);
        assertEq(uCost, uCost2);

        // move the timestamp forward so that t/T = 0.5 -> check that time multiplier is 0
        vm.warp(voteStartTime + 3.5 days);
        assertEq(1 ether, v.timeMultiplier());
        uCost2 = v.userCost(lastApp.appId, _leaderboard[0].votes);
        assertEq(uCost, uCost2);

        // move the timestamp forward so that t/T = 0.7 -> check that time multiplier is 0
        vm.warp(voteStartTime + 4.9 days);
        assertEq(1 ether, v.timeMultiplier());
        uCost2 = v.userCost(lastApp.appId, _leaderboard[0].votes);
        assertEq(uCost, uCost2);

        // move the timestamp forward so that t/T = 0.9 -> check that time multiplier increases
        vm.warp(voteStartTime + 6.3 days);
        assertEq(2.215 ether, v.timeMultiplier());
        uCost2 = v.userCost(lastApp.appId, _leaderboard[0].votes);
        assertGt(uCost2, uCost * 2);

        // move the timestamp forward so that t/T = 0.93 -> check that time multiplier increases
        vm.warp(voteStartTime + 6.51 days);
        assertEq(2297350000000000000, v.timeMultiplier());
        uCost2 = v.userCost(lastApp.appId, _leaderboard[0].votes);
        assertGt(uCost2, uCost * 2);

        // move the timestamp forward so that t/T = 0.95 -> check that time multiplier increases
        vm.warp(voteStartTime + 6.65 days);
        assertEq(2353750000000000000, v.timeMultiplier());
        uCost2 = v.userCost(lastApp.appId, _leaderboard[0].votes);
        assertGt(uCost2, uCost * 2);

        // move the timestamp forward so that t/T = 0.98 -> check that time multiplier increases
        vm.warp(voteStartTime + 6.86 days);
        assertEq(2440600000000000000, v.timeMultiplier());
        uCost2 = v.userCost(lastApp.appId, _leaderboard[0].votes);
        assertGt(uCost2, uCost * 2);
        
        // move the timestamp forward so that t/T = 0.99 -> check that time multiplier increases
        vm.warp(voteStartTime + 6.93 days);
        uCost2 = v.userCost(lastApp.appId, _leaderboard[0].votes);
        assertGt(uCost2, uCost * 2);
    }

    function test_randomVotes() public {
        // Do a lot of votes
        vm.pauseGasMetering();
        vm.startPrank(dev);

        v = new Phase1Voting(4000817287620000000000, 12, appRegistry, ant, dev, 1, 2e18);

        ant.approve(address(v), type(uint256).max);

        v.setAntBeneficiary(users[5]);

        _registerRandomApps(34);

        uint256 votesCount = 5000;

        console.log("Apps: ", appRegistry.appsCount());

        uint256 zeroCosts;

        for (uint256 i = 0; i < votesCount; i++) {
            uint256 appIdIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, votesCount, i)))
                % registeredApps.length;

            bytes32 appId = registeredApps[appIdIndex];

            uint256 voteAmount = (
                uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, appIdIndex, votesCount))) % 1000
                    + 1
            ) * 1e18;

            if (voteAmount > 1000 ether) {
                revert(":(");
            }

            uint256 uCost = v.userCost(appId, voteAmount);
            if (uCost == 0) {
                zeroCosts++;
                continue;
            }

            uint256 leadersVotes = getTotalVotesCastForLeaderboard();

            if (leadersVotes > v.totalAntPaid() + 50_000 ether) {
                revert("FAIL");
            }
            console.log("total ant spent: ", v.totalAntPaid());
            console.log("votes count: ", i);
            v.vote(appId, voteAmount);
        }

        for (uint256 i = 0; i < votesCount; i++) {
            uint256 appIdIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, votesCount, i)))
                % registeredApps.length;

            bytes32 appId = registeredApps[appIdIndex];

            uint256 voteAmount = (
                uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, appIdIndex, votesCount))) % 1000
                    + 1
            ) * 1e18;

            if (voteAmount > 1000 ether) {
                revert(":(");
            }

            uint256 uCost = v.userCost(appId, voteAmount);
            if (uCost == 0) {
                zeroCosts++;
                continue;
            }

            uint256 leadersVotes = getTotalVotesCastForLeaderboard();

            if (leadersVotes > v.totalAntPaid() + 50_000 ether) {
                revert("FAIL");
            }

            console.log("total votes cast: ", leadersVotes);
            console.log("total ant spent: ", v.totalAntPaid());
            console.log("votes count: ", i);
            v.vote(appId, voteAmount);
        }

        console.log("zero costs: ", zeroCosts);
    }

    function getTotalVotesCastForLeaderboard() public view returns (uint256) {
        IPhase1Voting.Vote[] memory leaderboard = v.getLeaderboard();

        uint256 totalVotesForLeaders;

        for (uint256 i = 0; i < 12; i++) {
            totalVotesForLeaders += leaderboard[i].votes;
        }

        return totalVotesForLeaders;
    }

    function test_userCost_ZeroCostNotAllowed() public {
        uint256 voteStartTime = 1;
        vm.pauseGasMetering();

        vm.startPrank(dev);

        v = new Phase1Voting(4000817287620000000000, 12, appRegistry, ant, dev, 1, 2.5e18);

        ant.approve(address(v), type(uint256).max);

        v.setAntBeneficiary(users[5]);

        _registerRandomApps(65);

        uint256 votesCount = 7000;

        for (uint256 i = 0; i < votesCount; i++) {
            uint256 appIdIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, votesCount, i)))
                % registeredApps.length;

            bytes32 appId = registeredApps[appIdIndex];

            uint256 voteAmount = (
                uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, appIdIndex, votesCount))) % 1000
                    + 1
            ) * 1e18;

            uint256 _userCost = v.userCost(appId, voteAmount);
            if (_userCost == 0) {
                vm.expectRevert(IPhase1Voting.ZeroUserCostNotAllowed.selector);
                v.vote(appId, voteAmount);

                while (_userCost == 0) {
                    voteAmount = voteAmount * 2;
                    _userCost = v.userCost(appId, voteAmount);
                }
            }
            v.vote(appId, voteAmount);
        }

        IPhase1Voting.Vote[] memory _leaderboard = v.getLeaderboard();

        uint256 firstAppVotesCount = _leaderboard[0].votes;
        console.log("First app has votes: ", firstAppVotesCount);

        console.logBytes32(_leaderboard[0].appId);

        console.logBytes32(_leaderboard[_leaderboard.length - 1].appId);

        console.log("last app has votes: ", _leaderboard[_leaderboard.length - 1].votes);

        uint256 costToBuy = v.userCost(_leaderboard[_leaderboard.length - 1].appId, firstAppVotesCount);
        console.log("Cost to buy: ", costToBuy);

        uint256 antSpending = ant.balanceOf(users[5]);
        console.log("ANT SPENT TOTAL: ", antSpending);

        vm.warp(voteStartTime + 6.9 days);

        costToBuy = v.userCost(_leaderboard[_leaderboard.length - 1].appId, firstAppVotesCount);
        console.log("Cost to buy later: ", costToBuy);
    }

    /* 
       ====================================== 
       ====== instantaneousMarketPrice ======
       ======================================
    */
    function test_instantaneousMarketPrice(uint256 votesBuyCount) public {
        _registerApps();
        vm.startPrank(dev);
        vm.assume(votesBuyCount > 1);
        vm.assume(votesBuyCount < 30);

        uint256 p = 500000000000000000;
        uint256 avgDiff = 3800000000000000;
        uint256 maxDelta = 500000000000000;

        for (uint256 i = 0; i < votesBuyCount; i++) {
            v.vote(appId1, 1 ether);
            uint256 newP = v.instantaneousMarketPrice(appId1);
            assertApproxEqAbs(newP - p, avgDiff, maxDelta);
            p = newP;
        }

        vm.stopPrank();
    }

    function test_cannot_instantaneousMarketPrice_invalidAppId() public {
        vm.expectRevert(IPhase1Voting.InvalidAppId.selector);
        v.instantaneousMarketPrice(appId1);
    }

    /* 
       ====================================== 
       ========= setAntBeneficiary ==========
       ======================================
    */
    function test_setAntBeneficiary() public {
        vm.prank(dev);
        v.setAntBeneficiary(users[1]);
        assertEq(users[1], v.antBeneficiary());
    }

    function test_cannot_setAntBeneficiary_NotOwner() public {
        vm.expectRevert();
        v.setAntBeneficiary(users[1]);
    }

    function test_cannot_setAntBeneficiary_ZeroAddress() public {
        vm.prank(dev);
        vm.expectRevert(IPhase1Voting.ZeroAddress.selector);
        v.setAntBeneficiary(address(0));
    }

    /* 
       ====================================== 
       ================ setB ================
       ======================================
    */
    function test_setB() public {
        vm.prank(dev);
        v.setB(200 ether);
        assertEq(200 ether, v.b());
    }

    function test_cannot_setB_notOwner() public {
        vm.expectRevert();
        v.setB(100 ether);
    }

    function test_cannot_setB_bCantBeZero() public {
        vm.prank(dev);
        vm.expectRevert(IPhase1Voting.BCantBeZero.selector);
        v.setB(0);
    }

    function _registerApps() private {
        // 1. register 4 apps
        vm.startPrank(dev);
        appId1 = appRegistry.registerApp(dev, "Test app 1", "This is test app no. 1", "https://autonomi.com");
        appId2 = appRegistry.registerApp(dev, "Test app 2", "This is test app no. 2", "https://autonomi.com");
        appId3 = appRegistry.registerApp(dev, "Test app 3", "This is test app no. 3", "https://autonomi.com");
        appId4 = appRegistry.registerApp(dev, "Test app 4", "This is test app no. 4", "https://autonomi.com");
        vm.stopPrank();
    }

    function _registerRandomApps(uint256 appsCount) private {
        for (uint256 i = 0; i < appsCount; i++) {
            string memory name = string(abi.encodePacked("App", vm.toString(registeredApps.length + 1)));
            string memory description = string(abi.encodePacked("Description", vm.toString(registeredApps.length + 1)));
            string memory uri = string(abi.encodePacked("uri", vm.toString(registeredApps.length + 1)));

            bytes32 newAppId = appRegistry.registerApp(users[2], name, description, uri);
            registeredApps.push(newAppId);
        }
    }

    function _logLeaderboard() internal view {
        IPhase1Voting.Vote[] memory _leaderboard = v.getLeaderboard();
        for (uint256 i = 0; i < _leaderboard.length; i++) {
            console.log(i, ".) ", _leaderboard[i].votes);
        }
    }
}
