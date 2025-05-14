// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/src/console.sol";
import "./Helper.sol";
import "../src/AppRegistry.sol";
import "../src/Phase2Voting.sol";
import "./DummyToken.sol";

contract Phase2VotingInvariantTest is Helper {
    using Math for uint256;

    AppRegistry public appRegistry;
    Phase2Voting public v;
    DummyToken public ant;

    bytes32[] public registeredApps;

    uint256 initialShares = 100 * 1e18;
    uint256 finalShares = 50 * 1e18;
    uint256 p = 5 * 1e17; // 0.5

    uint256 numUsers = 19;

    function setUp() public {
        vm.pauseGasMetering();
        vm.startPrank(dev);
        appRegistry = new AppRegistry(dev);
        ant = new DummyToken("Token", "T");
        v = new Phase2Voting(2, appRegistry, ant, initialShares, finalShares, p);

        ant.approve(address(v), type(uint256).max);
        v.increaseTotalRewardPool(1_500_000 ether);

        registerRandomApps(34);

        targetContract(address(this));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = this.lockRandom.selector;
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
        for (uint256 i = 0; i < count; i++) {
            uint256 userIndex =
                uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, count, i))) % numUsers;
            address controller = users[userIndex];

            string memory name = string(abi.encodePacked("App", vm.toString(registeredApps.length + 1)));
            string memory description = string(abi.encodePacked("Description", vm.toString(registeredApps.length + 1)));
            string memory uri = string(abi.encodePacked("uri", vm.toString(registeredApps.length + 1)));

            bytes32 newAppId = appRegistry.registerApp(controller, name, description, uri);
            registeredApps.push(newAppId);
        }
    }

    function setRandomAppsLive(uint256 count) public {
        if (registeredApps.length == 0) return;

        for (uint256 i = 0; i < count; i++) {
            uint256 appIdIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, count, i)))
                % registeredApps.length;
            bytes32 appId = registeredApps[appIdIndex];

            vm.prank(dev);
            appRegistry.setAppLive(appId, true);
        }
    }

    function lockRandom(uint256 random1, uint256 random2) public {
        if (registeredApps.length == 0) return;

        vm.assume(random1 < 10000);
        vm.assume(random2 < 10000);
        uint256 appIdIndex =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, random1))) % registeredApps.length;
        uint256 userIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, random1))) % numUsers;

        bytes32 appId = registeredApps[appIdIndex];

        address user = users[userIndex];

        uint256 antAmount =
            (uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, appIdIndex))) % 100_000 + 1) * 1e18;

        if (v.getUserLocksLength(user) > 10) {
            return;
        }
        vm.startPrank(user);
        ant.mint(antAmount);
        ant.approve(address(v), antAmount);
        v.lockTokens(appId, antAmount);
    }

    function invariant_UserSharesAlwaysEqualTotalPoolShares() public {
        if (registeredApps.length == 0) return;

        setRandomAppsLive(5);

        uint256 totalSharesCount;

        for (uint256 i = 0; i < numUsers; i++) {
            // go through all users and calculate the user share count
            uint256 userShareCount;

            uint256 userLocksLength = v.getUserLocksLength(users[i]);

            for (uint256 j = 0; j < userLocksLength; j++) {
                (, bytes32 selectedApp,, uint256 shares,) = v.userLocks(users[i], j);

                if (v.appAddedToTotalPoolShares(selectedApp)) {
                    userShareCount += shares;
                }
            }

            totalSharesCount += userShareCount;
        }

        // assert that they all add up to the total pool shares
        uint256 totalPoolShares = v.totalPoolShares();
        assertEq(totalSharesCount, totalPoolShares);
    }
}
