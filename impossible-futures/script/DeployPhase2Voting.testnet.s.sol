// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/Script.sol";
import "forge-std/src/console.sol";
import {IAppRegistry} from "../src/AppRegistry.sol";
import {Phase2Voting} from "../src/Phase2Voting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//   Phase 2 Voting deployed to:  0x709C9895F68F8d924DF15D308077868A70CE96AA
contract DeployPhase2VotingTestnet is Script {
    address public sender = 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4;
    // use dummy ANT token from claims
    IERC20 public ant = IERC20(0xE08384C4dECAfF7127353A7C68C2aeA3d84f95a8);

    IAppRegistry appRegistry = IAppRegistry(0x8201A081A0a685eDB2eDEed936Fb3f68e4bf84b2);

    uint256 startTimestamp = block.timestamp + 1 minutes;

    uint256 initialShares = 100 * 1e18;
    uint256 finalShares = 50 * 1e18;
    uint256 p = 5 * 1e17; // 0.5

    function run() external {
        console.log("starting deployment");

        uint256 deployerPrivKey = vm.envUint("KEY_TESTNET");
        vm.startBroadcast(deployerPrivKey);

        Phase2Voting v = new Phase2Voting(startTimestamp, appRegistry, ant, initialShares, finalShares, p);

        console.log("Phase 2 Voting deployed to: ", address(v));
    }
}
