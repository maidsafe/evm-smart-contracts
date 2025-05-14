// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/console.sol";
import "forge-std/src/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Airdrop} from "../src/Airdrop.sol";

contract AirdropDeployer is Script {
    address public sender = 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4;
    IERC20 public ANT = IERC20(0xa78d8321B20c4Ef90eCd72f2588AA985A4BDb684);
    function run() external {
        console.log("starting deploy...");
        
        uint256 deployerPrivKey = vm.envUint("KEY");
        vm.startBroadcast(deployerPrivKey);

        Airdrop airdrop = new Airdrop(ANT);

        console.log("Airdrop contract deployed to: ", address(airdrop));
    }
}