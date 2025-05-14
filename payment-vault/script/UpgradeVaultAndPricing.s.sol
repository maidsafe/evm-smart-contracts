// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/console.sol";
import "forge-std/src/Script.sol";
import {IPaymentVault, PaymentVault} from "../src/PaymentVault/PaymentVault.sol";
import {PricingCalculator} from "../src/PaymentVault/Pricing.sol";

/* 
- upgrade the pricing implementation on testnet
- verify that the returned price is correct
- upgrade the payment vault to the new implementation
- update the pricing calculator address in the payment vault
- verify that the payment vault works correctly
 */

contract UpgradeVaultAndPricing is Script {
    address public vaultProxy = 0x993C7739f50899A997fEF20860554b8a28113634;
    address public pricingProxy = 0xD28a08692D291e38c970DdAE776D0deFD12538E2;

    // TODO: Upgrade pricing implementation beforehand
    function run() external {
        console.log("starting update of pricing and vault...");
        
        uint256 deployerPrivKey = vm.envUint("KEY");
        vm.startBroadcast(deployerPrivKey);

        require(PricingCalculator(pricingProxy).costUnitPerDataType(IPaymentVault.DataType.GraphEntry) == 1, "Pricing proxy not upgraded yet");

        PaymentVault newVaultImpl = new PaymentVault();

        console.log("Vault Implementation: ", address(newVaultImpl));

        PaymentVault(vaultProxy).upgradeToAndCall(address(newVaultImpl), "");

        (bytes16 rewardsAddress, uint128 rewardsAddressAmount, bytes16 relayNodeAddress, uint128 relayNodeAmount) = PaymentVault(vaultProxy).completedPayments(0x982d3276ca057e383b185c3401349bc842ca23ed2074cd4fae782a6765f79ba0);

        console.logBytes16(rewardsAddress);
        console.log(rewardsAddressAmount);
        console.logBytes16(relayNodeAddress);
        console.log(relayNodeAmount);
    }
}