// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

import "./ILottery.sol";

contract LotteryV2 is ILottery, VRFConsumerBaseV2Plus {
    using SafeERC20 for IERC20;

    address public paymentVault;
    IERC20 public antToken;

    uint256 immutable SUBSCRIPTION_ID;
    uint32 constant CALLBACK_GAS_LIMIT = 2_499_999;
    bytes32 constant KEY_HASH = 0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be;

    // Lottery can be paused by owner
    bool isLotteryRunning;

    // Set to true when a chainlink VRF request & winner draw is in progress
    bool drawInProgress;

    uint256 public lastDrawTimestamp;

    // verified uploader addresses
    mapping(address => bool) public whitelistedUploaders;

    // Record if an address is OG - first payment before Jan 06 2025 00:00:00 GMT+0000
    mapping(address => bool) public isOG;

    // Record if an address is a daily participant - to prevent duplicate entries - we clear this mapping after each successful lottery draw
    mapping(bytes32 => bool) public isDailyParticipant;

    // Record daily participants for random daily winner selection - we clear this array after each successful lottery draw
    address[] public dailyParticipants;

    // Record daily OG participants for random daily OG winner selection - we clear this array after each successful lottery draw
    address[] public dailyOGParticipants;

    // We will pick this many daily OG winners
    uint256 dailyOGWinnersCount;

    // We will pick this many daily winners
    uint256 dailyWinnersCount;

    // interval that must pass between lottery draws
    uint256 public constant DRAW_INTERVAL = 1 days;

    // registration cutoff for the early participants lottery
    uint256 OG_CUTOFF_TIMESTAMP = 1736121600; // Mon Jan 06 2025 00:00:00 GMT+0000

    uint256 public dailyOGPrizePool;

    uint256 public dailyPrizePool;

    uint256 ongoingRequestId;

    modifier onlyPaymentVault() {
        if (msg.sender != paymentVault) {
            revert();
        }
        _;
    }

    constructor(address _paymentVault, IERC20 _antToken, address _vrfCoordinator, uint256 _subscriptionId)
        VRFConsumerBaseV2Plus(_vrfCoordinator)
    {
        SUBSCRIPTION_ID = _subscriptionId;

        lastDrawTimestamp = block.timestamp;

        paymentVault = _paymentVault;
        antToken = _antToken;
    }

    function newEntrant(address _uploader, address _entrant) external onlyPaymentVault {
        if (whitelistedUploaders[_uploader] == false) {
            revert();
        }

        // check if user is within OG cutoff
        if (isWithinOGCutoff()) {
            // if true - mark user as OG
            isOG[_entrant] = true;
        }

        bytes32 _entrantKey = keccak256(abi.encode(_entrant, lastDrawTimestamp));
        
        // check if lottery is running
        if (!isLotteryRunning || isDailyParticipant[_entrantKey]) {
            return;
        }

        isDailyParticipant[_entrantKey] = true;
        // if yes - add the user to the list of daily entrants
        dailyParticipants.push(_entrant);

        // if user is OG - add user to the list of daily OG entrants
        if (isOG[_entrant]) {
            dailyOGParticipants.push(_entrant);
        }

        // emit event
        emit NewParticipant(_entrant, block.timestamp);
    }

    function drawWinners() external onlyOwner {
        require(!drawInProgress, "Draw already in progress");
        require(
            dailyOGParticipants.length >= dailyOGWinnersCount && dailyParticipants.length >= dailyWinnersCount,
            "Not enough participants"
        );
        require(block.timestamp >= lastDrawTimestamp + DRAW_INTERVAL, "Too early for next draw");

        drawInProgress = true;

        VRFV2PlusClient.RandomWordsRequest memory _req = VRFV2PlusClient.RandomWordsRequest({
            keyHash: KEY_HASH,
            subId: SUBSCRIPTION_ID,
            requestConfirmations: 3,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            numWords: 2,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}))
        });

        ongoingRequestId = s_vrfCoordinator.requestRandomWords(_req);

        emit DrawStarted(ongoingRequestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        require(requestId == ongoingRequestId, "Wrong request");
        require(drawInProgress, "No draw in progress");

        require(randomWords.length == 2, "Wrong number of words returned");

        address[] memory _ogWinners = _selectWinners(randomWords[0], SelectionType.OG);

        address[] memory _dailyWinners = _selectWinners(randomWords[1], SelectionType.DAILY);

        _payWinners(_ogWinners, SelectionType.OG);

        _payWinners(_dailyWinners, SelectionType.DAILY);

        delete dailyOGParticipants;

        delete dailyParticipants;
    }

    /* 
    - we need to request dailyWinnersCount + dailyOGWinnersCount random numbers
    -  we are using the Fisher-Yates shuffle algorithm 
    - we only need to request 2 random words - 1 for the OG array and 1 for the regular array
     */
    function _selectWinners(uint256 randomNumber, SelectionType selectionType) private returns (address[] memory) {
        uint256 len = selectionType == SelectionType.OG ? dailyOGParticipants.length : dailyParticipants.length;
        uint256 winnersCount = selectionType == SelectionType.OG ? dailyOGWinnersCount : dailyWinnersCount;

        // Select winners using Fisher-Yates shuffle with the random number as seed
        address[] memory winners = new address[](winnersCount);

        uint256[] memory indices = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            indices[i] = i;
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < winnersCount; i++) {
            // Use the random number to generate a new random index
            uint256 remainingCount = len - i;
            uint256 randomIndex = i + uint256(keccak256(abi.encode(randomNumber, i))) % remainingCount;

            // Swap the current position with the randomly selected position
            uint256 temp = indices[i];
            indices[i] = indices[randomIndex];
            indices[randomIndex] = temp;

            // Select the winner
            winners[i] =
                selectionType == SelectionType.OG ? dailyOGParticipants[indices[i]] : dailyParticipants[indices[i]];

            unchecked {
                ++i;
            }
        }

        drawInProgress = false;

        return winners;
    }

    function _payWinners(address[] memory winners, SelectionType selectionType) private {
        uint256 winnersCount = winners.length;

        uint256 prizePool = selectionType == SelectionType.OG ? dailyOGPrizePool : dailyPrizePool;
        
        uint256 prizePerWinner = prizePool / winnersCount;

        for (uint256 i = 0; i < winnersCount; i++) {
            antToken.safeTransfer(winners[i], prizePerWinner);
        }
    }

    function whitelistUploader(address _uploader) external onlyOwner {
        whitelistedUploaders[_uploader] = true;
    }

    function removeUploaderFromWhitelist(address _uploader) external onlyOwner {
        whitelistedUploaders[_uploader] = false;
    }

    function startLottery() external onlyOwner {
        isLotteryRunning = true;
    }

    function pauseLottery() external onlyOwner {
        isLotteryRunning = false;
    }

    function setDailyOGPrizePool(uint256 _dailyOGPrizePool) external onlyOwner {
        dailyOGPrizePool = _dailyOGPrizePool;
    }

    function setDailyPrizePool(uint256 _dailyPrizePool) external onlyOwner {
        dailyPrizePool = _dailyPrizePool;
    }

    function setDailyWinnersCount(uint256 _dailyWinnersCount) external onlyOwner {
        dailyWinnersCount = _dailyWinnersCount;
    }

    function setDailyOGWinnersCount(uint256 _dailyOGWinnersCount) external onlyOwner {
        dailyOGWinnersCount = _dailyOGWinnersCount;
    }

    function isWithinOGCutoff() internal view returns (bool) {
        return block.timestamp < OG_CUTOFF_TIMESTAMP;
    }

    function withdraw(uint256 amount) external onlyOwner {
        antToken.safeTransfer(owner(), amount);
    }
}
