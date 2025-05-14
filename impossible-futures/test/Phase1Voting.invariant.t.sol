// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/console.sol";
import "./Helper.sol";
import "../src/AppRegistry.sol";
import "../src/Phase1Voting.sol";
import "./DummyToken.sol";

contract Phase1VotingInvariantTest is Helper {
    Phase1Voting public v;
    AppRegistry public appRegistry;
    DummyToken public ant;

    bytes32[] public registeredApps;

    uint256 public K = 12;

    uint256 numUsers = 19;

    function setUp() public {
        vm.startPrank(dev);

        appRegistry = new AppRegistry(dev);
        ant = new DummyToken("Token", "T");
        v = new Phase1Voting(4001 ether, K, appRegistry, ant, dev, 1, 2e18);

        ant.approve(address(v), type(uint256).max);

        bytes32 appId1 = appRegistry.registerApp(dev, "Test app 1", "This is test app no. 1", "https://autonomi.com");
        bytes32 appId2 = appRegistry.registerApp(dev, "Test app 2", "This is test app no. 2", "https://autonomi.com");
        bytes32 appId3 = appRegistry.registerApp(dev, "Test app 3", "This is test app no. 3", "https://autonomi.com");
        bytes32 appId4 = appRegistry.registerApp(dev, "Test app 4", "This is test app no. 4", "https://autonomi.com");

        registeredApps.push(appId1);
        registeredApps.push(appId2);
        registeredApps.push(appId3);
        registeredApps.push(appId4);

        targetContract(address(this));

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = this.registerRandomApp.selector;
        selectors[1] = this.voteRandom.selector;
        selectors[2] = this.registerRandomApps.selector;
        selectors[3] = this.voteRandomMultiple.selector;
        targetSelector(FuzzSelector({addr: address(this), selectors: selectors}));

        vm.stopPrank();
    }

    function registerRandomApp() public {
        uint256 userIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % numUsers;
        address controller = users[userIndex];

        string memory name = string(abi.encodePacked("App", vm.toString(registeredApps.length + 1)));
        string memory description = string(abi.encodePacked("Description", vm.toString(registeredApps.length + 1)));
        string memory uri = string(abi.encodePacked("uri", vm.toString(registeredApps.length + 1)));

        vm.prank(dev);
        bytes32 newAppId = appRegistry.registerApp(controller, name, description, uri);
        registeredApps.push(newAppId);
    }

    function registerRandomApps(uint256 count) public {
        vm.assume(count > 0);
        vm.assume(count < 100);

        for (uint256 i = 0; i < count; i++) {
            uint256 userIndex =
                uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, count, i))) % numUsers;
            address controller = users[userIndex];

            string memory name = string(abi.encodePacked("App", vm.toString(registeredApps.length + 1)));
            string memory description = string(abi.encodePacked("Description", vm.toString(registeredApps.length + 1)));
            string memory uri = string(abi.encodePacked("uri", vm.toString(registeredApps.length + 1)));

            vm.prank(dev);
            bytes32 newAppId = appRegistry.registerApp(controller, name, description, uri);
            registeredApps.push(newAppId);
        }
    }

    function voteRandom() public {
        if (registeredApps.length == 0) return;

        uint256 appIdIndex =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % registeredApps.length;
        bytes32 appId = registeredApps[appIdIndex];

        uint256 voteAmount =
            (uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, appIdIndex))) % 1000 + 1) * 1e18;

        vm.prank(dev);
        v.vote(appId, voteAmount);
    }

    function voteRandomMultiple(uint256 count) public {
        if (registeredApps.length == 0) return;

        vm.assume(count > 0);
        vm.assume(count < 100);

        for (uint256 i = 0; i < count; i++) {
            uint256 appIdIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, count, i)))
                % registeredApps.length;
            bytes32 appId = registeredApps[appIdIndex];

            uint256 voteAmount = (
                uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, appIdIndex, count))) % 1000 + 1
            ) * 1e18;

            uint256 _userCost = v.userCost(appId, voteAmount);
            assertGt(_userCost, 1);
            vm.prank(dev);
            v.vote(appId, voteAmount);
        }
    }

    function invariant_KEqualsMarketPriceSum() public view {
        uint256 totalMarketPrice = 0;

        // Calculate the sum of instantaneousMarketPrice for all registered apps
        for (uint256 i = 0; i < registeredApps.length; i++) {
            totalMarketPrice += v.instantaneousMarketPrice(registeredApps[i]);
        }

        assertApproxEqAbs(K * 1e18, totalMarketPrice, 10_000);
    }

    function invariant_MaxLossNeverExceedsExpected() public view {
        if (registeredApps.length < 12) {
            return;
        }
        uint256 totalAntPaid = v.totalAntPaid();
        uint256 leadersVotes = getTotalVotesCastForLeaderboard();
        uint256 maxLoss = 50_000 ether;

        assertGt(totalAntPaid + maxLoss, leadersVotes);
    }

    function getTotalVotesCastForLeaderboard() public view returns (uint256) {
        IPhase1Voting.Vote[] memory leaderboard = v.getLeaderboard();

        uint256 totalVotesForLeaders;

        for (uint256 i = 0; i < 12; i++) {
            totalVotesForLeaders += leaderboard[i].votes;
        }

        return totalVotesForLeaders;
    }
}
