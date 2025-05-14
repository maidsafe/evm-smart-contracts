// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAutonomiNFT} from "../src/IAutonomiNFT.sol";
import {Claims} from "../src/Claims.sol";

contract DeployClaims is Script {

    IERC20 constant ANT_TOKEN = IERC20(0xa78d8321B20c4Ef90eCd72f2588AA985A4BDb684);

    IAutonomiNFT constant AUTONOMI_NFT = IAutonomiNFT(0x04fAAC48DfC8e757A2a0E052cf8A9EF2618c9DD8);

    function run() external {
        console.log("starting deploy...");

        uint256 deployerPrivKey = vm.envUint("KEY");
        vm.startBroadcast(deployerPrivKey);

        Claims claims = new Claims(ANT_TOKEN, AUTONOMI_NFT);       

        console.log("Claims deployed to: ", address(claims)); 
    }
}
