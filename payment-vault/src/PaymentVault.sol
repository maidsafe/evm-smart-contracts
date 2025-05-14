// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./IPaymentVault.sol";
import "./IPricing.sol";

/*
- for testing use USDC/USD 
    - 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3 (Arb One)
    - 0x0153002d20B96532C639313c2d54c3dA09109309 (Arb Sepolia)
*/

contract PaymentVault is IPaymentVault, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public batchLimit;

    IERC20 public antToken;

    // mapping(bytes32 => DataPayment) public payments;

    // proxy update 1 //
    uint256 public requiredPaymentVerificationLength;
    // proxy update 1 //

    // proxy update 2 //
    uint256 private constant SEQUENCER_UPTIME_GRACE_PERIOD = 3600;
    AggregatorV3Interface public priceFeed;
    AggregatorV3Interface public sequencerUptimeFeed;
    IPricingCalculator public pricingCalculator;
    mapping(bytes32 => uint80) public roundIds;
    // proxy update 2 //

    // proxy update 3 //
    mapping(bytes32 => Payment) public completedPayments;
    // proxy update 3 //

    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 _antToken,
        uint256 _batchLimit,
        AggregatorV3Interface _priceFeed,
        AggregatorV3Interface _sequencerUptimeFeed,
        IPricingCalculator _pricingCalculator
    ) external initializer {
        if (address(_antToken) == address(0)) {
            revert AntTokenNull();
        }

        if (address(_priceFeed) == address(0)) {
            revert PriceFeedNull();
        }

        antToken = _antToken;
        batchLimit = _batchLimit;

        requiredPaymentVerificationLength = 5;

        priceFeed = _priceFeed;
        sequencerUptimeFeed = _sequencerUptimeFeed;
        pricingCalculator = _pricingCalculator;

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function getQuote(QuotingMetrics[] calldata _metrics) external view returns (uint256[] memory prices) {
        (, int256 latestPrice) = getLatestPrice();
        if (latestPrice <= 0) {
            revert InvalidChainlinkPrice();
        }

        uint256[] memory _prices = new uint256[](_metrics.length);

        for (uint256 i = 0; i < _metrics.length; i++) {
            uint256 _price = pricingCalculator.calculatePrice(uint256(latestPrice), _metrics[i]);
            _prices[i] = _price;
        }

        prices = _prices;
    }

    function payForQuotes(DataPayment[] calldata _payments) external {
        uint256 paymentsLen = _payments.length;

        if (paymentsLen > batchLimit) {
            revert BatchLimitExceeded();
        }

        // Record the roundID for the given quote hash
        (uint80 roundId,) = getLatestPrice();

        for (uint256 i = 0; i < paymentsLen; i++) {
            DataPayment calldata dataPayment = _payments[i];

            if (dataPayment.quoteHash == bytes32(0)) {
                antToken.safeTransferFrom(msg.sender, dataPayment.rewardsAddress, dataPayment.amount);
                continue;
            }

            if (dataPayment.relayNodeAddress == address(0)) {
                antToken.safeTransferFrom(msg.sender, dataPayment.rewardsAddress, dataPayment.amount);

                completedPayments[dataPayment.quoteHash] = Payment({
                    rewardsAddress: getFirst16Bytes(dataPayment.rewardsAddress),
                    rewardsAddressAmount: uint128(dataPayment.amount),
                    relayNodeAddress: bytes16(0),
                    relayNodeAmount: 0
                });
            } else {
                uint256 relayNodeAmount = (dataPayment.amount * 75) / 100; // 75%
                uint256 rewardsAddressAmount = dataPayment.amount - relayNodeAmount; // 25%

                // pay the relay node
                antToken.safeTransferFrom(msg.sender, dataPayment.relayNodeAddress, relayNodeAmount);

                // pay the node
                antToken.safeTransferFrom(msg.sender, dataPayment.rewardsAddress, rewardsAddressAmount);

                completedPayments[dataPayment.quoteHash] = Payment({
                    rewardsAddress: getFirst16Bytes(dataPayment.rewardsAddress),
                    rewardsAddressAmount: uint128(rewardsAddressAmount),
                    relayNodeAddress: getFirst16Bytes(dataPayment.relayNodeAddress),
                    relayNodeAmount: uint128(relayNodeAmount)
                });
            }

            roundIds[dataPayment.quoteHash] = roundId;

            emit DataPaymentMade(dataPayment.rewardsAddress, dataPayment.amount, dataPayment.quoteHash);
        }
    }

    function verifyPaymentV2(PaymentVerificationV2[] calldata _payments)
        external
        view
        returns (PaymentVerificationResult[3] memory verificationResults)
    {
        // verify that the length of the _payments is what is required
        if (_payments.length != requiredPaymentVerificationLength) {
            revert InvalidInputLength();
        }

        // go through them and get the 3 with the highest price
        PaymentVerificationV2[3] memory selectedPayments = selectTopPayments(_payments);

        // verify that those are paid
        for (uint256 i = 0; i < selectedPayments.length; i++) {
            Payment memory dataPayment = completedPayments[selectedPayments[i].quoteHash];

            // Get the round ID for the given quote hash
            uint80 _roundId = roundIds[selectedPayments[i].quoteHash];
            if (_roundId == 0) {
                verificationResults[i] =
                    PaymentVerificationResult({quoteHash: bytes32(0), amountPaid: 0, isValid: false});

                continue;
            }

            // Get the ANT price for the given round ID
            int256 _price = getPriceForRoundID(_roundId);

            // Calculate the expected price for the given input
            uint256 expectedPrice = pricingCalculator.calculatePrice(uint256(_price), selectedPayments[i].metrics);

            // Verify that the required amount of ANT was actually paid
            // check that the recorded payment has a relay address or not
            if (dataPayment.relayNodeAddress == bytes16(0)) {
                // if relay address is zero execute the previous logic
                bool isAmountOk =
                    (dataPayment.rewardsAddressAmount != 0) && (dataPayment.rewardsAddressAmount >= expectedPrice);

                bool isAddressOk = dataPayment.rewardsAddress == getFirst16Bytes(selectedPayments[i].rewardsAddress)
                    && (selectedPayments[i].rewardsAddress != address(0));

                PaymentVerificationResult memory _verificationResult = PaymentVerificationResult({
                    quoteHash: selectedPayments[i].quoteHash,
                    amountPaid: dataPayment.rewardsAddressAmount,
                    isValid: isAmountOk && isAddressOk
                });

                verificationResults[i] = _verificationResult;
            } else {
                // if relay address is something calculate 75% and 25% of the expected price
                uint256 expectedRelayNodeAmount = (expectedPrice * 75) / 100;

                uint256 expectedRewardsAddressAmount = expectedPrice - expectedRelayNodeAmount;
                // verify for both that the amount that was actually paid is is greater or equal to the corresponding percentages
                bool isRelayNodeAmountOk =
                    (dataPayment.relayNodeAmount != 0) && (dataPayment.relayNodeAmount >= expectedRelayNodeAmount);

                bool isRewardsAddressAmountOk = (dataPayment.rewardsAddressAmount != 0)
                    && (dataPayment.rewardsAddressAmount >= expectedRewardsAddressAmount);

                // verify that the addresses are set correctly
                bool isRelayNodeAddressOk = dataPayment.relayNodeAddress
                    == getFirst16Bytes(selectedPayments[i].relayNodeAddress)
                    && (selectedPayments[i].relayNodeAddress != address(0));

                bool isRewardsAddressOk = dataPayment.rewardsAddress
                    == getFirst16Bytes(selectedPayments[i].rewardsAddress)
                    && (selectedPayments[i].rewardsAddress != address(0));

                PaymentVerificationResult memory _verificationResult = PaymentVerificationResult({
                    quoteHash: selectedPayments[i].quoteHash,
                    amountPaid: dataPayment.rewardsAddressAmount + dataPayment.relayNodeAmount,
                    isValid: (isRelayNodeAmountOk && isRewardsAddressAmountOk)
                        && (isRelayNodeAddressOk && isRewardsAddressOk)
                });
                verificationResults[i] = _verificationResult;
            }
        }
    }

    function verifyPayment(PaymentVerification[] calldata _payments)
        external
        view
        returns (PaymentVerificationResult[3] memory verificationResults)
    {
        // verify that the length of the _payments is what is required
        if (_payments.length != requiredPaymentVerificationLength) {
            revert InvalidInputLength();
        }

        // go through them and get the 3 with the highest price
        PaymentVerification[3] memory selectedPayments = selectTopPaymentsOld(_payments);

        // verify that those are paid
        for (uint256 i = 0; i < selectedPayments.length; i++) {
            Payment memory dataPayment = completedPayments[selectedPayments[i].quoteHash];

            // Get the round ID for the given quote hash
            uint80 _roundId = roundIds[selectedPayments[i].quoteHash];
            if (_roundId == 0) {
                verificationResults[i] =
                    PaymentVerificationResult({quoteHash: bytes32(0), amountPaid: 0, isValid: false});

                continue;
            }

            // Get the ANT price for the given round ID
            int256 _price = getPriceForRoundID(_roundId);

            // Calculate the expected price for the given input
            uint256 expectedPrice = pricingCalculator.calculatePrice(uint256(_price), selectedPayments[i].metrics);

            bool isAmountOk;

            if (dataPayment.relayNodeAddress == bytes16(0)) {
                // if relay address is zero execute the previous logic
                isAmountOk =
                    (dataPayment.rewardsAddressAmount != 0) && (dataPayment.rewardsAddressAmount >= expectedPrice);
            } else {
                isAmountOk = (dataPayment.rewardsAddressAmount != 0 || dataPayment.relayNodeAmount != 0)
                    && (dataPayment.rewardsAddressAmount + dataPayment.relayNodeAmount >= expectedPrice);
            }

            bool isAddressOk = dataPayment.rewardsAddress == getFirst16Bytes(selectedPayments[i].rewardsAddress)
                && (selectedPayments[i].rewardsAddress != address(0));

            PaymentVerificationResult memory _verificationResult = PaymentVerificationResult({
                quoteHash: selectedPayments[i].quoteHash,
                amountPaid: dataPayment.rewardsAddressAmount + dataPayment.relayNodeAmount,
                isValid: isAmountOk && isAddressOk
            });

            verificationResults[i] = _verificationResult;
        }
    }

    function setRequiredPaymentVerificationLength(uint256 _requiredPaymentVerificationLength) external onlyOwner {
        requiredPaymentVerificationLength = _requiredPaymentVerificationLength;
    }

    function setPriceFeed(AggregatorV3Interface _priceFeed) external onlyOwner {
        priceFeed = _priceFeed;
    }

    function setSequencerUptimeFeed(AggregatorV3Interface _sequencerUptimeFeed) external onlyOwner {
        sequencerUptimeFeed = _sequencerUptimeFeed;
    }

    function setPricingCalculator(IPricingCalculator _pricingCalculator) external onlyOwner {
        pricingCalculator = _pricingCalculator;
    }

    function setBatchLimit(uint256 _batchLimit) external onlyOwner {
        batchLimit = _batchLimit;
    }

    function selectTopPayments(PaymentVerificationV2[] calldata _payments)
        internal
        view
        returns (PaymentVerificationV2[3] memory selectedPayments)
    {
        for (uint256 i = 0; i < _payments.length; i++) {
            Payment memory dataPayment = completedPayments[_payments[i].quoteHash];

            if (
                dataPayment.rewardsAddressAmount > completedPayments[selectedPayments[0].quoteHash].rewardsAddressAmount
            ) {
                selectedPayments[2] = selectedPayments[1];
                selectedPayments[1] = selectedPayments[0];
                selectedPayments[0] = _payments[i];
            } else if (
                dataPayment.rewardsAddressAmount > completedPayments[selectedPayments[1].quoteHash].rewardsAddressAmount
            ) {
                selectedPayments[2] = selectedPayments[1];
                selectedPayments[1] = _payments[i];
            } else if (
                dataPayment.rewardsAddressAmount > completedPayments[selectedPayments[2].quoteHash].rewardsAddressAmount
            ) {
                selectedPayments[2] = _payments[i];
            }
        }

        return selectedPayments;
    }

    function selectTopPaymentsOld(PaymentVerification[] calldata _payments)
        internal
        view
        returns (PaymentVerification[3] memory selectedPayments)
    {
        for (uint256 i = 0; i < _payments.length; i++) {
            Payment memory dataPayment = completedPayments[_payments[i].quoteHash];

            if (
                dataPayment.rewardsAddressAmount > completedPayments[selectedPayments[0].quoteHash].rewardsAddressAmount
            ) {
                selectedPayments[2] = selectedPayments[1];
                selectedPayments[1] = selectedPayments[0];
                selectedPayments[0] = _payments[i];
            } else if (
                dataPayment.rewardsAddressAmount > completedPayments[selectedPayments[1].quoteHash].rewardsAddressAmount
            ) {
                selectedPayments[2] = selectedPayments[1];
                selectedPayments[1] = _payments[i];
            } else if (
                dataPayment.rewardsAddressAmount > completedPayments[selectedPayments[2].quoteHash].rewardsAddressAmount
            ) {
                selectedPayments[2] = _payments[i];
            }
        }

        return selectedPayments;
    }

    function getLatestPrice() public view returns (uint80, int256) {
        _verifySequencerUptime();

        (
            uint80 roundID,
            int256 answer,
            /* uint startedAt */
            ,
            /* uint timeStamp */
            ,
            /* uint80 answeredInRound */
        ) = priceFeed.latestRoundData();

        uint8 _baseDecimals = priceFeed.decimals();
        int256 _scaledPrice = scalePrice(answer, _baseDecimals, 18);
        return (roundID, _scaledPrice);
    }

    function getPriceForRoundID(uint80 _roundId) public view returns (int256) {
        _verifySequencerUptime();

        (
            /* uint80 roundID */
            ,
            int256 answer,
            /* uint startedAt */
            ,
            /* uint timeStamp */
            ,
            /* uint80 answeredInRound */
        ) = priceFeed.getRoundData(_roundId);
        uint8 _baseDecimals = priceFeed.decimals();
        return scalePrice(answer, _baseDecimals, 18);
    }

    function _verifySequencerUptime() internal view {
        // Sequencer uptime feed is only available on mainnets. So for testnets the sequencer address will be 0 and we will skip this check.
        if (address(sequencerUptimeFeed) == address(0)) {
            return;
        }

        (
            /*uint80 roundID*/
            ,
            int256 answer,
            uint256 startedAt,
            /*uint256 updatedAt*/
            ,
            /*uint80 answeredInRound*/
        ) = sequencerUptimeFeed.latestRoundData();

        // Answer == 0: Sequencer is up
        // Answer == 1: Sequencer is down
        bool isSequencerUp = answer == 0;
        if (!isSequencerUp) {
            revert SequencerDown();
        }

        // Make sure the grace period has passed after the
        // sequencer is back up.
        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= SEQUENCER_UPTIME_GRACE_PERIOD) {
            revert GracePeriodNotOver();
        }
    }

    function getFirst16Bytes(address addr) internal pure returns (bytes16) {
        return bytes16(uint128(uint160(addr) >> 32));
    }

    function scalePrice(int256 _price, uint8 _priceDecimals, uint8 _decimals) internal pure returns (int256) {
        if (_priceDecimals < _decimals) {
            return _price * int256(10 ** uint256(_decimals - _priceDecimals));
        } else if (_priceDecimals > _decimals) {
            return _price / int256(10 ** uint256(_priceDecimals - _decimals));
        }
        return _price;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
