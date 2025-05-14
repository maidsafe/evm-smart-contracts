// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/Script.sol";
import "forge-std/src/console.sol";
import {IAppRegistry} from "../src/AppRegistry.sol";
import {Phase1Voting} from "../src/Phase1Voting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* 
  App registry deployed to:  0x59653fE6ef610F982b87d83f790D57C184a8F5ED
  Phase 1 voting deployed to :  0x60aA9987D4E42BA7bbc63d69b72bD6e89Cef8f42
 */
contract DeployPhase1VotingTestnet is Script {
    address public sender = 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4;
    // use dummy ANT token from claims
    IERC20 public ant = IERC20(0xE08384C4dECAfF7127353A7C68C2aeA3d84f95a8);

    uint256 public K = 12;

    function run() external {
        console.log("starting deployment");

        uint256 deployerPrivKey = vm.envUint("KEY_TESTNET");
        vm.startBroadcast(deployerPrivKey);

        // deploy phase 1 voting
        Phase1Voting phase1Voting = new Phase1Voting(
            4000817287620000000000, K, IAppRegistry(0x8201A081A0a685eDB2eDEed936Fb3f68e4bf84b2), ant, sender, block.timestamp + 1 minutes, 2e18
        );

        console.log("Phase 1 voting deployed to : ", address(phase1Voting));
    }
}
