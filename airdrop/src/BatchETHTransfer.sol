// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract BatchETHTransfer {
    struct Recipient {
        address recipient;
        uint256 amount;
    }

    error EmptyRecipientsArray();
    error InvalidRecipient(uint256 idx);
    error TransferFailed(uint256 idx);

    function batchETHTransfer(Recipient[] calldata recipients) external payable {
        if (recipients.length == 0) {
            revert EmptyRecipientsArray();
        }

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < recipients.length; ++i) {
            if (recipients[i].recipient == address(0)) {
                revert InvalidRecipient(i);
            }

            (bool success,) = recipients[i].recipient.call{value: recipients[i].amount}("");
            if (!success) {
                revert TransferFailed(i);
            }

            totalAmount += recipients[i].amount;
        }

        // Refund excess ETH if any
        uint256 remaining = msg.value - totalAmount;
        if (remaining > 0) {
            (bool success,) = msg.sender.call{value: remaining}("");
            require(success, "Refund failed");
        }
    }
}
