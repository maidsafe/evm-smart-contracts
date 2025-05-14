// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";
import {SD59x18, sd} from "@prb/math/src/SD59x18.sol";

import {IAppRegistry} from "./interfaces/IAppRegistry.sol";
import {IPhase1Voting} from "./interfaces/IPhase1Voting.sol";

contract Phase1Voting is IPhase1Voting, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_VOTE_AMOUNT = 1 ether;

    uint256 public immutable K;

    IERC20 public immutable ANT;

    IAppRegistry public immutable APP_REGISTRY;

    uint256 public b;

    address public antBeneficiary;

    uint256 public constant VOTING_DURATION = 1 weeks;
    uint256 public immutable VOTING_START_TIME;

    uint256 public immutable maxMultiplier;

    uint256 public totalAntPaid;

    mapping(bytes32 => uint256) public votesForApp;

    mapping(address => Vote[]) public userVotes;

    modifier onlyVotingActive() {
        if (block.timestamp < VOTING_START_TIME || block.timestamp > VOTING_START_TIME + VOTING_DURATION) {
            revert VotingNotActive();
        }
        _;
    }

    modifier onlyRegisteredApp(bytes32 appId) {
        // verify that the app ID is valid
        if (!APP_REGISTRY.isRegisteredApp(appId)) {
            revert InvalidAppId();
        }
        _;
    }

    constructor(
        uint256 _b,
        uint256 k,
        IAppRegistry appRegistry,
        IERC20 ant,
        address _antBeneficiary,
        uint256 _votingStartTime,
        uint256 _maxMultiplier
    ) Ownable(msg.sender) {
        if (_b == 0) {
            revert BCantBeZero();
        }

        if (k == 0) {
            revert KCantBeZero();
        }

        if (address(appRegistry) == address(0) || address(ant) == address(0) || address(_antBeneficiary) == address(0))
        {
            revert ZeroAddress();
        }

        if (_maxMultiplier < 1e18) {
            revert InvalidMaxMultiplier();
        }

        if (_votingStartTime < block.timestamp) {
            revert InvalidVotingStartTime();
        }

        b = _b;
        K = k;
        APP_REGISTRY = appRegistry;
        antBeneficiary = _antBeneficiary;
        ANT = ant;
        VOTING_START_TIME = _votingStartTime;
        maxMultiplier = _maxMultiplier;
    }

    /**
     * @dev See IPhase1Voting - vote
     */
    function vote(bytes32 appId, uint256 newVotes) external onlyVotingActive onlyRegisteredApp(appId) {
        // verify that user can't buy less than the minimum votes required
        if (newVotes < MIN_VOTE_AMOUNT) {
            revert MinimumOneVoteRequired();
        }

        uint256 _userCost = userCost(appId, newVotes);

        if (_userCost == 0) {
            revert ZeroUserCostNotAllowed();
        }

        // transfer the ANT from user to beneficiary
        ANT.safeTransferFrom(msg.sender, antBeneficiary, _userCost);

        // add the votes to the app
        votesForApp[appId] += newVotes;

        // add the votes to the user
        userVotes[msg.sender].push(Vote({appId: appId, votes: newVotes}));

        totalAntPaid += _userCost;

        emit Voted(msg.sender, appId, newVotes);
    }

    /**
     * @dev See IPhase1Voting - getLeaderboard
     */
    function getLeaderboard() external view returns (Vote[] memory) {
        bytes32[] memory apps = APP_REGISTRY.getAppIds();
        Vote[] memory leaderboard = new Vote[](apps.length);

        for (uint256 i = 0; i < apps.length; i++) {
            leaderboard[i] = Vote({appId: apps[i], votes: votesForApp[apps[i]]});
        }

        // Sort the array using bubble sort
        for (uint256 i = 0; i < leaderboard.length - 1; i++) {
            for (uint256 j = 0; j < leaderboard.length - i - 1; j++) {
                if (leaderboard[j].votes < leaderboard[j + 1].votes) {
                    // Swap positions
                    Vote memory temp = leaderboard[j];
                    leaderboard[j] = leaderboard[j + 1];
                    leaderboard[j + 1] = temp;
                }
            }
        }
        return leaderboard;
    }

    /**
     * @dev See IPhase1Voting - getUserVotes
     */
    function getUserVotes(address user) external view returns (Vote[] memory) {
        return userVotes[user];
    }

    /**
     * @dev See IPhase1Voting - getUserVotesLength
     */
    function getUserVotesLength(address user) external view returns (uint256) {
        return userVotes[user].length;
    }

    /**
     * @dev See IPhase1Voting - getUserTotalVotes
     */
    function getUserTotalVotes(address user) external view returns (uint256 userTotalVotes) {
        Vote[] memory _votes = userVotes[user];

        uint256 _votesLength = userVotes[user].length;

        for (uint256 i = 0; i < _votesLength; i++) {
            userTotalVotes += _votes[i].votes;
        }
    }

    /**
     * @dev Calculate the instantaneous market price for a specific app ID
     * @param targetAppId The specific app ID to get the price for
     * @return The price for the targeted app ID as a fixed-point number (scaled by 1e18)
     */
    function instantaneousMarketPrice(bytes32 targetAppId)
        public
        view
        onlyRegisteredApp(targetAppId)
        returns (uint256)
    {
        bytes32[] memory appIds = APP_REGISTRY.getAppIds();

        // 1. calculate qi over b for the given app id
        uint256 qi = votesForApp[targetAppId];
        UD60x18 qiFixed = UD60x18.wrap(qi);
        UD60x18 bFixed = UD60x18.wrap(b); // Convert b to UD60x18
        UD60x18 qiOverB = qiFixed.div(bFixed);

        // 2. calculate C(q)
        uint256 cq = c(appIds, bytes32(""), 0);

        // 3. calculate C(q) / b
        UD60x18 cqFixed = UD60x18.wrap(cq);
        UD60x18 cqOverB = cqFixed.div(bFixed);

        // 4. convert 1 and 3 into signed values
        SD59x18 qiOverBSigned = qiOverB.intoSD59x18();
        SD59x18 cqOverBSigned = cqOverB.intoSD59x18();

        // 5. substract 3 from 1
        SD59x18 subResult = qiOverBSigned.sub(cqOverBSigned);
        SD59x18 expSubResult = subResult.exp();

        SD59x18 kScaledSigned = SD59x18.wrap(int256(K * 1e18));

        // 6. multiply exp of substraction result by K
        SD59x18 marketPriceSigned = kScaledSigned.mul(expSubResult);

        return uint256(marketPriceSigned.unwrap());
    }

    // For this we need an app ID the user is voting for
    // Further we need the amount of votes the user is buying
    // first we calculate q_old with the current state
    // we multiply with time multiplier
    // then we add the num votes to the new input
    // Calculates : K * (q_new - q_old) * timeMultiplier()
    function userCost(bytes32 selectedAppId, uint256 newVotes) public view returns (uint256) {
        bytes32[] memory appIds = APP_REGISTRY.getAppIds();

        uint256 qOld = c(appIds, bytes32(""), 0);

        uint256 qNew = c(appIds, selectedAppId, newVotes);

        uint256 costDifference = qNew - qOld;

        uint256 finalUserCost = K * Math.mulDiv(costDifference, timeMultiplier(), 1e18);

        return finalUserCost;
    }

    /**
     * @dev calculates TimeMultiplier(t) = 1 + (M - 1) × (t/T)^2
     * where: t is the time since voting started, T is the total voting duration,
     * M is the maximum cost multiplier
     *
     * Applies a time decay to voting power.
     * The purpose for this is to make it negative ROI to wait till the very end of voting,
     * and cast a large number of votes very cheaply to a project with little to no votes.
     */
    function timeMultiplier() public view returns (uint256) {
        uint256 scale = 1e18;
        uint256 minTimePoint = 0.9 ether;

        uint256 t = block.timestamp - VOTING_START_TIME;

        uint256 T = VOTING_DURATION;

        uint256 normalizedTime = Math.mulDiv(t, scale, T);

        if (normalizedTime < minTimePoint) {
            return scale;
        }

        uint256 timeFactor = Math.mulDiv(normalizedTime, normalizedTime, scale);

        uint256 multiplierDelta = maxMultiplier - scale;

        uint256 timeComponent = Math.mulDiv(multiplierDelta, timeFactor, scale);

        return scale + timeComponent;
    }

    /**
     * @dev Calculate the cost function C(q) = b * ln(sum(exp(qi/b)))
     * @param appIds Array of application IDs to include in the calculation
     * @return The cost function result as a fixed-point number (scaled by 1e18)
     */
    function c(bytes32[] memory appIds, bytes32 selectedAppId, uint256 newVotes) public view returns (uint256) {
        uint256 appIdsLength = appIds.length;

        SD59x18 sum = SD59x18.wrap(0); // Start with 0

        UD60x18 bFixed = UD60x18.wrap(b); // Convert b to UD60x18

        UD60x18 maxVal = UD60x18.wrap(0);
        for (uint256 i = 0; i < appIdsLength; i++) {
            uint256 qi = votesForApp[appIds[i]];
            if (appIds[i] == selectedAppId) {
                qi += newVotes;
            }
            UD60x18 qiFixed = UD60x18.wrap(qi);
            UD60x18 qiOverB = qiFixed.div(bFixed);
            if (qiOverB.gt(maxVal)) {
                maxVal = qiOverB;
            }
        }

        SD59x18 maxValSigned = maxVal.intoSD59x18();
        for (uint256 i = 0; i < appIdsLength; i++) {
            // Get votes for this app (already scaled by 1e18)
            uint256 qi = votesForApp[appIds[i]];
            if (appIds[i] == selectedAppId) {
                qi += newVotes;
            }

            // Calculate qi/b properly with fixed-point division
            SD59x18 qiOverBSubMaxVal = UD60x18.wrap(qi).div(bFixed).intoSD59x18().sub(maxValSigned);

            // Calculate exp(qi/b) and add to sum
            sum = sum.add(qiOverBSubMaxVal.exp());
        }

        // Calculate b * ln(sum)
        UD60x18 result = bFixed.mul(maxValSigned.add(sum.ln()).intoUD60x18());

        // Convert back to uint256 (still scaled by 1e18)
        return UD60x18.unwrap(result);
    }

    /**
     * @dev See IPhase1Voting - setAntBeneficiary
     */
    function setAntBeneficiary(address _antBeneficiary) external onlyOwner {
        if (_antBeneficiary == address(0)) {
            revert ZeroAddress();
        }

        antBeneficiary = _antBeneficiary;

        emit SetAntBeneficiary(antBeneficiary);
    }

    function setB(uint256 _b) external onlyOwner {
        if (_b == 0) {
            revert BCantBeZero();
        }

        b = _b;

        emit SetB(_b);
    }
}
