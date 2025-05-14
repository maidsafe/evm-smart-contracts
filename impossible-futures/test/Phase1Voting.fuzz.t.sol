// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/src/console.sol";

import "./Helper.sol";
import "../src/AppRegistry.sol";
import "../src/Phase1Voting.sol";
import "./DummyToken.sol";

contract Phase1VotingFuzzTest is Helper {
    AppRegistry public appRegistry;
    Phase1Voting public v;
    DummyToken public ant;

    uint256 public K = 12;

    bytes32[] public registeredApps;

    function setUp() public {
        vm.startPrank(dev);

        appRegistry = new AppRegistry(dev);
        ant = new DummyToken("Token", "T");
        v = new Phase1Voting(3000 ether, K, appRegistry, ant, dev, 1, 2e18);

        ant.approve(address(v), type(uint256).max);

        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function test_userCost_AlwaysGtZero(uint256 votesCount) public {
        votesCount = bound(votesCount, 1, 100);

        vm.pauseGasMetering();

        vm.startPrank(dev);

        uint256 appsCount = 65;

        v.setAntBeneficiary(users[5]);

        for (uint256 i = 0; i < appsCount; i++) {
            string memory name = string(abi.encodePacked("App", vm.toString(registeredApps.length + 1)));
            string memory description = string(abi.encodePacked("Description", vm.toString(registeredApps.length + 1)));
            string memory uri = string(abi.encodePacked("uri", vm.toString(registeredApps.length + 1)));

            bytes32 newAppId = appRegistry.registerApp(users[2], name, description, uri);
            registeredApps.push(newAppId);
        }

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
}
