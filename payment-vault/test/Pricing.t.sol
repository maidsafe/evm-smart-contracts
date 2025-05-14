// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./Helper.sol";
import "../src/PaymentVault/Pricing.sol";
import {IPaymentVault} from "../src/PaymentVault/IPaymentVault.sol";

contract PricingTest is Helper {
    PricingCalculator public pricing;

    uint256 CHUNK_COST_UNIT = 10;
    uint256 GRAPH_ENTRY_COST_UNIT = 1;
    uint256 SCRATCHPAD_COST_UNIT = 100;
    uint256 POINTER_COST_UNIT = 20;

    uint256 MAX_COST_UNIT = 163840;

    IPaymentVault.DataType[] public dataTypes;

    uint256[] public costUnits;

    function setUp() public {
        vm.startPrank(dev);
        _deployPricingCalculator();

        pricing.setMaxCostUnit(MAX_COST_UNIT);

        dataTypes.push(IPaymentVault.DataType.GraphEntry);
        dataTypes.push(IPaymentVault.DataType.Scratchpad);
        dataTypes.push(IPaymentVault.DataType.Chunk);
        dataTypes.push(IPaymentVault.DataType.Pointer);

        costUnits.push(GRAPH_ENTRY_COST_UNIT);
        costUnits.push(SCRATCHPAD_COST_UNIT);
        costUnits.push(CHUNK_COST_UNIT);
        costUnits.push(POINTER_COST_UNIT);

        pricing.setCostUnitForDataTypes(dataTypes, costUnits);

        vm.stopPrank();
    }

    function test_calculatePrice_fuzz(uint256 randomNumber, uint256 recordsCount) public view {
        IPaymentVault.DataType dataType = selectDataType(randomNumber);

        vm.assume(recordsCount > 0);
        vm.assume(recordsCount < 200);

        IPaymentVault.Record[] memory records1 = new IPaymentVault.Record[](1);
        records1[0] = IPaymentVault.Record({dataType: dataType, records: recordsCount});

        IPaymentVault.QuotingMetrics memory testMetrics1 = IPaymentVault.QuotingMetrics({
            dataType: dataType,
            dataSize: 0,
            closeRecordsStored: 0,
            recordsPerType: records1,
            maxRecords: 0,
            receivedPaymentCount: 0,
            liveTime: 0,
            networkDensity: 0,
            networkSize: 0
        });

        IPaymentVault.Record[] memory records2 = new IPaymentVault.Record[](1);
        records2[0] = IPaymentVault.Record({dataType: dataType, records: recordsCount - 1});

        IPaymentVault.QuotingMetrics memory testMetrics2 = IPaymentVault.QuotingMetrics({
            dataType: dataType,
            dataSize: 0,
            closeRecordsStored: 0,
            recordsPerType: records2,
            maxRecords: 0,
            receivedPaymentCount: 0,
            liveTime: 0,
            networkDensity: 0,
            networkSize: 0
        });

        uint256 returnPrice1 = pricing.calculatePrice(1e18, testMetrics1);
        uint256 returnPrice2 = pricing.calculatePrice(1e18, testMetrics2);

        uint256 difference = returnPrice1 - returnPrice2;

        if (dataType == IPaymentVault.DataType.GraphEntry) {
            assertApproxEqAbs(difference, 37200000, 200000);
        } else if (dataType == IPaymentVault.DataType.Scratchpad) {
            assertApproxEqAbs(difference, 373000000000, 200000000000);
        } else if (dataType == IPaymentVault.DataType.Chunk) {
            assertApproxEqAbs(difference, 3720000000, 200000000);
        } else if (dataType == IPaymentVault.DataType.Pointer) {
            assertApproxEqAbs(difference, 14900000000, 2000000000);
        }
    }

    function test_calculatePrice() public view {
        IPaymentVault.Record[] memory records = new IPaymentVault.Record[](1);
        records[0] = IPaymentVault.Record({dataType: IPaymentVault.DataType.GraphEntry, records: 4});

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

        uint256 returnPrice = pricing.calculatePrice(1e18, testMetrics);

        IPaymentVault.Record[] memory records2 = new IPaymentVault.Record[](1);
        records2[0] = IPaymentVault.Record({dataType: IPaymentVault.DataType.GraphEntry, records: 3});

        IPaymentVault.QuotingMetrics memory testMetrics2 = IPaymentVault.QuotingMetrics({
            dataType: IPaymentVault.DataType.GraphEntry,
            dataSize: 0,
            closeRecordsStored: 0,
            recordsPerType: records2,
            maxRecords: 0,
            receivedPaymentCount: 0,
            liveTime: 0,
            networkDensity: 0,
            networkSize: 0
        });

        uint256 returnPrice2 = pricing.calculatePrice(1e18, testMetrics2);
        assertApproxEqAbs(returnPrice - returnPrice2, 37200000, 200000);
    }

    function test_calculateLnSigned() public view {
        int256 value = pricing.calculateLnSigned(int256(10 ether));
        assertEq(value, 2302585092994045674);
    }

    function test_getTotalCostUnit() public view {
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

        uint256 totalCostUnit = pricing.getTotalCostUnit(testMetrics);
        assertEq(totalCostUnit, 1);
    }

    function test_setScalingFactor() public {
        vm.startPrank(dev);
        pricing.setScalingFactor(1e19);
        uint256 scalingfactor = pricing.scalingFactor();
        assertEq(scalingfactor, 1e19);
        vm.stopPrank();
    }

    function test_cannot_setScalingFactor_notOwner() public {
        vm.expectRevert();
        pricing.setScalingFactor(1e19);
    }

    function test_setMinPrice() public {
        vm.startPrank(dev);
        pricing.setMinPrice(2);
        assertEq(pricing.minPrice(), 2);
        vm.stopPrank();

    }

    function test_setMinPrice_notOwner() public {
        vm.expectRevert();
        pricing.setMinPrice(2);
    }

    function test_setMaxCostUnit() public {
        vm.startPrank(dev);
        pricing.setMaxCostUnit(100);
        assertEq(pricing.maxCostUnit(), 100);
        vm.stopPrank();

    }

    function test_setMaxCostUnit_notOwner() public {
        vm.expectRevert();
        pricing.setMaxCostUnit(100);
    }

    function test_setCostUnitPerDataType() public {
        vm.startPrank(dev);
        pricing.setCostUnitPerDataType(IPaymentVault.DataType.Chunk, 42);
        assertEq(pricing.costUnitPerDataType(IPaymentVault.DataType.Chunk), 42);
        vm.stopPrank();

    }

    function test_setCostUnitPerDataType_notOwner() public {
        vm.expectRevert();
        pricing.setCostUnitPerDataType(IPaymentVault.DataType.Chunk, 42);
    }

    function test_setCostUnitForDataTypes() public {
        vm.startPrank(dev);

        IPaymentVault.DataType[] memory _dataTypes = new IPaymentVault.DataType[](2);
        _dataTypes[0] = IPaymentVault.DataType.Chunk;
        _dataTypes[1] = IPaymentVault.DataType.Scratchpad;

        uint256[] memory _costUnits = new uint256[](2);
        _costUnits[0] = 42;
        _costUnits[1] = 69;

        pricing.setCostUnitForDataTypes(_dataTypes, _costUnits);

        assertEq(pricing.costUnitPerDataType(IPaymentVault.DataType.Chunk), 42);
        assertEq(pricing.costUnitPerDataType(IPaymentVault.DataType.Scratchpad), 69);

        vm.stopPrank();

    }

    function test_setCostUnitForDataTypes_notOwner() public {
        IPaymentVault.DataType[] memory _dataTypes = new IPaymentVault.DataType[](2);
        _dataTypes[0] = IPaymentVault.DataType.Chunk;
        _dataTypes[1] = IPaymentVault.DataType.Scratchpad;

        uint256[] memory _costUnits = new uint256[](2);
        _costUnits[0] = 42;
        _costUnits[1] = 69;

        vm.expectRevert();
        pricing.setCostUnitForDataTypes(_dataTypes, _costUnits);
    }

    function test_proxyUpgrade() public {
        vm.startPrank(dev);

        PricingCalculator newPricingImpl = new PricingCalculator();

        pricing.upgradeToAndCall(address(newPricingImpl), "");

        vm.stopPrank();
    }

    function _deployPricingCalculator() private {
        PricingCalculator _pricingCalculatorImpl = new PricingCalculator();

        bytes memory initData = abi.encodeCall(PricingCalculator.initialize, (1e18, 1, 1000));
        ERC1967Proxy pricingProxy = new ERC1967Proxy(address(_pricingCalculatorImpl), initData);

        pricing = PricingCalculator(address(pricingProxy));
    }

    function selectDataType(uint256 randomNumber) internal pure returns (IPaymentVault.DataType) {
        // Use modulo 4 to map the random number to one of the 4 enum values
        uint256 index = randomNumber % 4;
        console.log(index);

        // Return the corresponding DataType
        return IPaymentVault.DataType(index);
    }
}
