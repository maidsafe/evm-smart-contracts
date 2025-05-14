// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/console.sol";
import "forge-std/src/Script.sol";
import "../src/PaymentVault/Pricing.sol";
import {IPaymentVault} from "../src/PaymentVault/IPaymentVault.sol";

contract PricingUpgrader is Script {
    address public sender = 0xeeb3e0999D01f0d1Ed465513E414725a357F6ae4;

    address public pricingProxy = 0xD28a08692D291e38c970DdAE776D0deFD12538E2;

    uint256 MAX_COST_UNIT = 163840;

    uint256 CHUNK_COST_UNIT = 10;
    uint256 GRAPH_ENTRY_COST_UNIT = 1; 
    uint256 SCRATCHPAD_COST_UNIT = 100;
    uint256 POINTER_COST_UNIT = 20;

    IPaymentVault.DataType[] public dataTypes;

    uint256[] public costUnits;

    function run() external {
        uint256 deployerPrivKey = vm.envUint("KEY");
        vm.startBroadcast(deployerPrivKey);

        PricingCalculator newPricingImpl = new PricingCalculator();

        console.log("New pricing implementation: ", address(newPricingImpl));

        PricingCalculator(pricingProxy).upgradeToAndCall(address(newPricingImpl), "");

        PricingCalculator(pricingProxy).setMaxCostUnit(MAX_COST_UNIT);

        dataTypes.push(IPaymentVault.DataType.GraphEntry);
        dataTypes.push(IPaymentVault.DataType.Scratchpad);
        dataTypes.push(IPaymentVault.DataType.Chunk);
        dataTypes.push(IPaymentVault.DataType.Pointer);

        costUnits.push(GRAPH_ENTRY_COST_UNIT);
        costUnits.push(SCRATCHPAD_COST_UNIT);
        costUnits.push(CHUNK_COST_UNIT);
        costUnits.push(POINTER_COST_UNIT);

        PricingCalculator(pricingProxy).setCostUnitForDataTypes(dataTypes, costUnits);

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

        uint256 returnPrice = PricingCalculator(pricingProxy).calculatePrice(1e18, testMetrics);
        console.log("return price: ", returnPrice);

    }
}

