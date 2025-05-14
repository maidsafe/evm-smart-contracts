// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/PaymentVault/IPaymentVault.sol";

contract DataPayments {
    address public immutable PAYMENT_TOKEN_ADDRESS;

    event DataPaymentMade(
        address indexed rewardsAddress,
        uint256 indexed amount,
        bytes32 indexed quoteHash
    );

    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Token address cannot be zero address");

        PAYMENT_TOKEN_ADDRESS = _tokenAddress;
    }

    function submitDataPayments(IPaymentVault.DataPayment[] calldata dataPayments) external {
        for (uint256 i = 0; i < dataPayments.length; i++) {
            IPaymentVault.DataPayment calldata dataPayment = dataPayments[i];

            // Send tokens to the reward address
            _sendTokens(msg.sender, dataPayment.rewardsAddress, dataPayment.amount);

            // Emit events that can be listened to and will be stored in the transaction
            emit DataPaymentMade(dataPayment.rewardsAddress, dataPayment.amount, dataPayment.quoteHash);
        }
    }

    function _sendTokens(address from, address to, uint256 amount) internal {
        require(IERC20(PAYMENT_TOKEN_ADDRESS).balanceOf(from) >= amount, "Wallet does not have enough tokens");

        if (from != address(this)) {
            require(IERC20(PAYMENT_TOKEN_ADDRESS).allowance(from, address(this)) >= amount, "Contract is not allowed to spend enough tokens");
        }

        IERC20(PAYMENT_TOKEN_ADDRESS).transferFrom(from, to, amount);
    }
}