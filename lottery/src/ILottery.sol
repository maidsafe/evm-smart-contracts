// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ILottery {
    event NewParticipant(address indexed participant, uint256 timestamp);
    event DrawStarted(uint256 indexed requestId);

    enum SelectionType {
        OG,
        DAILY
    }

    // Whitelist an uploader address
    function whitelistUploader(address _uploader) external;

    // Called by the payment vault in payForQuotes
    // Checks that the uploader address is whitelisted
    // Registers the entrant if it hasn't been registered yet
    function newEntrant(address _uploader, address _entrant) external;

    // Checks if one day has passed since last call
    // Then draws the winners for both lotteries
    function drawWinners() external;

    // Owner can withdraw the ANT
    function withdraw(uint256 amount) external;
}
