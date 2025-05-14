// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/console.sol";
import "forge-std/src/Script.sol";

import {PaymentVault} from "../src/PaymentVault/PaymentVault.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {PricingCalculator} from "../src/PaymentVault/Pricing.sol";

contract TestnetVaultPricingUpdater is Script {
    address public sender = 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4;

    address public vaultProxy2 = 0x993C7739f50899A997fEF20860554b8a28113634;

    address public pricingProxy = 0xD28a08692D291e38c970DdAE776D0deFD12538E2;

    address public vaultImplementation = 0xBC9697fdcD58bED8A87E90f0cD6ed0Fc1b104524;

    AggregatorV3Interface public arbSepoliaUSDCPriceFeed =
        AggregatorV3Interface(0x0153002d20B96532C639313c2d54c3dA09109309);

    IERC20 public antToken = IERC20(0xBE1802c27C324a28aeBcd7eeC7D734246C807194);

    function run() external {
        console.log("starting update...");

        uint256 deployerPrivKey = vm.envUint("KEY");
        vm.startBroadcast(deployerPrivKey);

        PaymentVault(vaultProxy2).upgradeToAndCall(vaultImplementation, "");

        PaymentVault(vaultProxy2).setPricingCalculator(PricingCalculator(pricingProxy));

        PaymentVault(vaultProxy2).setPriceFeed(arbSepoliaUSDCPriceFeed);

        PaymentVault(vaultProxy2).setRequiredPaymentVerificationLength(5);

        require(PricingCalculator(pricingProxy).scalingFactor() == 1e18, "invalid scaling");
        require(PricingCalculator(pricingProxy).minPrice() == 1, "invalid min price");

        require(PaymentVault(vaultProxy2).batchLimit() == 512,"invalid batch size");

        require(PaymentVault(vaultProxy2).antToken() == antToken, "invalid ant token");
        require(PaymentVault(vaultProxy2).priceFeed() == arbSepoliaUSDCPriceFeed, "invalid price feed");
        require(PaymentVault(vaultProxy2).sequencerUptimeFeed() == AggregatorV3Interface(address(0)), "invalid sequencer");
        require(PaymentVault(vaultProxy2).pricingCalculator() == PricingCalculator(pricingProxy), "invalid pricing calculator");
    }
}
