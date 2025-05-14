// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/console.sol";
import "./Helper.sol";
import {IClaims, Claims} from "../src/Claims.sol";
import {IAutonomiNFT} from "../src/IAutonomiNFT.sol";
import {AutonomiNFT} from "../src/AutonomiNFT.sol";
import {DummyToken} from "./DummyToken.sol";

contract ClaimsTest is Helper {
    IAutonomiNFT public autonomiNFT = IAutonomiNFT(0x71dB7B18cFd0a4804fE564ea6AcDEE25847f4965);

    DummyToken public ant;

    Claims public claims;

    uint256 public START_TIMESTAMP = 1739282400;

    uint256 ThreeMonthsInFuture = START_TIMESTAMP + 90 days;
    uint256 SixMonthsInFuture = START_TIMESTAMP + 180 days;

    function setUp() public {
        forkArbitrumSepolia();
        selectArbSepolia();
        vm.warp(START_TIMESTAMP);

        ant = new DummyToken("Autonomi", "ANT");

        claims = new Claims(ant, autonomiNFT);

        ant.transfer(address(claims), 1_200_000_000 ether);
    }

    function test_claim() public {
        uint256 tokenAlloc1 = 52911097099932500000000;
        assertEq(tokenAlloc1, autonomiNFT.tokenIdToAntAllocation(1));

        vm.startPrank(autonomiNFT.ownerOf(1));

        // check that claimable is 0
        uint256 claimable = claims.getClaimable(1);
        assertEq(claimable, 0);

        // ========================================================
        // warp 90 days, claim, check that 25% was claimed
        vm.warp(ThreeMonthsInFuture);
        claimable = claims.getClaimable(1);
        assertEq((tokenAlloc1 * 50) / 100, claimable);

        vm.expectEmit(true, true, false, false);
        emit IClaims.TokensClaimed(1, claimable);
        claims.claim(1, claimable);

        uint256 userBalance = ant.balanceOf(autonomiNFT.ownerOf(1));

        assertEq(userBalance, claimable);
        claimable = claims.getClaimable(1);

        assertEq(claimable, 0);

        // ========================================================
        // warp 180 days, claim, check that 50% was claimed
        vm.warp(SixMonthsInFuture);
        claimable = claims.getClaimable(1);

        assertEq((tokenAlloc1 * 50) / 100, claimable);

        uint256 userBalanceBefore = ant.balanceOf(autonomiNFT.ownerOf(1));
        emit IClaims.TokensClaimed(1, claimable);

        claims.claim(1, claimable);

        userBalance = ant.balanceOf(autonomiNFT.ownerOf(1));

        assertEq(userBalance, userBalanceBefore + claimable);
        vm.stopPrank();

        // ========================================================
        // different token ID
        vm.warp(START_TIMESTAMP);

        vm.startPrank(autonomiNFT.ownerOf(2));

        // check that claimable is 0
        claimable = claims.getClaimable(2);
        assertEq(claimable, 0);

        // ========================================================
        // warp 180 days instantly, check that all 50% were claimed
        vm.warp(SixMonthsInFuture);
        claimable = claims.getClaimable(2);
        tokenAlloc1 = autonomiNFT.tokenIdToAntAllocation(2);
        assertEq((tokenAlloc1 * 100) / 100, claimable);

        userBalanceBefore = ant.balanceOf(autonomiNFT.ownerOf(2));

        emit IClaims.TokensClaimed(2, claimable);
        claims.claim(2, claimable);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(2)), userBalanceBefore + claimable);

        vm.stopPrank();
    }

    function test_claim_partial() public {
        // warp 90 days
        vm.startPrank(autonomiNFT.ownerOf(1));
        vm.warp(ThreeMonthsInFuture);

        uint256 claimable = claims.getClaimable(1);

        claims.claim(1, claimable / 2);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(1)), (autonomiNFT.tokenIdToAntAllocation(1) * 50 / 100) / 2);

        claims.claim(1, (claimable / 2) - 100 ether);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(1)), (autonomiNFT.tokenIdToAntAllocation(1) * 50 / 100) - 100 ether);

        claims.claim(1, 100 ether);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(1)), autonomiNFT.tokenIdToAntAllocation(1) * 50 / 100);

        vm.warp(SixMonthsInFuture);
        claimable = claims.getClaimable(1);

        claims.claim(1, 100 ether);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(1)), (autonomiNFT.tokenIdToAntAllocation(1) * 50 / 100) + 100 ether);

        claims.claim(1, 200 ether);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(1)), (autonomiNFT.tokenIdToAntAllocation(1) * 50 / 100) + 300 ether);

        claims.claim(1, claimable - 300 ether);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(1)), autonomiNFT.tokenIdToAntAllocation(1));

        autonomiNFT.transferFrom(autonomiNFT.ownerOf(2), users[1], 2);
        vm.stopPrank();

        vm.warp(ThreeMonthsInFuture);
        vm.startPrank(autonomiNFT.ownerOf(2));

        claims.claim(2, 200 ether);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(2)), 200 ether);

        vm.warp(SixMonthsInFuture);
        claimable = claims.getClaimable(2);
        claims.claim(2, claimable);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(2)), autonomiNFT.tokenIdToAntAllocation(2));
        vm.stopPrank();
    }

    function test_claim_transfer_nft() public {
        // warp 90 days
        vm.startPrank(autonomiNFT.ownerOf(1));
        vm.warp(ThreeMonthsInFuture);

        uint256 claimable = claims.getClaimable(1);

        claims.claim(1, claimable / 2);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(1)), (autonomiNFT.tokenIdToAntAllocation(1) * 50 / 100) / 2);

        autonomiNFT.transferFrom(autonomiNFT.ownerOf(1), users[1], 1);

        vm.stopPrank();

        vm.startPrank(autonomiNFT.ownerOf(1));
        claims.claim(1, claimable / 2);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(1)), (autonomiNFT.tokenIdToAntAllocation(1) * 50 / 100) / 2);

        vm.stopPrank();
    }

    function test_cannot_claim_too_much() public {
        // warp 90 days
        vm.startPrank(autonomiNFT.ownerOf(1));
        vm.warp(ThreeMonthsInFuture);

        uint256 claimable = claims.getClaimable(1);
        claims.claim(1, 100 ether);

        vm.expectRevert(IClaims.TryingToClaimTooMuch.selector);
        claims.claim(1, claimable);
    }

    function test_cannot_double_claim() public {
        // warp 90 days
        vm.startPrank(autonomiNFT.ownerOf(1));
        vm.warp(ThreeMonthsInFuture);

        // claim 50%
        uint256 claimable = claims.getClaimable(1);
        claims.claim(1, claimable);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(1)), autonomiNFT.tokenIdToAntAllocation(1) * 50 / 100);

        claimable = claims.getClaimable(1);
        assertEq(claimable, 0);

        // verify that can't claim again
        vm.expectRevert(IClaims.TryingToClaimTooMuch.selector);
        claims.claim(1, 100 ether);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(1)), autonomiNFT.tokenIdToAntAllocation(1) * 50 / 100);

        // warp 180 days
        vm.warp(SixMonthsInFuture);
        // claim 50%
        claimable = claims.getClaimable(1);
        claims.claim(1, claimable);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(1)), autonomiNFT.tokenIdToAntAllocation(1));

        claimable = claims.getClaimable(1);
        assertEq(claimable, 0);

        // verify that can't claim again
        vm.expectRevert(IClaims.TryingToClaimTooMuch.selector);
        claims.claim(1, 100 ether);
        assertEq(ant.balanceOf(autonomiNFT.ownerOf(1)), autonomiNFT.tokenIdToAntAllocation(1));

        vm.stopPrank();
    }

    function test_cannot_claim_unauthorized() public {
        vm.warp(ThreeMonthsInFuture);
        vm.prank(users[1]);
        vm.expectRevert(IClaims.Unauthorized.selector);
        claims.claim(1, 1 ether);
    }

    function test_mint_after_first_vesting() public {
        vm.warp(SixMonthsInFuture);
        vm.startPrank(AutonomiNFT(address(autonomiNFT)).owner());
        
        AutonomiNFT(address(autonomiNFT)).mint(dev, AutonomiNFT.AntAllocation({tokenId: 471, antAllocation: 50 ether}));
        uint256 claimable = claims.getClaimable(471);
        
        assertEq(claimable, 50 ether);

        vm.stopPrank();
    }
}
