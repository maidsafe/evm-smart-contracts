// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/src/console.sol";
import "./Helper.sol";
import "./DummyToken.sol";

import "../src/Airdrop.sol";

contract AirdropTest is Helper {
    Airdrop public airdrop;
    DummyToken public token;

    uint256 amountPerTest = 500000000000000000000000000;

    function setUp() public {
        vm.startPrank(dev);

        forkArbitrum();
        selectArbitrum();

        token = new DummyToken("test token", "tt");

        airdrop = new Airdrop(IERC20(address(token)));

        token.transfer(address(airdrop), amountPerTest);
    }

    function test_regularTransfer() public {
        uint256 transferAmount = amountPerTest / 1000;
         for (uint256 i = 1; i < 700; i++) {
            token.transfer(address(uint160(i)), transferAmount);
        }
    }

    function test_batchAirdrop() public {
        uint256 transferAmount = amountPerTest / 1000;
        Airdrop.AirdropRecipient[] memory recipients = new Airdrop.AirdropRecipient[](10);
        for (uint256 i = 0; i < recipients.length; i++) {
            recipients[i] = Airdrop.AirdropRecipient({
                recipient: address(uint160(i+1)),
                amount: transferAmount
            });
        }

        airdrop.batchAirdrop(recipients);
    }
}