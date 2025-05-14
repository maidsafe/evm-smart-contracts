// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* 
- the goal of this contract is to hold ANT tokens, and then unlock them periodically to NFT holders
- the total allocation is specified in the NFT so the contract will have to read that:
function tokenIdToAntAllocation(uint256) external view returns (uint256)

then the claimable amounts are as follows:
50% of claimable amount unlocked after 3 months
next 50% of claimable amount unlocked after 6 months
 */
interface IClaims {
    error Unauthorized();
    error TryingToClaimTooMuch();

    event TokensClaimed(uint256 indexed tokenId, uint256 indexed amount);

    function claim(uint256 tokenId, uint256 amount) external;
}
