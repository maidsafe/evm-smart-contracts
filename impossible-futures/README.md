# Impossible Futures Smart Contracts

## Table of Contents
[Phase1Voting](#phase1voting-contract)
1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Technical Details](#technical-details)
4. [Constants and State Variables](#constants-and-state-variables)
5. [Core Functions](#core-functions)
6. [View Functions](#view-functions)
7. [Admin Functions](#admin-functions)
8. [Mechanism Explanations](#mechanism-explanations)
9. [Usage](#usage)
10. [Events](#events)
11. [Error Conditions](#error-conditions)

[Phase2Voting](#phase2voting-contract)
1. [Overview](#overview-phase2)
2. [Key Concepts](#key-concepts)
3. [Contract Architecture](#contract-architecture)
4. [Detailed Functionality](#detailed-functionality)
   - [Token Locking Mechanism](#token-locking-mechanism)
   - [Reward Distribution System](#reward-distribution-system)
   - [Token Unlocking](#token-unlocking)
5. [Security Considerations](#security-considerations)
6. [Events](#events)
7. [Usage Examples](#usage-examples)
8. [Mathematical Foundation](#mathematical-foundation)

## Phase1Voting Contract

### Overview

The Phase1Voting contract implements a mechanism for application voting using the Logarithmic Market Scoring Rule (LMSR). This system allows users to vote for registered applications by spending ANT tokens, with the cost of votes increasing as more votes are cast for the same application. The contract includes a time-based multiplier to discourage last-minute voting.

The whole project from the user's point of view is described here: https://impossible-futures.com

### Key Features

- LMSR-based pricing mechanism for votes
- Time multiplier to prevent late voting exploitation
- Leaderboard functionality to track top applications
- User vote tracking and history
- Owner-configurable parameters

### Technical Details

#### Constants and State Variables

- `MIN_VOTE_AMOUNT`: Minimum amount of votes (1 ether)
- `K`: Multiplier used in the LMSR formula (immutable)
- `ANT`: Token used for voting (immutable)
- `APP_REGISTRY`: Registry contract for valid applications (immutable)
- `b`: Parameter that controls the shape of the cost curve
- `antBeneficiary`: Address where voting fees are sent
- `isVotingActive`: Flag to enable/disable voting
- `VOTING_DURATION`: Fixed voting period (1 week)
- `VOTING_START_TIME`: Timestamp when voting begins (immutable)
- `maxMultiplier`: Maximum time multiplier for late voting

#### Core Functions

##### Vote

```solidity
function vote(bytes32 appId, uint256 newVotes) external onlyVotingActive
```

Allows users to vote for an application by transferring ANT tokens. The cost is calculated based on the current state of votes and a time multiplier.

##### User Cost Calculation

```solidity
function userCost(bytes32 selectedAppId, uint256 newVotes) public view returns (uint256)
```

Calculates the cost in ANT tokens for a user to cast a specific number of votes for an application.

##### Time Multiplier

```solidity
function timeMultiplier() public view returns (uint256)
```

Implements a quadratic time decay function that increases the cost of voting as the voting period progresses, with the formula:
`TimeMultiplier(t) = 1 + (M - 1) × (t/T)^2`
where:

- t is the time since voting started
- T is the total voting duration
- M is the maximum cost multiplier

##### Market Price

```solidity
function instantaneousMarketPrice(bytes32 targetAppId) public view returns (uint256)
```

Calculates the current market price for voting on a specific application.

##### Cost Function

```solidity
function c(bytes32[] memory appIds, bytes32 selectedAppId, uint256 newVotes) public view returns (uint256)
```

Implements the LMSR cost function: `C(q) = b * ln(sum(exp(qi/b)))`.

#### View Functions

##### Get Leaderboard

```solidity
function getLeaderboard() external view returns (Vote[] memory)
```

Returns a sorted array of applications by vote count, from highest to lowest.

##### User Votes

```solidity
function getUserVotes(address user) external view returns (Vote[] memory)
```

Returns all votes cast by a specific user.

##### User Vote Count

```solidity
function getUserVotesLength(address user) external view returns (uint256)
```

Returns the number of votes cast by a specific user.

##### User Total Votes

```solidity
function getUserTotalVotes(address user) external view returns (uint256)
```

Returns the total number of votes cast by a specific user across all applications.

#### Admin Functions

##### Set Voting Active

```solidity
function setVotingActive(bool _isVotingActive) external onlyOwner
```

Enables or disables voting functionality.

##### Set ANT Beneficiary

```solidity
function setAntBeneficiary(address _antBeneficiary) external onlyOwner
```

Updates the address that receives ANT tokens from voting.

##### Set B Parameter

```solidity
function setB(uint256 _b) external onlyOwner
```

Updates the `b` parameter used in the LMSR cost function.

### LMSR Mechanism Explained

The Logarithmic Market Scoring Rule (LMSR) is a pricing mechanism that:

1. Makes early votes cheaper than later votes for the same application
2. Ensures that the marginal cost of votes increases as more votes are cast
3. Provides a balanced funding mechanism that rewards widespread support

The cost function `C(q)` calculates the total cost to achieve the current vote distribution. When a user adds votes, they pay the difference between the new state and the old state: `C(q_new) - C(q_old)`.

### Time Multiplier Mechanism

The time multiplier feature increases voting costs as the voting period progresses:

- At the start of voting, the multiplier is 1.0
- The multiplier remains at 1.0 for the first 90% of the voting period
- In the final 10% of the voting period, the multiplier increases quadratically up to `maxMultiplier`

This prevents users from waiting until the end of the voting period to cast votes at artificially low prices.

### Usage

To use this contract:

1. Deploy with appropriate parameters:

   - `_b`: Initial value for the LMSR curve parameter
   - `k`: Multiplier for the cost function
   - `appRegistry`: Address of the application registry contract
   - `ant`: Address of the ANT token contract
   - `_antBeneficiary`: Address to receive ANT tokens from voting
   - `_votingStartTime`: Unix timestamp when voting begins
   - `_maxMultiplier`: Maximum time multiplier value

2. Approve the ANT token contract to spend tokens on behalf of voters

3. Cast votes using the `vote` function

### Events

- `Voted(address indexed user, bytes32 indexed appId, uint256 votes)`: Emitted when a user votes
- `SetVotingActive(bool active)`: Emitted when voting is enabled or disabled
- `SetAntBeneficiary(address beneficiary)`: Emitted when the beneficiary address is updated
- `SetB(uint256 b)`: Emitted when the `b` parameter is updated

### Error Conditions

- `VotingNotActive`: Voting is currently disabled
- `BCantBeZero`: The `b` parameter cannot be zero
- `KCantBeZero`: The `K` parameter cannot be zero
- `ZeroAddress`: Address parameters cannot be zero
- `InvalidAppId`: The application ID must be registered in APP_REGISTRY
- `MinimumOneVoteRequired`: Votes must be at least MIN_VOTE_AMOUNT
- `ZeroUserCostNotAllowed`: Vote cost cannot be zero

## Phase2Voting Contract

### Overview (Phase2)

This is Solidity smart contract system where users can lock their ANT tokens for 12 months during a 4 week period against a given set of apps. The amount of shares they receive for locking their ANT tokens depends on when they lock the tokens - there is an exponential time decay function, so the later they lock the less shares they receive. Users then receive rewards based on whether the app they locked against goes "live". They can unlock their ANT tokens after 12 months.

Key features:

1. **Time-Decayed Shares**: The number of shares users receive for locking tokens decreases exponentially over the campaign period
2. **Long-Term Commitment**: Tokens are locked for 1 year and 1 day (366 days)
3. **Reward Distribution**: Users earn rewards based on whether the apps they supported go "live" in the ecosystem

### Key Concepts

#### Shares System

- Shares represent voting power and reward eligibility
- Shares are calculated based on:
  - Amount of ANT locked
  - Time when tokens are locked (earlier lockers get more shares)
- Shares follow an exponential decay formula over the 4-week campaign period

#### Reward Mechanism

- A reward pool of ANT tokens is distributed to users who locked tokens against apps that eventually went "live"
- Reward distribution is proportional to the user's share of the total qualifying shares

#### Time Periods

1. **Campaign Duration**: 4 weeks (when users can lock tokens)
2. **Lock Duration**: 1 year and 1 day (366 days) after campaign ends
3. **Unlock Time**: After the full lock duration has passed

### Contract Architecture

#### Key Components

1. **State Variables**:

   - `APP_REGISTRY`: Interface to the application registry
   - `ANT`: ANT token interface
   - Time-related constants (`CAMPAIGN_DURATION`, `LOCK_DURATION`)
   - Share calculation parameters (`INITIAL_SHARES`, `FINAL_SHARES`, `p`)
   - Reward pool tracking (`totalRewardPool`)
   - User and app tracking mappings

2. **Core Functions**:

   - `lockTokens()`: Users lock ANT tokens against specific apps
   - `unlockTokens()`: Users retrieve their locked ANT after the lock period
   - `claimRewards()`: Users claim their share of the reward pool
   - `updateTotalPoolShares()`: Updates the reward pool with qualifying apps

3. **Mathematical Functions**:
   - `calculateRate()`: Computes the current share rate based on time decay
   - `calculateShares()`: Calculates shares for a given ANT amount

### Detailed Functionality

#### Token Locking Mechanism

1. **Locking Process**:

   - Users call `lockTokens()` during the 4-week campaign
   - Specify an app ID and ANT amount to lock
   - Contract calculates shares based on current time
   - ANT tokens are transferred to the contract
   - Lock record is created

2. **Share Calculation**:
   - Uses exponential decay formula: `initial * exp((t/duration)^p * ln(final/initial))`
   - Where:
     - `t` = time elapsed since campaign start
     - `p` = decay rate parameter
     - `initial` = initial share rate (highest)
     - `final` = final share rate (lowest)

#### Reward Distribution System

1. **Reward Pool**:

   - ANT tokens are added via `increaseTotalRewardPool()`
   - Only apps marked as "live" in the registry qualify for rewards
   - `updateTotalPoolShares()` adds qualifying apps to the reward pool

2. **Claiming Rewards**:
   - After unlock time, users can claim rewards
   - Rewards are proportional to: `(user_shares / total_qualifying_shares) * total_reward_pool`
   - Each user can only claim once

#### Token Unlocking

- After the 1-year and 1 day lock period, users can call `unlockTokens()`
- Specifies which lock to unlock (users may have multiple)
- Original ANT amount is returned
- Lock is marked as unlocked to prevent duplicate withdrawals

### Security Considerations

1. **Time-Based Restrictions**:

   - `lockTokens()` only works during the 4-week campaign
   - `unlockTokens()` and `claimRewards()` only work after lock period
   - `updateTotalPoolShares()` only works before unlock time

2. **Input Validation**:

   - Validates app IDs are registered and in phase 2
   - Checks for zero amounts and invalid addresses
   - Prevents duplicate reward claims

3. **State Management**:
   - Uses OpenZeppelin's SafeERC20 for secure token transfers
   - Tracks unlocked status to prevent reentrancy issues

### Events

- `LockedTokens`: Emitted when tokens are locked
- `UnlockedTokens`: Emitted when tokens are unlocked
- `IncreasedTotalRewardPool`: When reward pool is increased
- `UpdatedTotalPoolShares`: When qualifying apps are added to reward pool
- `ClaimedRewards`: When users claim their rewards

### Usage Examples

#### Locking Tokens

```solidity
// During campaign period (May 14 - June 11)
phase2Voting.lockTokens(appId, 1000 ether);
```

#### Adding to Reward Pool

```solidity
// Before unlock time
phase2Voting.increaseTotalRewardPool(100000 ether);
phase2Voting.updateTotalPoolShares([appId1, appId2]);
```

#### Claiming Rewards

```solidity
// After May 15 of next year
phase2Voting.claimRewards();
phase2Voting.unlockTokens(0); // Unlock first lock
```

### Mathematical Foundation

The share calculation uses an exponential decay model:

```
shares = antAmount * (initialShares * exp((t/duration)^p * ln(finalShares/initialShares))) / 1e18
```

Where:

- `t` = time since campaign start
- `duration` = 4 weeks (campaign duration)
- `p` = decay rate parameter
- `initialShares` = maximum shares (at t=0)
- `finalShares` = minimum shares (at t=duration)

This ensures:

- Early participants get more shares per ANT
- The decay rate is controlled by parameter `p`
- Smooth transition from initial to final share rate
