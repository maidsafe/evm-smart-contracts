// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import "forge-std/src/console.sol";
import "forge-std/src/Script.sol";

import {AutonomiNetworkToken} from "../src/AutonomiNetworkToken.sol";
// 0xa78d8321B20c4Ef90eCd72f2588AA985A4BDb684
contract AntDeployer is Script {
    address public sender = 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4;

    address public AUTONOMI = 0x4f7B7fd0533d06D2ABFad07eAe57C9CE8E92B670;

    uint256 ANT_TOTAL_SUPPLY = 1_200_000_000 ether;

    function run() external {
        console.log("starting deploy...");
        
        uint256 deployerPrivKey = vm.envUint("KEY");
        vm.startBroadcast(deployerPrivKey);

        AutonomiNetworkToken ant = new AutonomiNetworkToken(AUTONOMI);

        console.log("ANT deployed to: ", address(ant));

        uint256 totalSupply = ant.totalSupply();
        require(totalSupply == ANT_TOTAL_SUPPLY, "invalid supply");

        require(ant.balanceOf(AUTONOMI) == ANT_TOTAL_SUPPLY, "invalid autonomi balance");
    }
}