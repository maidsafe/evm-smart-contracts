// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/Script.sol";
import "forge-std/src/console.sol";
import {IAppRegistry} from "../src/interfaces/IAppRegistry.sol";
import {Phase1Voting} from "../src/Phase1Voting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployPhase1Voting is Script {
    address public sender = 0xf14176Fe20d87fb763eF908C378B0FbF595c32a1;

    IERC20 public ant = IERC20(0xa78d8321B20c4Ef90eCd72f2588AA985A4BDb684);

    IAppRegistry public appRegistry = IAppRegistry(0x81feC66E8eE72cfa971761eD241B7D0e91a4D122);

    uint256 public b = 4000817287620000000000;

    uint256 public K = 12;

    uint256 public votingStartTime = 1746702000; // Wed May 08 2025 11:00:00 GMT+0000
    uint256 public maxMultiplier = 2e18;

    address public antBeneficiary = 0x675D39cdCEA31ba8313565b03D684A3bbe183a1a;

    function run() external {
        console.log("starting deployment");

        uint256 deployerPrivKey = vm.envUint("KEY_MAINNET");
        vm.startBroadcast(deployerPrivKey);

        Phase1Voting phase1Voting =
            new Phase1Voting(b, K, appRegistry, ant, antBeneficiary, votingStartTime, maxMultiplier);

        console.log("Phase 1 voting deployed to : ", address(phase1Voting));
    }
}
