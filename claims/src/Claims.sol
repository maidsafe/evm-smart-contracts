// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IClaims} from "./IClaims.sol";
import {IAutonomiNFT} from "./IAutonomiNFT.sol";

contract Claims is IClaims, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddressNotAllowed();
    error ZeroAmountNotAllowed();

    // Tue Feb 11 2025 14:00:00 GMT+0000 - when ANT trading went live
    uint256 public constant VESTING_START_TIMESTAMP = 1739282400;

    uint256 public constant VESTING_PERIOD_1 = 90 days; // 3 months
    uint256 public constant VESTING_PERIOD_2 = 180 days; // 6 months

    mapping(uint256 => uint256) public totalAntClaimedForTokenId;

    IERC20 public immutable ANT_TOKEN;
    IAutonomiNFT public immutable AUTONOMI_NFT;

    constructor(IERC20 antToken, IAutonomiNFT autonomiNFT) {
        if (address(antToken) == address(0) || address(autonomiNFT) == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        ANT_TOKEN = antToken;
        AUTONOMI_NFT = autonomiNFT;
    }

    /**
     * @dev The total claimable amount is unlocked during a period of 6 months,
     * with the 50% unlocked after 3 months, and the rest after 6 months.
     * Autonomi NFT holders can claim any amount less than or equal to the unlocked amount, minus the amount they already claimed.
     *
     * The amount claimed should never be more than the total allocation to that NFT.
     * NFT holders should be able to claim all their allocated ANT tokens after the 6 month vesting periods have passed.
     */
    function claim(uint256 tokenId, uint256 amount) external nonReentrant {
        if (AUTONOMI_NFT.ownerOf(tokenId) != msg.sender) {
            revert Unauthorized();
        }

        if (amount == 0) {
            revert ZeroAmountNotAllowed();
        }

        uint256 claimableAmount = _claimable(tokenId);

        // Check that it input amount is lesser or equal than claimable Amount
        if (amount > claimableAmount) {
            revert TryingToClaimTooMuch();
        }

        // add the amount to the total Ant claimed for token ID
        totalAntClaimedForTokenId[tokenId] += amount;

        // transfer the tokens
        ANT_TOKEN.safeTransfer(msg.sender, amount);

        emit TokensClaimed(tokenId, amount);
    }

    function getClaimable(uint256 tokenId) external view returns (uint256) {
        return _claimable(tokenId);
    }

    function _claimable(uint256 tokenId) private view returns (uint256) {
        uint256 totalAllocation = AUTONOMI_NFT.tokenIdToAntAllocation(tokenId);

        uint256 alreadyClaimed = totalAntClaimedForTokenId[tokenId];

        uint256 elapsedTime = block.timestamp - VESTING_START_TIMESTAMP;
        uint256 claimableAmount = 0;

        if (elapsedTime >= VESTING_PERIOD_2) {
            claimableAmount = totalAllocation - alreadyClaimed;
        } else if (elapsedTime >= VESTING_PERIOD_1) {
            claimableAmount = (totalAllocation * 50) / 100 - alreadyClaimed;
        }

        return claimableAmount;
    }
}
