// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/Script.sol";

import {AutonomiNFT} from "../src/AutonomiNFT.sol";

contract DeployAutonomiNFT is Script {

    string constant NAME = "Autonomi NFT";
    string constant SYMBOL = "AUTONOMI";
    string constant BASE_TOKEN_URI = "http://arweave.net/ZTfGhytJf5F2ZQ1wDKJ1RODp2pczavp6X9GW07aHdD8/";

    function run() external {
        console.log("starting deploy...");

        uint256 deployerPrivKey = vm.envUint("KEY");
        vm.startBroadcast(deployerPrivKey);

        AutonomiNFT autonomiNFT = new AutonomiNFT(NAME, SYMBOL, BASE_TOKEN_URI);

        console.log("Autonomi NFT deployed to: ", address(autonomiNFT));
    }
}
