// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/console.sol";
import "./Helper.sol";
import {DummyToken} from "./DummyToken.sol";
import {FoundationEmissions} from "../src/FoundationEmissions.sol";

contract FoundationEmissionsTest is Helper {
    // 234 159 378,4 ether to deposit
    DummyToken public ant;
    FoundationEmissions public emissions;

    uint256 public constant VESTING_START_TIMESTAMP = 1739282400;
    uint256 public constant BASE_VESTING_PERIOD = 365 days;

    uint256 eightPercentClaim = 23_415_937.84 ether;
    uint256 tenPercentClaim = 29_269_922.3 ether; //29269922.3
    uint256 fourPercentClaim = 11_707_969 ether;
    uint256 threePercentClaim = 8_780_976.69 ether;
    uint256 twoPercentClaim = 5_853_984.46 ether;
    uint256 onePercentClaim = 2_926_992.23 ether;
    uint256 pointFivePercentClaim = 1_463_496.115 ether;
    uint256 point25PercentClaim = 731_748 ether;
    uint256 pointTwoPercentClaim = 585_398.4 ether;

    function setUp() public {
        ant = new DummyToken("Autonomi", "ANT");

        emissions = new FoundationEmissions(ant, dev);

        ant.transfer(address(emissions), 234_159_378.4 ether);

        vm.warp(VESTING_START_TIMESTAMP);
    }

    function test_claim() public {
        // warp 1 year to future
        vm.startPrank(dev);

        // verify that if claimed in 0th year, claimable amount is 0
        uint256 balanceBeforeStart = ant.balanceOf(dev);
        assertEq(emissions.getClaimable(), 0);

        emissions.claim();
        
        uint256 claimedZeroYear = ant.balanceOf(dev) - balanceBeforeStart;
        assertEq(claimedZeroYear, 0);

        // verify amounts for the rest of the years
        vm.warp(block.timestamp + BASE_VESTING_PERIOD);

        for (uint256 i = 1; i < 50; i++) {
            vm.warp(VESTING_START_TIMESTAMP + (BASE_VESTING_PERIOD * i));
            uint256 balanceBefore = ant.balanceOf(dev);
            uint256 amountClaimable = emissions.getClaimable();

            emissions.claim();
            uint256 balanceAfter = ant.balanceOf(dev);

            uint256 claimed = balanceAfter - balanceBefore;

            assertEq(claimed, amountClaimable);

            if (i == 1 || i == 2 || i == 3 || i == 5 || i == 6) {
                assertEq(claimed, eightPercentClaim);
            } else if (i == 4) {
                assertEq(claimed, tenPercentClaim);
            } else if (i == 7) {
                assertApproxEqAbs(claimed, fourPercentClaim, 0.1 ether);
            } else if (i == 8 || i == 9 || i == 10) {
                assertEq(claimed, threePercentClaim);
            } else if (i == 11) {
                assertEq(claimed, twoPercentClaim);
            } else if (i == 12 || i == 13 || i == 14 || i == 15) {
                assertEq(claimed, onePercentClaim);
            } else if (i > 15 && i < 28) {
                assertEq(claimed, pointFivePercentClaim);
            } else if (i >= 28 && i < 40) {
                assertApproxEqAbs(claimed, point25PercentClaim, 0.1 ether);
            } else if (i >= 40) {
                assertApproxEqAbs(claimed, pointTwoPercentClaim, 0.1 ether);
            }
        }

        vm.stopPrank();
    }
}
