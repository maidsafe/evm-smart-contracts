// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPhase2Voting {
    /**
     * @dev Represents an ANT token lock
     *
     * @param locker the user who locked the ANT
     * @param selectedApp the app that the user locked against
     * @param antAmount the amount of ANT that was locked
     * @param shares the shares received for locking the ANT
     * @param unlocked whether the ANT has been unlocked
     */
    struct Lock {
        address locker;
        bytes32 selectedApp;
        uint256 antAmount;
        uint256 shares;
        bool unlocked;
    }

    error InvalidStartTime();
    error InvalidAddress();
    error InvalidAmounts();

    error InvalidAppId();
    error CampaignNotActive();
    error LockPeriodNotOver();
    error InvalidLockIndex();
    error AlreadyUnlocked();

    error OnlyBeforeUnlockTime();

    event LockedTokens(bytes32 indexed appId, uint256 indexed antAmount, address indexed user);
    event UnlockedTokens(address indexed user, uint256 indexed lockIndex);

    error RewardsAlreadyClaimed();

    event IncreasedTotalRewardPool(uint256 indexed antAmount);

    event UpdatedTotalPoolShares(bytes32[] indexed appIds);

    event ClaimedRewards(address indexed user, uint256 indexed rewardAmount);

    /**
     * @dev Locks a given amount of tokens or a given app ID
     *
     * @param appId the app ID to lock the tokens for
     * @param antAmount the amount of ANT tokens to lock
     */
    function lockTokens(bytes32 appId, uint256 antAmount) external;

    /**
     * @dev Unlocks the tokens that were locked at a specific lock index
     *
     * @param lockIndex The index of the lock in the userLocks array
     */
    function unlockTokens(uint256 lockIndex) external;

    /**
     * @dev Claims the rewards earned by the user 
     * user gets rewards pro rata from the reward pool for each app he voted on that went live
     */
    function claimRewards() external;

    /**
     * @dev Calculates the shares receivable for a given ANT amount
     *
     * @param antAmount The amount of ANT to pay for shares
     */
    function calculateShares(uint256 antAmount) external view returns (uint256);
}
