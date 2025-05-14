// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPhase2Voting} from "./interfaces/IPhase2Voting.sol";
import {IAppRegistry} from "./interfaces/IAppRegistry.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";
import {SD59x18, sd} from "@prb/math/src/SD59x18.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Phase2Voting is IPhase2Voting, Ownable {
    using Math for uint256;
    using SafeERC20 for IERC20;

    /// @dev Address of the app registry contract
    IAppRegistry public immutable APP_REGISTRY;
    /// @dev Address of ANT token
    IERC20 public immutable ANT;

    /// @dev constant variables: campaign and lock durations
    uint256 public constant CAMPAIGN_DURATION = 4 weeks;
    // lock duration is 1 year and 1 day - needs to be so for tax reasons to make it a long term capital gain
    uint256 public constant LOCK_DURATION = 366 days;

    /// @dev start time will be May 14
    uint256 public immutable START_TIME;
    /// @dev unlock time is START_TIME + LOCK_DURATION
    uint256 public immutable UNLOCK_TIME;

    /// @dev the initial amount of shares receivable at the beginning
    uint256 public immutable INITIAL_SHARES;
    /// @dev the final amount of shares close to the end
    uint256 public immutable FINAL_SHARES;

    /// @dev The total amount of ANT in the reward pool
    /// will be distributed to users who voted on apps that went live
    uint256 public totalRewardPool;

    /// @dev the exponential decay rate
    uint256 p;

    /// @dev ln(FINAL_SHARES / INITIAL_SHARES) - part of the shares calculation
    SD59x18 ratioLn;

    /// @dev All ANT locks that were made by a user are tracked here
    mapping(address => Lock[]) public userLocks;
    /// @dev The total shares earned by each user are tracked here
    mapping(address => uint256) public totalUserShares;

    /// @dev The total shares locked for each app are tracked here
    mapping(bytes32 => uint256) public sharesPerApp;
    /// @dev The total ANT used per app to buy shares to lock against them
    mapping(bytes32 => uint256) public antPerApp;

    /// @dev Tracks whether a user already claimed the rewards
    mapping(address => bool) public rewardsClaimed;

    /// @dev This is the total shares that are for apps that are set to live in the app registry
    /// used for rewards calculation
    uint256 public totalPoolShares;
    /// @dev each app that is live in the app registry can only be added once to the total pool
    mapping(bytes32 => bool) public appAddedToTotalPoolShares;

    /// @dev check that the lock period is over
    modifier onlyAfterUnlockTime() {
        if (block.timestamp < UNLOCK_TIME) {
            revert LockPeriodNotOver();
        }
        _;
    }

    constructor(
        uint256 startTime,
        IAppRegistry appRegistry,
        IERC20 antToken,
        uint256 initialShares,
        uint256 finalShares,
        uint256 _p
    ) Ownable(msg.sender) {
        // verify that start time is in the future
        if (startTime < block.timestamp) {
            revert InvalidStartTime();
        }

        // verify registry and ant addresses
        if (address(appRegistry) == address(0) || address(antToken) == address(0)) {
            revert InvalidAddress();
        }

        // verify initial and final shares
        if (initialShares == 0 || finalShares == 0 || finalShares > initialShares) {
            revert InvalidAmounts();
        }

        // verify p
        if (_p == 0) {
            revert InvalidAmounts();
        }

        // set start time
        START_TIME = startTime;

        // unlock time set based on start time
        UNLOCK_TIME = START_TIME + LOCK_DURATION;

        // app registry
        APP_REGISTRY = appRegistry;
        // ant token
        ANT = antToken;

        // set p
        p = _p;

        // set shares
        INITIAL_SHARES = initialShares;
        FINAL_SHARES = finalShares;

        SD59x18 initialSharesUD = SD59x18.wrap(int256(initialShares));
        SD59x18 finalSharesUD = SD59x18.wrap(int256(finalShares));
        // set the ln ratio
        ratioLn = finalSharesUD.div(initialSharesUD).ln();
    }

    /**
     * @dev See IPhase2Voting - lockTokens
     */
    function lockTokens(bytes32 appId, uint256 antAmount) external {
        // check that the app is registered & in phase 2
        if (!APP_REGISTRY.isRegisteredApp(appId) || !APP_REGISTRY.isInPhase2(appId)) {
            revert InvalidAppId();
        }

        // check that campaign is active
        if (block.timestamp < START_TIME || block.timestamp > START_TIME + CAMPAIGN_DURATION) {
            revert CampaignNotActive();
        }

        // calculate the shares receivable
        uint256 shares = calculateShares(antAmount);

        // transfer the ant amount
        ANT.safeTransferFrom(msg.sender, address(this), antAmount);

        // update state
        sharesPerApp[appId] += shares;
        antPerApp[appId] += antAmount;
        userLocks[msg.sender].push(
            Lock({locker: msg.sender, selectedApp: appId, antAmount: antAmount, shares: shares, unlocked: false})
        );
        totalUserShares[msg.sender] += shares;

        // emit event
        emit LockedTokens(appId, antAmount, msg.sender);
    }

    /**
     * @dev See IPhase2Voting - unlockTokens
     */
    function unlockTokens(uint256 lockIndex) external onlyAfterUnlockTime {
        // check that user locks length >= lock index
        if (userLocks[msg.sender].length <= lockIndex) {
            revert InvalidLockIndex();
        }

        // get lock at index
        Lock memory lock = userLocks[msg.sender][lockIndex];

        // check that it is not unlocked already
        if (lock.unlocked) {
            revert AlreadyUnlocked();
        }

        // update the lock to unlocked
        userLocks[msg.sender][lockIndex].unlocked = true;

        // transfer the ANT to the user
        ANT.safeTransfer(msg.sender, lock.antAmount);

        // emit event
        emit UnlockedTokens(msg.sender, lockIndex);
    }

    /**
     * @dev Increases the reward pool by adding ANT
     *
     * @param antAmount The amount of ANT to add
     */
    function increaseTotalRewardPool(uint256 antAmount) external {
        ANT.safeTransferFrom(msg.sender, address(this), antAmount);
        totalRewardPool += antAmount;

        emit IncreasedTotalRewardPool(antAmount);
    }

    /**
     * @dev Updates the total pool shares -
     * it checks if the given app IDs are live, and if they haven't been added yet
     * if that's the case it increases the total reward pool and marks the app as added to the pool
     *
     * @param appIds The list of apps to handle
     */
    function updateTotalPoolShares(bytes32[] memory appIds) external onlyOwner {
        if (block.timestamp > UNLOCK_TIME) {
            revert OnlyBeforeUnlockTime();
        }

        for (uint256 i = 0; i < appIds.length; i++) {
            bytes32 appId = appIds[i];
            if (!APP_REGISTRY.isLive(appId)) {
                continue;
            }
            if (appAddedToTotalPoolShares[appId]) {
                continue;
            }
            appAddedToTotalPoolShares[appId] = true;
            uint256 appShares = sharesPerApp[appId];
            totalPoolShares += appShares;
        }

        emit UpdatedTotalPoolShares(appIds);
    }

    /**
     * @dev See IPhase2Voting - claimRewards
     */
    function claimRewards() external onlyAfterUnlockTime {
        // check that user has not claimed rewards already
        if (rewardsClaimed[msg.sender]) {
            revert RewardsAlreadyClaimed();
        }

        // get the user's shares for apps that went live
        uint256 userShareCount;
        Lock[] memory locks = userLocks[msg.sender];
        for (uint256 i = 0; i < locks.length; i++) {
            if (appAddedToTotalPoolShares[locks[i].selectedApp]) {
                userShareCount += locks[i].shares;
            }
        }
        if (userShareCount == 0) {
            return;
        }

        // calculate the reward amount
        uint256 rewardAmount = totalRewardPool.mulDiv(userShareCount, totalPoolShares);

        // update user rewards claimed to true
        rewardsClaimed[msg.sender] = true;

        // transfer rewards
        ANT.safeTransfer(msg.sender, rewardAmount);

        // emit event
        emit ClaimedRewards(msg.sender, rewardAmount);
    }

    /**
     * @dev calculates the rate for shares at a given point
     * the time decay formula is: initial * exp((t/duration)^p * ln(final/initial))
     */
    function calculateRate() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - START_TIME;
        uint256 timeRatio = timeElapsed.mulDiv(1e18, CAMPAIGN_DURATION);

        UD60x18 timeRatioUD = UD60x18.wrap(timeRatio);
        UD60x18 pUD = UD60x18.wrap(p);

        // exp((t/duration)^p * ln(final/initial))
        UD60x18 poweredTimeRatio = timeRatioUD.pow(pUD);
        SD59x18 expFactor = poweredTimeRatio.intoSD59x18().mul(ratioLn).exp();

        UD60x18 initialUD = UD60x18.wrap(INITIAL_SHARES);

        UD60x18 resultUD = initialUD.mul(expFactor.intoUD60x18());

        return resultUD.unwrap();
    }

    /**
     * @dev See IPhase2Voting - calculateShares
     */
    function calculateShares(uint256 antAmount) public view returns (uint256) {
        uint256 shareRate = calculateRate();

        return antAmount.mulDiv(shareRate, 1e18);
    }

    /**
     * @dev Returns all of the user's token locks
     *
     * @param user the address of the user
     */
    function getUserLocks(address user) external view returns (Lock[] memory) {
        return userLocks[user];
    }

    /**
     * @dev Returns the number of a user's token locks
     *
     * @param user the address of the user
     */
    function getUserLocksLength(address user) external view returns (uint256) {
        return userLocks[user].length;
    }
}
