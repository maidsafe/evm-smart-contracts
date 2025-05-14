// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/Script.sol";
import {FoundationEmissions} from "../src/FoundationEmissions.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployFoundationEmissions is Script {
    IERC20 constant ANT_TOKEN = IERC20(0xa78d8321B20c4Ef90eCd72f2588AA985A4BDb684);
    address constant FOUNDATION = 0xf14176Fe20d87fb763eF908C378B0FbF595c32a1; // TODO

    function run() external {
        console.log("starting deploy...");

        uint256 deployerPrivKey = vm.envUint("KEY");
        vm.startBroadcast(deployerPrivKey);

        FoundationEmissions foundationEmissions = new FoundationEmissions(ANT_TOKEN, FOUNDATION);

        console.log("Foundation emissions deployed to: ", address(foundationEmissions));
    }
}
