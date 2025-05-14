// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/console.sol";
import "forge-std/src/Script.sol";

import {AntCirculatingSupply} from "../src/AntCirculatingSupply.sol";

contract AntCirculatingSupplyDeployer is Script {
    address public shareholders = 0xd176a7A36608EAd4cA3EB461EbB17027f8C524a9;
    address public emissionsReserve = 0xdA4f3aF146f86850DE8e0D6FaE6EEe051Ad0AA44;
    address public emissionsService = 0x3550728Fe3324a62Ad714d4c147ba1d1cF4F0bc7;
    address public foundationLP = 0x1d24Fb12F1AA3B6585bD34E00939A67c5883108C;
    address public foundation = 0xd10A556E6A5111b5D4Dd5Ae06761d41F6CE1D499;
    address public foundationNodeRewards = 0xc20c19b57629fc22E8e1e50a3b924A20b0fA25AA;
    address public foundationReserve = 0x4f7B7fd0533d06D2ABFad07eAe57C9CE8E92B670;
    address public emaidAirdropper = 0x675D39cdCEA31ba8313565b03D684A3bbe183a1a;

    function run() external {
        console.log("starting deploy...");

        uint256 deployerPrivKey = vm.envUint("KEY");
        vm.startBroadcast(deployerPrivKey);

        AntCirculatingSupply antCirculatingSupply = new AntCirculatingSupply(
            shareholders,
            emissionsReserve,
            emissionsService,
            foundationLP,
            foundation,
            foundationNodeRewards,
            foundationReserve,
            emaidAirdropper
        );

        console.log("ANT circulating supply contract deployed to: ", address(antCirculatingSupply));

        uint256 circulatingSupply = antCirculatingSupply.totalCirculatingSupply();

        console.log("TOTAL CIRCULATING SUPPLY: ", circulatingSupply);
    }
}
