// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/src/console.sol";
import "./Helper.sol";
import "../src/AppRegistry.sol";
import "../src/Phase2Voting.sol";
import "./DummyToken.sol";

contract Phase2VotingTest is Helper {
    using Math for uint256;

    AppRegistry public appRegistry;
    Phase2Voting public v;
    DummyToken public ant;

    bytes32 public appId1;
    bytes32 public appId2;
    bytes32 public appId3;
    bytes32 public appId4;

    bytes32[] public registeredApps;

    uint256 initialShares = 100 * 1e18;
    uint256 finalShares = 50 * 1e18;
    uint256 p = 5 * 1e17; // 0.5

    function setUp() public {
        vm.startPrank(dev);

        appRegistry = new AppRegistry(dev);
        ant = new DummyToken("Token", "T");

        v = new Phase2Voting(2, appRegistry, ant, initialShares, finalShares, p);

        ant.approve(address(v), type(uint256).max);
        vm.stopPrank();
    }

    function test_constructor_args() public {
        vm.startPrank(dev);

        vm.expectRevert(IPhase2Voting.InvalidStartTime.selector);
        v = new Phase2Voting(0, appRegistry, ant, initialShares, finalShares, p);

        vm.expectRevert(IPhase2Voting.InvalidAddress.selector);
        v = new Phase2Voting(2, AppRegistry(address(0)), ant, initialShares, finalShares, p);

        vm.expectRevert(IPhase2Voting.InvalidAddress.selector);
        v = new Phase2Voting(2, appRegistry, IERC20(address(0)), initialShares, finalShares, p);

        vm.expectRevert(IPhase2Voting.InvalidAmounts.selector);
        v = new Phase2Voting(2, appRegistry, ant, 0, finalShares, p);

        vm.expectRevert(IPhase2Voting.InvalidAmounts.selector);
        v = new Phase2Voting(2, appRegistry, ant, initialShares, 0, p);

        vm.expectRevert(IPhase2Voting.InvalidAmounts.selector);
        v = new Phase2Voting(2, appRegistry, ant, initialShares, finalShares, 0);

        vm.stopPrank();
    }

    /* 
       ====================================== 
       ============= lockTokens =============
       ======================================
    */
    function test_lockTokens() public {
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);
        appRegistry.setAppIsInPhase2(appId2, true);
        appRegistry.setAppIsInPhase2(appId3, true);
        appRegistry.setAppIsInPhase2(appId4, true);

        vm.warp(block.timestamp + 1);

        // right at the beginning of the campaign, shares should be 100
        vm.expectEmit(true, true, true, false);
        emit IPhase2Voting.LockedTokens(appId1, 1 ether, dev);
        v.lockTokens(appId1, 1 ether);

        uint256 antBalanceAfter = ant.balanceOf(address(v));
        assertEq(1 ether, antBalanceAfter);

        IPhase2Voting.Lock[] memory userLocks = v.getUserLocks(dev);
        uint256 userLocksLength = v.getUserLocksLength(dev);
        assertEq(userLocksLength, 1);

        assertEq(userLocks[0].locker, dev);
        assertEq(userLocks[0].antAmount, 1 ether);
        assertEq(userLocks[0].shares, 100e18);
        assertFalse(userLocks[0].unlocked);

        assertEq(v.totalUserShares(dev), 100e18);
        assertEq(v.sharesPerApp(appId1), 100e18);
        assertEq(v.antPerApp(appId1), 1 ether);

        vm.stopPrank();
    }

    function test_cannot_lockTokens_InvalidAppId() public {
        _registerApps();
        vm.startPrank(dev);

        vm.expectRevert(IPhase2Voting.InvalidAppId.selector);
        v.lockTokens(bytes32(0), 1 ether);

        vm.expectRevert(IPhase2Voting.InvalidAppId.selector);
        v.lockTokens(appId1, 1 ether);

        vm.stopPrank();
    }

    function test_cannot_lockTokens_campaignNotActive() public {
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);

        vm.expectRevert(IPhase2Voting.CampaignNotActive.selector);
        v.lockTokens(appId1, 1 ether);

        vm.warp(v.START_TIME() + v.CAMPAIGN_DURATION() + 1);
        vm.expectRevert(IPhase2Voting.CampaignNotActive.selector);
        v.lockTokens(appId1, 1 ether);

        vm.stopPrank();
    }

    function test_cannot_lockTokens_missingApproval() public {
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);
        appRegistry.setAppIsInPhase2(appId2, true);
        appRegistry.setAppIsInPhase2(appId3, true);
        appRegistry.setAppIsInPhase2(appId4, true);

        ant.transfer(users[1], 10 ether);

        vm.warp(block.timestamp + 1);

        vm.stopPrank();

        vm.prank(users[1]);
        vm.expectRevert();
        v.lockTokens(appId1, 10 ether);
    }

    function test_cannot_lockTokens_notEnoughAnt() public {
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);
        appRegistry.setAppIsInPhase2(appId2, true);
        appRegistry.setAppIsInPhase2(appId3, true);
        appRegistry.setAppIsInPhase2(appId4, true);

        ant.transfer(users[1], 10 ether);

        vm.warp(block.timestamp + 1);

        vm.stopPrank();

        vm.startPrank(users[1]);
        ant.approve(address(v), 10 ether);
        vm.expectRevert();
        v.lockTokens(appId1, 100 ether);

        vm.stopPrank();
    }

    /* 
       ====================================== 
       ============ unlockTokens ============
       ======================================
    */
    function test_unlockTokens() public {
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);
        appRegistry.setAppIsInPhase2(appId2, true);
        appRegistry.setAppIsInPhase2(appId3, true);
        appRegistry.setAppIsInPhase2(appId4, true);

        vm.warp(block.timestamp + 1);

        v.lockTokens(appId1, 1 ether);

        vm.warp(v.START_TIME() + v.UNLOCK_TIME() + 1);

        uint256 userBalanceBefore = ant.balanceOf(dev);

        vm.expectEmit(true, true, false, false);
        emit IPhase2Voting.UnlockedTokens(dev, 0);
        v.unlockTokens(0);

        assertEq(ant.balanceOf(dev) - userBalanceBefore, 1 ether);

        uint256 vBalanceAfter = ant.balanceOf(address(v));
        assertEq(vBalanceAfter, 0);

        IPhase2Voting.Lock[] memory userLocks = v.getUserLocks(dev);

        assertTrue(userLocks[0].unlocked);

        vm.stopPrank();
    }

    function test_cannot_unlockTokens_onlyAfterUnlockTime() public {
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);

        vm.warp(block.timestamp + 1);

        v.lockTokens(appId1, 1 ether);

        vm.expectRevert(IPhase2Voting.LockPeriodNotOver.selector);
        v.unlockTokens(0);

        vm.stopPrank();
    }

    function test_cannot_unlockTokens_invalidLockIndex() public {
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);

        vm.warp(block.timestamp + 1);

        v.lockTokens(appId1, 1 ether);

        vm.warp(v.START_TIME() + v.UNLOCK_TIME() + 1);

        vm.expectRevert(IPhase2Voting.InvalidLockIndex.selector);
        v.unlockTokens(2);

        vm.stopPrank();
    }

    function test_cannot_unlockTokens_alreadyUnlocked() public {
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);

        vm.warp(block.timestamp + 1);

        v.lockTokens(appId1, 1 ether);

        vm.warp(v.START_TIME() + v.UNLOCK_TIME() + 1);

        v.unlockTokens(0);

        vm.expectRevert(IPhase2Voting.AlreadyUnlocked.selector);
        v.unlockTokens(0);

        vm.stopPrank();
    }

    /* 
       ====================================== 
       ====== increaseTotalRewardPool =======
       ======================================
    */
    function test_increaseTotalRewardPool() public {
        _registerApps();
        vm.startPrank(dev);

        vm.expectEmit(true, false, false, false);
        emit IPhase2Voting.IncreasedTotalRewardPool(1_500_000 ether);

        v.increaseTotalRewardPool(1_500_000 ether);
        assertEq(ant.balanceOf(address(v)), 1_500_000 ether);

        assertEq(v.totalRewardPool(), 1_500_000 ether);
        vm.stopPrank();
    }

    function test_cannot_increaseTotalRewardPool_missingApproval() public {
        _registerApps();
        vm.prank(dev);
        ant.transfer(users[1], 100 ether);

        vm.prank(users[1]);
        vm.expectRevert();
        v.increaseTotalRewardPool(100 ether);
    }

    function test_cannot_increaseTotalRewardPool_notEnoughAnt() public {
        _registerApps();
        vm.prank(dev);
        ant.transfer(users[1], 100 ether);

        vm.prank(users[1]);
        ant.approve(address(v), 100 ether);

        vm.prank(users[1]);
        vm.expectRevert();
        v.increaseTotalRewardPool(1000 ether);
    }

    /* 
       ====================================== 
       ======= updateTotalPoolShares ========
       ======================================
    */
    function test_updateTotalPoolShares() public {
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);
        appRegistry.setAppIsInPhase2(appId2, true);
        appRegistry.setAppIsInPhase2(appId3, true);
        appRegistry.setAppIsInPhase2(appId4, true);

        uint256 finalPoolAmount;
        vm.warp(v.START_TIME() + 1);
        finalPoolAmount += v.calculateShares(1 ether);
        v.lockTokens(appId1, 1 ether);

        vm.warp(v.START_TIME() + 1 weeks);
        finalPoolAmount += v.calculateShares(1 ether);
        v.lockTokens(appId2, 1 ether);

        vm.warp(v.START_TIME() + 2 weeks);
        finalPoolAmount += v.calculateShares(1 ether);
        v.lockTokens(appId3, 1 ether);

        vm.warp(v.START_TIME() + 3 weeks);
        finalPoolAmount += v.calculateShares(1 ether);
        v.lockTokens(appId4, 1 ether);

        v.updateTotalPoolShares(registeredApps);
        assertEq(v.totalPoolShares(), 0);

        appRegistry.setAppLive(appId1, true);
        appRegistry.setAppLive(appId2, true);
        appRegistry.setAppLive(appId3, true);
        appRegistry.setAppLive(appId4, true);

        v.updateTotalPoolShares(registeredApps);
        uint256 totalPoolShares = v.totalPoolShares();
        assertEq(finalPoolAmount, totalPoolShares);

        v.updateTotalPoolShares(registeredApps);
        totalPoolShares = v.totalPoolShares();
        assertEq(finalPoolAmount, totalPoolShares);
    }

    function test_cannot_updateTotalPoolShares_onlyBeforeUnlockTime() public {
        vm.startPrank(dev);
        vm.warp(v.UNLOCK_TIME() + 1);

        vm.expectRevert(IPhase2Voting.OnlyBeforeUnlockTime.selector);
        v.updateTotalPoolShares(registeredApps);
        vm.stopPrank();
    }

    /* 
       ====================================== 
       ============ claimRewards ============
       ======================================
    */
    function test_claimRewards() public {
        // do a vote to each project from a different address
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);
        appRegistry.setAppIsInPhase2(appId2, true);
        appRegistry.setAppIsInPhase2(appId3, true);
        appRegistry.setAppIsInPhase2(appId4, true);

        appRegistry.setAppLive(appId1, true);
        appRegistry.setAppLive(appId2, true);
        appRegistry.setAppLive(appId3, true);
        appRegistry.setAppLive(appId4, true);

        vm.warp(block.timestamp + 1);

        v.lockTokens(appId1, 1 ether);

        ant.transfer(users[1], 1 ether);
        ant.transfer(users[2], 1 ether);
        ant.transfer(users[3], 1 ether);

        vm.stopPrank();

        vm.startPrank(users[1]);
        ant.approve(address(v), 1 ether);
        v.lockTokens(appId2, 1 ether);
        vm.stopPrank();

        vm.startPrank(users[2]);
        ant.approve(address(v), 1 ether);
        v.lockTokens(appId3, 1 ether);
        vm.stopPrank();

        vm.startPrank(users[3]);
        ant.approve(address(v), 1 ether);
        v.lockTokens(appId4, 1 ether);
        vm.stopPrank();

        // record the reward pool
        vm.prank(dev);
        v.updateTotalPoolShares(registeredApps);

        // fund the pool
        vm.prank(dev);
        v.increaseTotalRewardPool(1_500_000 ether);

        // forward to concluding the voting
        vm.warp(v.UNLOCK_TIME() + 1);

        vm.startPrank(dev);
        uint256 userShareCount = v.totalUserShares(dev);
        uint256 totalRewardPool = v.totalRewardPool();
        uint256 totalPoolShares = v.totalPoolShares();

        uint256 rewardAmount = totalRewardPool.mulDiv(userShareCount, totalPoolShares);

        // claim rewards from pool for each user
        uint256 antBalanceBefore = ant.balanceOf(dev);
        vm.expectEmit(true, true, false, false);
        emit IPhase2Voting.ClaimedRewards(dev, rewardAmount);
        v.claimRewards();
        uint256 antBalanceAfter = ant.balanceOf(dev);
        assertEq(antBalanceAfter - antBalanceBefore, rewardAmount);

        vm.stopPrank();

        vm.startPrank(users[1]);
        userShareCount = v.totalUserShares(users[1]);

        rewardAmount = totalRewardPool.mulDiv(userShareCount, totalPoolShares);

        antBalanceBefore = ant.balanceOf(users[1]);
        vm.expectEmit(true, true, false, false);
        emit IPhase2Voting.ClaimedRewards(users[1], rewardAmount);
        v.claimRewards();
        antBalanceAfter = ant.balanceOf(users[1]);
        assertEq(antBalanceAfter - antBalanceBefore, rewardAmount);

        vm.stopPrank();

        vm.startPrank(users[2]);
        userShareCount = v.totalUserShares(users[2]);

        rewardAmount = totalRewardPool.mulDiv(userShareCount, totalPoolShares);

        // claim rewards from pool for each user
        antBalanceBefore = ant.balanceOf(users[2]);
        vm.expectEmit(true, true, false, false);
        emit IPhase2Voting.ClaimedRewards(users[2], rewardAmount);
        v.claimRewards();
        antBalanceAfter = ant.balanceOf(users[2]);
        assertEq(antBalanceAfter - antBalanceBefore, rewardAmount);

        vm.stopPrank();

        vm.startPrank(users[3]);
        userShareCount = v.totalUserShares(users[3]);

        rewardAmount = totalRewardPool.mulDiv(userShareCount, totalPoolShares);

        // claim rewards from pool for each user
        antBalanceBefore = ant.balanceOf(users[3]);
        vm.expectEmit(true, true, false, false);
        emit IPhase2Voting.ClaimedRewards(users[3], rewardAmount);
        v.claimRewards();
        antBalanceAfter = ant.balanceOf(users[3]);
        assertEq(antBalanceAfter - antBalanceBefore, rewardAmount);

        vm.stopPrank();
    }

    function test_claimRewards_OnlyForLiveApps() public {
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);
        appRegistry.setAppIsInPhase2(appId2, true);
        appRegistry.setAppIsInPhase2(appId3, true);
        appRegistry.setAppIsInPhase2(appId4, true);

        appRegistry.setAppLive(appId1, true);
        appRegistry.setAppLive(appId2, true);

        vm.warp(block.timestamp + 1);

        v.lockTokens(appId1, 1 ether);

        ant.transfer(users[1], 1 ether);
        ant.transfer(users[2], 1 ether);
        ant.transfer(users[3], 1 ether);

        vm.stopPrank();

        vm.startPrank(users[1]);
        ant.approve(address(v), 1 ether);
        v.lockTokens(appId2, 1 ether);
        vm.stopPrank();

        vm.startPrank(users[2]);
        ant.approve(address(v), 1 ether);
        v.lockTokens(appId3, 1 ether);
        vm.stopPrank();

        vm.startPrank(users[3]);
        ant.approve(address(v), 1 ether);
        v.lockTokens(appId4, 1 ether);
        vm.stopPrank();

        // record the reward pool
        vm.prank(dev);
        v.updateTotalPoolShares(registeredApps);

        // fund the pool
        vm.prank(dev);
        v.increaseTotalRewardPool(1_500_000 ether);

        // forward to concluding the voting
        vm.warp(v.UNLOCK_TIME() + 1);

        vm.startPrank(dev);
        uint256 userShareCount = v.totalUserShares(dev);
        uint256 totalRewardPool = v.totalRewardPool();
        uint256 totalPoolShares = v.totalPoolShares();

        uint256 rewardAmount = totalRewardPool.mulDiv(userShareCount, totalPoolShares);

        // claim rewards from pool for each user
        uint256 antBalanceBefore = ant.balanceOf(dev);
        vm.expectEmit(true, true, false, false);
        emit IPhase2Voting.ClaimedRewards(dev, rewardAmount);
        v.claimRewards();
        uint256 antBalanceAfter = ant.balanceOf(dev);
        assertEq(antBalanceAfter - antBalanceBefore, rewardAmount);

        vm.stopPrank();

        vm.startPrank(users[2]);
        userShareCount = v.totalUserShares(users[2]);
        assertGt(userShareCount, 0);

        antBalanceBefore = ant.balanceOf(users[2]);
        v.claimRewards();
        antBalanceAfter = ant.balanceOf(users[2]);
        assertEq(antBalanceBefore, antBalanceAfter);
        vm.stopPrank();
    }

    function test_cannot_claimRewards_lockPeriodNotOver() public {
        // do a vote to each project from a different address
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);

        appRegistry.setAppLive(appId1, true);

        vm.warp(block.timestamp + 1);

        v.lockTokens(appId1, 1 ether);

        v.updateTotalPoolShares(registeredApps);

        v.increaseTotalRewardPool(1_500_000 ether);

        vm.expectRevert(IPhase2Voting.LockPeriodNotOver.selector);
        v.claimRewards();
        vm.stopPrank();
    }

    function test_cannot_claimRewards_alreadyClaimed() public {
        // do a vote to each project from a different address
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);

        appRegistry.setAppLive(appId1, true);

        vm.warp(block.timestamp + 1);

        v.lockTokens(appId1, 1 ether);

        // record the reward pool
        v.updateTotalPoolShares(registeredApps);

        // fund the pool
        v.increaseTotalRewardPool(1_500_000 ether);

        // forward to concluding the voting
        vm.warp(v.UNLOCK_TIME() + 1);

        v.claimRewards();

        vm.expectRevert(IPhase2Voting.RewardsAlreadyClaimed.selector);
        v.claimRewards();
    }

    function test_cannot_claimRewards_zeroShares() public {
        // do a vote to each project from a different address
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);

        appRegistry.setAppLive(appId1, true);

        vm.warp(block.timestamp + 1);

        v.lockTokens(appId1, 1 ether);

        // record the reward pool
        v.updateTotalPoolShares(registeredApps);

        // fund the pool
        v.increaseTotalRewardPool(1_500_000 ether);
        vm.stopPrank();

        // forward to concluding the voting
        vm.warp(v.UNLOCK_TIME() + 1);

        vm.prank(users[1]);
        v.claimRewards();

        assertFalse(v.rewardsClaimed(users[1]));

        assertEq(ant.balanceOf(address(v)), 1_500_001 ether);
        assertEq(ant.balanceOf(users[1]), 0);
    }

    /* 
       ====================================== 
       =========== calculateRate ============
       ======================================
    */
    function test_calculateRate() public {
        _registerApps();
        vm.startPrank(dev);

        appRegistry.setAppIsInPhase2(appId1, true);
        appRegistry.setAppIsInPhase2(appId2, true);
        appRegistry.setAppIsInPhase2(appId3, true);
        appRegistry.setAppIsInPhase2(appId4, true);

        vm.warp(block.timestamp + 1);

        uint256 currentRate = v.calculateRate();
        assertEq(currentRate, 100 ether);

        vm.warp(v.START_TIME() + 0.685 weeks);
        currentRate = v.calculateRate();
        assertApproxEqAbs(currentRate, 75 ether, 0.1 ether);

        vm.warp(v.START_TIME() + 4 weeks);
        currentRate = v.calculateRate();

        assertEq(currentRate, 50 ether);

        vm.stopPrank();
    }

    function _registerApps() private {
        // 1. register 4 apps
        vm.startPrank(dev);
        appId1 = appRegistry.registerApp(dev, "Test app 1", "This is test app no. 1", "https://autonomi.com");
        appId2 = appRegistry.registerApp(dev, "Test app 2", "This is test app no. 2", "https://autonomi.com");
        appId3 = appRegistry.registerApp(dev, "Test app 3", "This is test app no. 3", "https://autonomi.com");
        appId4 = appRegistry.registerApp(dev, "Test app 4", "This is test app no. 4", "https://autonomi.com");

        registeredApps.push(appId1);
        registeredApps.push(appId2);
        registeredApps.push(appId3);
        registeredApps.push(appId4);
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
}
