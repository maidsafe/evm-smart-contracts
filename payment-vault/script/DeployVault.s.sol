// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/console.sol";
import "forge-std/src/Script.sol";

import {PaymentVault} from "../src/PaymentVault/PaymentVault.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultDeployer is Script {
    address public sender = 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4;

    address public vaultProxy = 0x607483B50C5F06c25cDC316b6d1E071084EeC9f5;

    function run() external {
        console.log("starting deploy...");
        
        uint256 deployerPrivKey = vm.envUint("KEY");
        vm.startBroadcast(deployerPrivKey);

        PaymentVault newVaultImpl = new PaymentVault();

        console.log("Vault Implementation: ", address(newVaultImpl));

        PaymentVault(vaultProxy).upgradeToAndCall(address(newVaultImpl), "");
    }
}