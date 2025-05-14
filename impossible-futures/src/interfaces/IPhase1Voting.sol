// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPhase1Voting {
    error ZeroAddress();
    error VotingNotActive();
    error InvalidAppId();
    error BCantBeZero();
    error KCantBeZero();
    error InvalidMaxMultiplier();
    error InvalidVotingStartTime();

    error MinimumOneVoteRequired();

    error ZeroUserCostNotAllowed();

    event Voted(address indexed user, bytes32 indexed appId, uint256 indexed votes);

    event SetVotingActive(bool indexed isVotingActive);

    event SetAntBeneficiary(address indexed antBeneficiary);

    event SetB(uint256 indexed b);

    /**
     * @dev Struct used to store votes made by users for apps
     *
     * @param appId The ID of the app to which the vote was placed
     * @param votes The amount of votes placed
     */
    struct Vote {
        bytes32 appId;
        uint256 votes;
    }

    /**
     * @dev Votes on a given app
     *
     * @param appId The ID of the app for which the user votes
     * @param newVotes The amount of votes to purchase. Expressed in wei with 18 decimals.
     */
    function vote(bytes32 appId, uint256 newVotes) external;

    /**
     * @dev Returns the leaderboard: all the apps with their app IDs and received votes, in descending order
     */
    function getLeaderboard() external view returns (Vote[] memory);

    /**
     * @dev Returns all the votes placed by a given user 
     *
     * @param user The address of the user.
     *
     * @return The complete votes array for the user.
     */
    function getUserVotes(address user) external view returns (Vote[] memory);

    /**
     * @dev Returns the length of the votes array that contains the votes placed by the user
     *
     * @param user The address of the user.
     *
     * @return The length of the votes array for the user
     */
    function getUserVotesLength(address user) external view returns (uint256);

    /**
     * @dev Returns the total amount of votes placed by a user on all apps combined
     *
     * @param user The address of the user.
     *
     * @return userTotalVotes The total votes bought by the user.
     */
    function getUserTotalVotes(address user) external view returns (uint256 userTotalVotes);

    /**
     * @dev Sets the address to which the ANT paid for votes is sent.
     *
     * @param _antBeneficiary The address of the ANT beneficiary
     */
    function setAntBeneficiary(address _antBeneficiary) external;
}