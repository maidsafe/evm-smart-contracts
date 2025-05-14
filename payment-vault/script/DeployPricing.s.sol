// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/console.sol";
import "forge-std/src/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PaymentVault} from "../src/PaymentVault/PaymentVault.sol";
import {PricingCalculator} from "../src/PaymentVault/Pricing.sol";
import {IPaymentVault} from "../src/PaymentVault/IPaymentVault.sol";

contract NewPricingDeployer is Script {
    address public sender = 0xf14176Fe20d87fb763eF908C378B0FbF595c32a1;
    IERC20 public antToken = IERC20(0xa78d8321B20c4Ef90eCd72f2588AA985A4BDb684);

    AggregatorV3Interface public arbOneUSDCPriceFeed =
        AggregatorV3Interface(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3);

    // PRICE FEED: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3

    // address vaultProxy = 0x993C7739f50899A997fEF20860554b8a28113634; // USED FOR LIVE TESTNET
    // address vaultProxy2 = 0x7f0842a78F7d4085d975bA91d630D680f91b1295; // USED FOR TEST ENVIRONMENT
    // address vaultProxy3 = 0x607483B50C5F06c25cDC316b6d1E071084EeC9f5; // USED FOR ARB ONE

    PricingCalculator public pricing;

    uint256 constant PRICING_SCALING_FACTOR = 1e18;
    uint256 constant PRICING_MIN_PRICE = 1;

    uint256 MAX_COST_UNIT = 163840;

    uint256 CHUNK_COST_UNIT = 10;
    uint256 GRAPH_ENTRY_COST_UNIT = 1; 
    uint256 SCRATCHPAD_COST_UNIT = 100;
    uint256 POINTER_COST_UNIT = 20;

    IPaymentVault.DataType[] public dataTypes;

    uint256[] public costUnits;

    function run() external {
        console.log("starting deployment");

        uint256 deployerPrivKey = vm.envUint("KEY");
        vm.startBroadcast(deployerPrivKey);

        // - deploy the implementation for the pricing contract
        PricingCalculator newPricingImpl = new PricingCalculator();
        console.log("new pricing implementation: ", address(newPricingImpl));

        bytes memory pricingInitData = abi.encodeCall(PricingCalculator.initialize, (PRICING_SCALING_FACTOR, PRICING_MIN_PRICE, MAX_COST_UNIT));

        // - deploy and init the proxy for the pricing contract
        ERC1967Proxy pricingProxy = new ERC1967Proxy(address(newPricingImpl), pricingInitData);
        pricing = PricingCalculator(address(pricingProxy));

        console.log("Pricing proxy deployed to: ", address(pricingProxy));

        PricingCalculator(address(pricingProxy)).setMaxCostUnit(MAX_COST_UNIT);

        dataTypes.push(IPaymentVault.DataType.GraphEntry);
        dataTypes.push(IPaymentVault.DataType.Scratchpad);
        dataTypes.push(IPaymentVault.DataType.Chunk);
        dataTypes.push(IPaymentVault.DataType.Pointer);

        costUnits.push(GRAPH_ENTRY_COST_UNIT);
        costUnits.push(SCRATCHPAD_COST_UNIT);
        costUnits.push(CHUNK_COST_UNIT);
        costUnits.push(POINTER_COST_UNIT);

        PricingCalculator(address(pricingProxy)).setCostUnitForDataTypes(dataTypes, costUnits);

        IPaymentVault.Record[] memory records = new IPaymentVault.Record[](1);
        records[0] = IPaymentVault.Record({dataType: IPaymentVault.DataType.GraphEntry, records: 1});

        IPaymentVault.QuotingMetrics memory testMetrics = IPaymentVault.QuotingMetrics({
            dataType: IPaymentVault.DataType.GraphEntry,
            dataSize: 0,
            closeRecordsStored: 0,
            recordsPerType: records,
            maxRecords: 0,
            receivedPaymentCount: 0,
            liveTime: 0,
            networkDensity: 0,
            networkSize: 0
        });

        uint256 returnPrice = PricingCalculator(address(pricingProxy)).calculatePrice(1e18, testMetrics);
        console.log("return price: ", returnPrice);

        PaymentVault newVaultImpl = new PaymentVault();
        console.log("Vault Implementation: ", address(newVaultImpl));

        bytes memory vaultInitData = abi.encodeCall(PaymentVault.initialize, (antToken,512,arbOneUSDCPriceFeed,AggregatorV3Interface(address(0)),PricingCalculator(address(pricingProxy))));

        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(newVaultImpl), vaultInitData);
        console.log("payment vault proxy deployed to: ", address(vaultProxy));

        IPaymentVault.QuotingMetrics[] memory _metrics = new IPaymentVault.QuotingMetrics[](1);
        _metrics[0] = testMetrics;
        uint256[] memory _prices = PaymentVault(address(vaultProxy)).getQuote(_metrics);

        console.log("return price 2: ", _prices[0]);

         // - verify that the correct values are set
        require(pricing.scalingFactor() == 1e18, "scaling factor not ok");
        require(pricing.minPrice() == 1, "min price not ok");

        require(PaymentVault(address(vaultProxy)).batchLimit() == 512, "batch limit not ok");
        require(PaymentVault(address(vaultProxy)).requiredPaymentVerificationLength() == 5, "verification length not ok");

        require(PaymentVault(address(vaultProxy)).antToken() == antToken, "ant token not ok");
        require(PaymentVault(address(vaultProxy)).priceFeed() == arbOneUSDCPriceFeed, "price feed not ok");
        require(PaymentVault(address(vaultProxy)).sequencerUptimeFeed() == AggregatorV3Interface(address(0)), "sequencer not ok");
        require(PaymentVault(address(vaultProxy)).pricingCalculator() == pricing, "pricing not ok");
    }
}