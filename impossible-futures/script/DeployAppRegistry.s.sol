// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/Script.sol";
import "forge-std/src/console.sol";
import {AppRegistry} from "../src/AppRegistry.sol";

contract DeployAppRegistry is Script {
    address public sender = 0xf14176Fe20d87fb763eF908C378B0FbF595c32a1;
    function run() external {
        console.log("starting deployment");

        uint256 deployerPrivKey = vm.envUint("KEY_MAINNET");
        vm.startBroadcast(deployerPrivKey);

        AppRegistry appRegistry = new AppRegistry(sender);

        console.log("App Registry deployed to: ", address(appRegistry));
    }
}
