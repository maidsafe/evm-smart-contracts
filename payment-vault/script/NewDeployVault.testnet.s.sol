// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/console.sol";
import "forge-std/src/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PaymentVault} from "../src/PaymentVault/PaymentVault.sol";
import {PricingCalculator} from "../src/PaymentVault/Pricing.sol";

contract NewTestnetVaultDeployer is Script {
    address public sender = 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4;
    IERC20 public antToken = IERC20(0x4bc1aCE0E66170375462cB4E6Af42Ad4D5EC689C);
    AggregatorV3Interface public arbSepoliaUSDCPriceFeed =
        AggregatorV3Interface(0x0153002d20B96532C639313c2d54c3dA09109309);

    PricingCalculator public pricing = PricingCalculator(0xb49418F07A60F779156E783a7402fE54c50ef2ae);
    PaymentVault public vault;

    uint256 constant PRICING_SCALING_FACTOR = 1e18;
    uint256 constant PRICING_MIN_PRICE = 1;
    uint256 constant PRICING_MAX_UNIT_COST = 1000;

    function run() external {
        console.log("starting deployment");

        uint256 deployerPrivKey = vm.envUint("KEY");
        vm.startBroadcast(deployerPrivKey);

        // - deploy the implementation for the vault contract
        PaymentVault newVaultImpl = new PaymentVault();
        console.log("new payment vault implementation: ", address(newVaultImpl));

        bytes memory vaultInitData = abi.encodeCall(
            PaymentVault.initialize,
            (
                antToken,
                512,
                arbSepoliaUSDCPriceFeed,
                AggregatorV3Interface(address(0)),
                PricingCalculator(0xb49418F07A60F779156E783a7402fE54c50ef2ae)
            )
        );

        // - deploy and init the proxy for the vault contract
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(newVaultImpl), vaultInitData);
        vault = PaymentVault(address(vaultProxy));

        console.log("Vault proxy deployed to: ", address(vaultProxy));

        // - verify that the correct values are set
        require(pricing.scalingFactor() == 1e18);
        require(pricing.minPrice() == 1);

        require(vault.batchLimit() == 512);

        require(vault.requiredPaymentVerificationLength() == 5);

        require(vault.antToken() == antToken);
        require(vault.priceFeed() == arbSepoliaUSDCPriceFeed);
        require(vault.sequencerUptimeFeed() == AggregatorV3Interface(address(0)));
        require(vault.pricingCalculator() == pricing);
    }
}
