// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Airdrop is Ownable {
    using SafeERC20 for IERC20;

    struct AirdropRecipient {
        address recipient;
        uint256 amount;
    }

    error EmptyRecipientsArray();
    error InvalidRecipient(uint256 idx);
    error InvalidAmount();

    // Event to log successful airdrops
    event BatchAirdropCompleted(AirdropRecipient[] indexed recipients);
    event UniformAirdropCompleted( address[] recipients, uint256 amountEach);

    IERC20 public antToken;

    constructor(IERC20 _antToken) Ownable(msg.sender) {
        antToken = _antToken;
    }

    /**
     * @notice Performs batch transfer of tokens to multiple addresses
     * @param recipients Array of recipient addresses and amounts
     */
    function batchAirdrop(AirdropRecipient[] calldata recipients) external onlyOwner {
        if (recipients.length == 0) {
            revert EmptyRecipientsArray();
        }

        for (uint256 i = 0; i < recipients.length; ++i) {
            if (recipients[i].recipient == address(0)) {
                revert InvalidRecipient(i);
            }
            antToken.safeTransfer(recipients[i].recipient, recipients[i].amount);
        }

        emit BatchAirdropCompleted(recipients);
    }

    function uniformAirdrop(address[] calldata recipients, uint256 amountEach) external onlyOwner {
        if (recipients.length == 0) {
            revert EmptyRecipientsArray();
        }

        if (amountEach == 0) {
            revert InvalidAmount();
        }

        for (uint256 i = 0; i < recipients.length; ++i) {
            if (recipients[i] == address(0)) {
                revert InvalidRecipient(i);
            }
            antToken.safeTransfer(recipients[i], amountEach);
        }

        emit UniformAirdropCompleted(recipients, amountEach);
    }

    function setAntToken(IERC20 _antToken) external onlyOwner {
        antToken = _antToken;
    }

    function withdraw(uint256 amount) external onlyOwner {
        antToken.safeTransfer(owner(), amount);
    }
}
