// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/console.sol";
import "forge-std/src/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BatchETHTransfer} from "../src/BatchETHTransfer.sol";

contract BatchETHTransferDeployer is Script {
    function run() external {
        console.log("starting deploy...");

        uint256 deployerPrivKey = vm.envUint("KEY");
        vm.startBroadcast(deployerPrivKey);

        BatchETHTransfer bt = new BatchETHTransfer();

        console.log("Batch transfer contract deployed to: ", address(bt));
    }
}
