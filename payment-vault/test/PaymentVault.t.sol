// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "forge-std/src/console.sol";

import "./Helper.sol";

import "./DummyToken.sol";

import "../src/PaymentVault/PaymentVault.sol";
import "../src/PaymentVault/Pricing.sol";
import {Vm} from "forge-std/src/Vm.sol";

contract PaymentVaultTest is Helper {
    PaymentVault public vault;
    DummyToken public ant;
    PricingCalculator public pricing;

    uint256 ARB_BLOCK_NUMBER = 285331104;

    uint256 constant PRICING_SCALING_FACTOR = 1e18;
    uint256 constant PRICING_MIN_PRICE = 1;

    uint256 MAX_COST_UNIT = 163840;

    uint256 CHUNK_COST_UNIT = 10;
    uint256 GRAPH_ENTRY_COST_UNIT = 1;
    uint256 SCRATCHPAD_COST_UNIT = 100;
    uint256 POINTER_COST_UNIT = 20;

    IPaymentVault.DataType[] public dataTypes;
    uint256[] public costUnits;

    function setUp() public {
        vm.startPrank(dev);

        forkArbitrum(ARB_BLOCK_NUMBER);
        selectArbitrum();

        ant = new DummyToken("Test ANT Token", "ANT");

        // deploy pricing calculator with proxy
        PricingCalculator newPricingImpl = new PricingCalculator();
        bytes memory pricingInitData =
            abi.encodeCall(PricingCalculator.initialize, (PRICING_SCALING_FACTOR, PRICING_MIN_PRICE, MAX_COST_UNIT));

        ERC1967Proxy pricingProxy = new ERC1967Proxy(address(newPricingImpl), pricingInitData);
        pricing = PricingCalculator(address(pricingProxy));

        dataTypes.push(IPaymentVault.DataType.GraphEntry);
        dataTypes.push(IPaymentVault.DataType.Scratchpad);
        dataTypes.push(IPaymentVault.DataType.Chunk);
        dataTypes.push(IPaymentVault.DataType.Pointer);

        costUnits.push(GRAPH_ENTRY_COST_UNIT);
        costUnits.push(SCRATCHPAD_COST_UNIT);
        costUnits.push(CHUNK_COST_UNIT);
        costUnits.push(POINTER_COST_UNIT);

        pricing.setCostUnitForDataTypes(dataTypes, costUnits);

        // set up payment vault with proxy
        PaymentVault newVaultImpl = new PaymentVault();

        // initialize
        bytes memory vaultInitData = abi.encodeCall(
            PaymentVault.initialize,
            (
                ant,
                512,
                AggregatorV3Interface(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3),
                AggregatorV3Interface(address(0)),
                pricing
            )
        );

        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(newVaultImpl), vaultInitData);
        vault = PaymentVault(address(vaultProxy));

        ant.approve(address(vault), type(uint256).max);

        // verify that all values are initialized correctly
        assertEq(pricing.scalingFactor(), 1e18);
        assertEq(pricing.minPrice(), 1);

        assertEq(vault.batchLimit(), 512);

        assertEq(address(vault.antToken()), address(ant));
        assertEq(address(vault.priceFeed()), 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3);
        assertEq(address(vault.sequencerUptimeFeed()), address(0));
        assertEq(address(vault.pricingCalculator()), address(pricing));

        vm.stopPrank();
    }

    function test_proxyUpgrade() public {
        vm.startPrank(dev);

        PaymentVault newVaultImpl = new PaymentVault();

        vault.upgradeToAndCall(address(newVaultImpl), "");

        vm.stopPrank();
    }

    function test_getQuote() public view {
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

        IPaymentVault.QuotingMetrics[] memory _metrics = new IPaymentVault.QuotingMetrics[](1);
        _metrics[0] = testMetrics;

        uint256[] memory _prices = vault.getQuote(_metrics);

        console.log("price: ", _prices[0]);
        assertEq(55882007, _prices[0]);
    }

    function test_payForQuotes_quoteHashZero() public {
        vm.startPrank(dev);
        IPaymentVault.DataPayment[] memory _dataPayments = new IPaymentVault.DataPayment[](1);

        _dataPayments[0] = IPaymentVault.DataPayment({
            relayNodeAddress: address(0),
            rewardsAddress: users[1],
            amount: 10 ether,
            quoteHash: bytes32(0)
        });

        vault.payForQuotes(_dataPayments);

        (bytes16 rewardsAddress, uint128 rewardsAddressAmount, bytes16 relayNodeAddress, uint128 relayNodeAmount) =
            vault.completedPayments(bytes32(0));
        assertEq(rewardsAddressAmount, 0);
        assertEq(rewardsAddress, bytes16(0));
        assertEq(relayNodeAmount, 0);
        assertEq(relayNodeAddress, bytes16(0));

        assertEq(ant.balanceOf(users[1]), 10 ether);

        vm.stopPrank();
    }

    function test_payForQuotes_relayNodeZero() public {
        vm.startPrank(dev);

        IPaymentVault.DataPayment[] memory _dataPayments = new IPaymentVault.DataPayment[](1);
        _dataPayments[0] = IPaymentVault.DataPayment({
            relayNodeAddress: address(0),
            rewardsAddress: users[1],
            amount: 10 ether,
            quoteHash: bytes32("asd")
        });

        vm.expectEmit(true, true, true, false);
        emit IPaymentVault.DataPaymentMade(users[1], 10 ether, bytes32("asd"));
        vault.payForQuotes(_dataPayments);

        (bytes16 rewardsAddress, uint128 rewardsAddressAmount, bytes16 relayNodeAddress, uint128 relayNodeAmount) =
            vault.completedPayments(bytes32("asd"));

        assertEq(ant.balanceOf(users[1]), 10 ether);
        assertEq(rewardsAddress, getFirst16Bytes(users[1]));
        assertEq(rewardsAddressAmount, 10 ether);
        assertEq(relayNodeAddress, bytes16(0));
        assertEq(relayNodeAmount, 0);

        vm.stopPrank();
    }

    function test_payForQuotes() public {
        vm.startPrank(dev);

        IPaymentVault.DataPayment[] memory _dataPayments = new IPaymentVault.DataPayment[](1);
        _dataPayments[0] = IPaymentVault.DataPayment({
            relayNodeAddress: users[2],
            rewardsAddress: users[1],
            amount: 10 ether,
            quoteHash: bytes32("asd")
        });

        vm.expectEmit(true, true, true, false);
        emit IPaymentVault.DataPaymentMade(users[1], 10 ether, bytes32("asd"));
        vault.payForQuotes(_dataPayments);

        (bytes16 rewardsAddress, uint128 rewardsAddressAmount, bytes16 relayNodeAddress, uint128 relayNodeAmount) =
            vault.completedPayments(bytes32("asd"));

        assertEq(ant.balanceOf(users[1]), 2.5 ether);
        assertEq(ant.balanceOf(users[2]), 7.5 ether);

        assertEq(rewardsAddress, getFirst16Bytes(users[1]));
        assertEq(relayNodeAddress, getFirst16Bytes(users[2]));
        assertEq(rewardsAddressAmount, 2.5 ether);
        assertEq(relayNodeAmount, 7.5 ether);

        vm.stopPrank();
    }

    function test_cannot_payForQuotes_batchLimitExceeded() public {
        vm.startPrank(dev);
        IPaymentVault.DataPayment[] memory _dataPayments = new IPaymentVault.DataPayment[](600);

        for (uint256 i = 0; i < _dataPayments.length; i++) {
            _dataPayments[i] = IPaymentVault.DataPayment({
                relayNodeAddress: users[2],
                rewardsAddress: users[1],
                amount: 10 ether,
                quoteHash: bytes32("asd")
            });
        }

        vm.expectRevert(IPaymentVault.BatchLimitExceeded.selector);
        vault.payForQuotes(_dataPayments);
        vm.stopPrank();
    }

    function test_verifyPayment_relayNodeZero() public {
        vm.startPrank(dev);
        // add 5 payments
        IPaymentVault.DataPayment[] memory _dataPayments = new IPaymentVault.DataPayment[](5);
        IPaymentVault.PaymentVerificationV2[] memory _paymentVerifications = new IPaymentVault.PaymentVerificationV2[](5);
        uint256 expectedPrice = 55882007;

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

        // all with equal prices
        for (uint256 i = 0; i < _dataPayments.length; i++) {
            _dataPayments[i] = IPaymentVault.DataPayment({
                relayNodeAddress: address(0),
                rewardsAddress: users[1],
                amount: expectedPrice,
                quoteHash: bytes32(i + 1)
            });

            _paymentVerifications[i] = IPaymentVault.PaymentVerificationV2({
                metrics: testMetrics,
                rewardsAddress: users[1],
                relayNodeAddress: address(0),
                quoteHash: bytes32(i + 1)
            });
        }

        // pay
        vault.payForQuotes(_dataPayments);

        // verify payment
        IPaymentVault.PaymentVerificationResult[3] memory verificationResults =
            vault.verifyPaymentV2(_paymentVerifications);

        // check info
        for (uint256 i = 0; i < verificationResults.length; i++) {
            assertEq(verificationResults[i].quoteHash, bytes32(i + 1));
            assertEq(verificationResults[i].amountPaid, expectedPrice);
            assertEq(verificationResults[i].isValid, true);
        }

        // all with different prices
        uint256 _expPrice1 = 93137244;
        uint256 _expPrice2 = 130392922;
        uint256 _expPrice3 = 167649065;
        uint256 _expPrice4 = 204905658;
        uint256 _expPrice5 = 242162711;

        uint256[] memory _expectedPrices = new uint256[](5);
        _expectedPrices[0] = _expPrice1;
        _expectedPrices[1] = _expPrice2;
        _expectedPrices[2] = _expPrice3;
        _expectedPrices[3] = _expPrice4;
        _expectedPrices[4] = _expPrice5;

        // add another 5 payment
        for (uint256 i = 0; i < _dataPayments.length; i++) {
            records = new IPaymentVault.Record[](1);
            records[0] = IPaymentVault.Record({dataType: IPaymentVault.DataType.GraphEntry, records: i + 2});

            testMetrics = IPaymentVault.QuotingMetrics({
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

            _dataPayments[i] = IPaymentVault.DataPayment({
                relayNodeAddress: address(0),
                rewardsAddress: users[1],
                amount: _expectedPrices[i],
                quoteHash: bytes32(i + 1)
            });

            _paymentVerifications[i] = IPaymentVault.PaymentVerificationV2({
                metrics: testMetrics,
                rewardsAddress: users[1],
                relayNodeAddress: address(0),
                quoteHash: bytes32(i + 1)
            });
        }

        // pay
        vault.payForQuotes(_dataPayments);

        // verify payment
        verificationResults = vault.verifyPaymentV2(_paymentVerifications);

        // check info
        for (uint256 i = 0; i < verificationResults.length; i++) {
            // verify them
            assertEq(verificationResults[i].quoteHash, bytes32(_expectedPrices.length - i));
            assertEq(verificationResults[i].amountPaid, _expectedPrices[_expectedPrices.length - 1 - i]);
            assertEq(verificationResults[i].isValid, true);
        }

        vm.stopPrank();
    }

    function test_verifyPayment() public {
        vm.startPrank(dev);

        IPaymentVault.DataPayment[] memory _dataPayments = new IPaymentVault.DataPayment[](5);
        IPaymentVault.PaymentVerificationV2[] memory _paymentVerifications = new IPaymentVault.PaymentVerificationV2[](5);
        uint256 expectedPrice = 55882007;

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

        // all with equal prices
        for (uint256 i = 0; i < _dataPayments.length; i++) {
            _dataPayments[i] = IPaymentVault.DataPayment({
                relayNodeAddress: users[2],
                rewardsAddress: users[1],
                amount: expectedPrice,
                quoteHash: bytes32(i + 1)
            });

            _paymentVerifications[i] = IPaymentVault.PaymentVerificationV2({
                metrics: testMetrics,
                rewardsAddress: users[1],
                relayNodeAddress: users[2],
                quoteHash: bytes32(i + 1)
            });
        }

        // pay
        vault.payForQuotes(_dataPayments);

        // verify payment
        IPaymentVault.PaymentVerificationResult[3] memory verificationResults =
            vault.verifyPaymentV2(_paymentVerifications);

        // check info
        for (uint256 i = 0; i < verificationResults.length; i++) {
            assertEq(verificationResults[i].quoteHash, bytes32(i + 1));
            assertEq(verificationResults[i].amountPaid, expectedPrice);
            assertEq(verificationResults[i].isValid, true);
        }

        // all with different prices
        uint256 _expPrice1 = 93137244;
        uint256 _expPrice2 = 130392922;
        uint256 _expPrice3 = 167649065;
        uint256 _expPrice4 = 204905658;
        uint256 _expPrice5 = 242162711;

        uint256[] memory _expectedPrices = new uint256[](5);
        _expectedPrices[0] = _expPrice1;
        _expectedPrices[1] = _expPrice2;
        _expectedPrices[2] = _expPrice3;
        _expectedPrices[3] = _expPrice4;
        _expectedPrices[4] = _expPrice5;

        // add another 5 payment
        for (uint256 i = 0; i < _dataPayments.length; i++) {
            records = new IPaymentVault.Record[](1);
            records[0] = IPaymentVault.Record({dataType: IPaymentVault.DataType.GraphEntry, records: i + 2});

            testMetrics = IPaymentVault.QuotingMetrics({
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

            _dataPayments[i] = IPaymentVault.DataPayment({
                relayNodeAddress: users[2],
                rewardsAddress: users[1],
                amount: _expectedPrices[i],
                quoteHash: bytes32(i + 1)
            });

            _paymentVerifications[i] = IPaymentVault.PaymentVerificationV2({
                metrics: testMetrics,
                rewardsAddress: users[1],
                relayNodeAddress: users[2],
                quoteHash: bytes32(i + 1)
            });
        }

        // pay
        vault.payForQuotes(_dataPayments);

        // verify payment
        verificationResults = vault.verifyPaymentV2(_paymentVerifications);

        // check info
        for (uint256 i = 0; i < verificationResults.length; i++) {
            // verify them
            assertEq(verificationResults[i].quoteHash, bytes32(_expectedPrices.length - i));
            assertEq(verificationResults[i].amountPaid, _expectedPrices[_expectedPrices.length - 1 - i]);
            assertEq(verificationResults[i].isValid, true);
        }

        vm.stopPrank();
    }

    function test_cannot_verifyPayment_invalidInputLength() public {
        vm.startPrank(dev);

        IPaymentVault.DataPayment[] memory _dataPayments = new IPaymentVault.DataPayment[](4);
        IPaymentVault.PaymentVerificationV2[] memory _paymentVerifications = new IPaymentVault.PaymentVerificationV2[](4);
        uint256 expectedPrice = 55882007;

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

        // all with equal prices
        for (uint256 i = 0; i < _dataPayments.length; i++) {
            _dataPayments[i] = IPaymentVault.DataPayment({
                relayNodeAddress: users[2],
                rewardsAddress: users[1],
                amount: expectedPrice,
                quoteHash: bytes32(i + 1)
            });

            _paymentVerifications[i] = IPaymentVault.PaymentVerificationV2({
                metrics: testMetrics,
                rewardsAddress: users[1],
                relayNodeAddress: users[2],
                quoteHash: bytes32(i + 1)
            });
        }

        // pay
        vault.payForQuotes(_dataPayments);

        // verify payment
        vm.expectRevert(IPaymentVault.InvalidInputLength.selector);
        vault.verifyPaymentV2(_paymentVerifications);

        vm.stopPrank();
    }

    function test_cannot_verifyPayment_relayNodeZero_amountNotOk() public {
        vm.startPrank(dev);
        // add 5 payments
        IPaymentVault.DataPayment[] memory _dataPayments = new IPaymentVault.DataPayment[](5);
        IPaymentVault.PaymentVerificationV2[] memory _paymentVerifications = new IPaymentVault.PaymentVerificationV2[](5);
        uint256 wrongPrice = 15882007;

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

        // all with equal prices
        for (uint256 i = 0; i < _dataPayments.length; i++) {
            _dataPayments[i] = IPaymentVault.DataPayment({
                relayNodeAddress: address(0),
                rewardsAddress: users[1],
                amount: wrongPrice,
                quoteHash: bytes32(i + 1)
            });

            _paymentVerifications[i] = IPaymentVault.PaymentVerificationV2({
                metrics: testMetrics,
                rewardsAddress: users[1],
                relayNodeAddress: address(0),
                quoteHash: bytes32(i + 1)
            });
        }

        vault.payForQuotes(_dataPayments);

        IPaymentVault.PaymentVerificationResult[3] memory verificationResults =
            vault.verifyPaymentV2(_paymentVerifications);

        for (uint256 i = 0; i < verificationResults.length; i++) {
            assertEq(verificationResults[i].quoteHash, bytes32(i + 1));
            assertEq(verificationResults[i].amountPaid, wrongPrice);
            assertEq(verificationResults[i].isValid, false);
        }

        vm.stopPrank();
    }

    function test_cannot_verify_payment_relayNodeZero_addressNotOk() public {
        vm.startPrank(dev);
        // add 5 payments
        IPaymentVault.DataPayment[] memory _dataPayments = new IPaymentVault.DataPayment[](5);
        IPaymentVault.PaymentVerificationV2[] memory _paymentVerifications = new IPaymentVault.PaymentVerificationV2[](5);
        uint256 expectedPrice = 55882007;

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

        // all with equal prices
        for (uint256 i = 0; i < _dataPayments.length; i++) {
            _dataPayments[i] = IPaymentVault.DataPayment({
                relayNodeAddress: address(0),
                rewardsAddress: users[1],
                amount: expectedPrice,
                quoteHash: bytes32(i + 1)
            });

            _paymentVerifications[i] = IPaymentVault.PaymentVerificationV2({
                metrics: testMetrics,
                rewardsAddress: users[3],
                relayNodeAddress: address(0),
                quoteHash: bytes32(i + 1)
            });
        }

        vault.payForQuotes(_dataPayments);

        IPaymentVault.PaymentVerificationResult[3] memory verificationResults =
            vault.verifyPaymentV2(_paymentVerifications);

        for (uint256 i = 0; i < verificationResults.length; i++) {
            assertEq(verificationResults[i].quoteHash, bytes32(i + 1));
            assertEq(verificationResults[i].amountPaid, expectedPrice);
            assertEq(verificationResults[i].isValid, false);
        }

        vm.stopPrank();
    }

    function test_cannot_verify_payment_amountNotOk() public {
        vm.startPrank(dev);

        IPaymentVault.DataPayment[] memory _dataPayments = new IPaymentVault.DataPayment[](5);
        IPaymentVault.PaymentVerificationV2[] memory _paymentVerifications = new IPaymentVault.PaymentVerificationV2[](5);
        uint256 wrongPrice = 15882007;

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

        // all with equal prices
        for (uint256 i = 0; i < _dataPayments.length; i++) {
            _dataPayments[i] = IPaymentVault.DataPayment({
                relayNodeAddress: users[2],
                rewardsAddress: users[1],
                amount: wrongPrice,
                quoteHash: bytes32(i + 1)
            });

            _paymentVerifications[i] = IPaymentVault.PaymentVerificationV2({
                metrics: testMetrics,
                rewardsAddress: users[1],
                relayNodeAddress: users[2],
                quoteHash: bytes32(i + 1)
            });
        }

        // pay
        vault.payForQuotes(_dataPayments);

        // verify payment
        IPaymentVault.PaymentVerificationResult[3] memory verificationResults =
            vault.verifyPaymentV2(_paymentVerifications);

        // check info
        for (uint256 i = 0; i < verificationResults.length; i++) {
            assertEq(verificationResults[i].quoteHash, bytes32(i + 1));
            assertEq(verificationResults[i].amountPaid, wrongPrice);
            assertEq(verificationResults[i].isValid, false);
        }

        vm.stopPrank();
    }

    function test_cannot_verify_payment_addressNotOk() public {
        vm.startPrank(dev);

        IPaymentVault.DataPayment[] memory _dataPayments = new IPaymentVault.DataPayment[](5);
        IPaymentVault.PaymentVerificationV2[] memory _paymentVerifications = new IPaymentVault.PaymentVerificationV2[](5);
        uint256 expectedPrice = 55882007;

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

        // all with equal prices
        for (uint256 i = 0; i < _dataPayments.length; i++) {
            _dataPayments[i] = IPaymentVault.DataPayment({
                relayNodeAddress: users[2],
                rewardsAddress: users[1],
                amount: expectedPrice,
                quoteHash: bytes32(i + 1)
            });

            _paymentVerifications[i] = IPaymentVault.PaymentVerificationV2({
                metrics: testMetrics,
                rewardsAddress: users[2],
                relayNodeAddress: users[3],
                quoteHash: bytes32(i + 1)
            });
        }

        // pay
        vault.payForQuotes(_dataPayments);

        // verify payment
        IPaymentVault.PaymentVerificationResult[3] memory verificationResults =
            vault.verifyPaymentV2(_paymentVerifications);

        // check info
        for (uint256 i = 0; i < verificationResults.length; i++) {
            assertEq(verificationResults[i].quoteHash, bytes32(i + 1));
            assertEq(verificationResults[i].amountPaid, expectedPrice);
            assertEq(verificationResults[i].isValid, false);
        }

        vm.stopPrank();
    }

    function test_verifyPayment_old_relayerNodeZero() public {
        vm.startPrank(dev);
        // add 5 payments
        IPaymentVault.DataPayment[] memory _dataPayments = new IPaymentVault.DataPayment[](5);
        IPaymentVault.PaymentVerification[] memory _paymentVerifications = new IPaymentVault.PaymentVerification[](5);
        uint256 expectedPrice = 55882007;

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

        // all with equal prices
        for (uint256 i = 0; i < _dataPayments.length; i++) {
            _dataPayments[i] = IPaymentVault.DataPayment({
                relayNodeAddress: address(0),
                rewardsAddress: users[1],
                amount: expectedPrice,
                quoteHash: bytes32(i + 1)
            });

            _paymentVerifications[i] = IPaymentVault.PaymentVerification({
                metrics: testMetrics,
                rewardsAddress: users[1],
                quoteHash: bytes32(i + 1)
            });
        }

        vault.payForQuotes(_dataPayments);

        IPaymentVault.PaymentVerificationResult[3] memory verificationResults =
            vault.verifyPayment(_paymentVerifications);

        // check info
        for (uint256 i = 0; i < verificationResults.length; i++) {
            assertEq(verificationResults[i].quoteHash, bytes32(i + 1));
            assertEq(verificationResults[i].amountPaid, expectedPrice);
            assertEq(verificationResults[i].isValid, true);
        }
    }

    function test_verifyPayment_old() public {
        vm.startPrank(dev);

        IPaymentVault.DataPayment[] memory _dataPayments = new IPaymentVault.DataPayment[](5);
        IPaymentVault.PaymentVerification[] memory _paymentVerifications = new IPaymentVault.PaymentVerification[](5);
        uint256 expectedPrice = 55882007;

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

        // all with equal prices
        for (uint256 i = 0; i < _dataPayments.length; i++) {
            _dataPayments[i] = IPaymentVault.DataPayment({
                relayNodeAddress: users[2],
                rewardsAddress: users[1],
                amount: expectedPrice,
                quoteHash: bytes32(i + 1)
            });

            _paymentVerifications[i] = IPaymentVault.PaymentVerification({
                metrics: testMetrics,
                rewardsAddress: users[1],
                quoteHash: bytes32(i + 1)
            });
        }

        // pay
        vault.payForQuotes(_dataPayments);

        // verify payment
        IPaymentVault.PaymentVerificationResult[3] memory verificationResults =
            vault.verifyPayment(_paymentVerifications);

        // check info
        for (uint256 i = 0; i < verificationResults.length; i++) {
            assertEq(verificationResults[i].quoteHash, bytes32(i + 1));
            assertEq(verificationResults[i].amountPaid, expectedPrice);
            assertEq(verificationResults[i].isValid, true);
        }
    }

    function test_setRequiredPaymentVerificationLength() public {
        vm.startPrank(dev);
        vault.setRequiredPaymentVerificationLength(1);
        assertEq(vault.requiredPaymentVerificationLength(), 1);
        vm.stopPrank();
    }

    function test_cannot_setRequiredPaymentVerificationLength_notOwner() public {
        vm.expectRevert();
        vault.setRequiredPaymentVerificationLength(1);
    }

    function test_setPriceFeed() public {
        vm.startPrank(dev);
        vault.setPriceFeed(AggregatorV3Interface(users[2]));
        assertEq(address(vault.priceFeed()), users[2]);
        vm.stopPrank();
    }

    function test_cannot_setPriceFeed_notOwner() public {
        vm.expectRevert();
        vault.setPriceFeed(AggregatorV3Interface(users[2]));
    }

    function test_setSequencerUptimeFeed() public {
        vm.startPrank(dev);
        vault.setSequencerUptimeFeed(AggregatorV3Interface(users[2]));
        assertEq(address(vault.sequencerUptimeFeed()), users[2]);
        vm.stopPrank();
    }

    function test_cannot_setSequencerUptimeFeed_notOwner() public {
        vm.expectRevert();
        vault.setSequencerUptimeFeed(AggregatorV3Interface(users[2]));
    }

    function test_setPricingCalculator() public {
        vm.startPrank(dev);

        vault.setPricingCalculator(IPricingCalculator(users[2]));
        assertEq(address(vault.pricingCalculator()), users[2]);

        vm.stopPrank();
    }

    function test_cannot_setPricingCalculator_notOwner() public {
        vm.expectRevert();
        vault.setPricingCalculator(IPricingCalculator(users[2]));
    }

    function test_setBatchLimit() public {
        vm.startPrank(dev);
        vault.setBatchLimit(42);
        assertEq(vault.batchLimit(), 42);
        vm.stopPrank();
    }

    function test_cannot_setBatchLimit_notOwner() public {
        vm.expectRevert();
        vault.setBatchLimit(0);
    }

    function test_getLatestPrice() public view {
        (, int256 latestPrice) = vault.getLatestPrice();
        int256 oneEtherInt = 1 ether;
        assertApproxEqAbs(oneEtherInt, latestPrice, 0.001 ether);
    }

    function test_getPriceForRoundID() public view {
        int256 price = vault.getPriceForRoundID(18446744073709556593);
        int256 oneEtherInt = 1 ether;
        assertApproxEqAbs(oneEtherInt, price, 0.001 ether);
    }

    function getFirst16Bytes(address addr) internal pure returns (bytes16) {
        return bytes16(uint128(uint160(addr) >> 32));
    }

    function toHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";

        uint256 length = data.length;
        bytes memory str = new bytes(2 + length * 2);
        str[0] = "0";
        str[1] = "x";

        for (uint256 i = 0; i < length; i++) {
            str[2 + i * 2] = alphabet[uint8(data[i] >> 4) & 0xf];
            str[3 + i * 2] = alphabet[uint8(data[i]) & 0xf];
        }

        return string(str);
    }

    function bytes32ToHexString(bytes32 buffer) internal pure returns (string memory) {
        bytes memory converted = new bytes(buffer.length * 2);
        bytes memory _base = "0123456789abcdef";
        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }
        return string(abi.encodePacked("0x", converted));
    }
}
