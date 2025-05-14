// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/Script.sol";
import "forge-std/src/console.sol";
import {AppRegistry} from "../src/AppRegistry.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployAppRegistryTestnet is Script {
    address public sender = 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4;
    uint256 APPS_COUNT = 34;

    function run() external {
        console.log("starting deployment");

        uint256 deployerPrivKey = vm.envUint("KEY_TESTNET");
        vm.startBroadcast(deployerPrivKey);

        AppRegistry appRegistry = new AppRegistry(sender);

        console.log("App Registry deployed to: ", address(appRegistry));
        

        for (uint256 i = 0; i < APPS_COUNT; i++) {
            appRegistry.registerApp(sender, createString(i), "test", "https://autonomi.com");
        }
        console.log("Test apps registered");
    }

    function createString(uint256 number) public pure returns (string memory) {
        return string(abi.encodePacked("Test app ", Strings.toString(number)));
    }
}
