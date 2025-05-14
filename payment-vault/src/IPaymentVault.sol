// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPaymentVault {
    struct DataPayment {
        address relayNodeAddress;
        address rewardsAddress;
        uint256 amount;
        bytes32 quoteHash;
    }

    struct Payment {
        bytes16 rewardsAddress;
        uint128 rewardsAddressAmount;
        bytes16 relayNodeAddress;
        uint128 relayNodeAmount;
    }

    event DataPaymentMade(address indexed rewardsAddress, uint256 indexed amount, bytes32 indexed quoteHash);

    enum DataType {
        GraphEntry,
        Scratchpad,
        Chunk,
        Pointer
    }

    struct Record {
        DataType dataType;
        uint256 records;
    }

    struct QuotingMetrics {
        DataType dataType;
        uint256 dataSize;
        uint256 closeRecordsStored;
        Record[] recordsPerType;
        uint256 maxRecords;
        uint256 receivedPaymentCount;
        uint256 liveTime;
        uint256 networkDensity;
        uint256 networkSize;
    }

    struct CostUnit {
        uint256 costUnit;
        uint256 costUnitMax;
    }

    struct PaymentVerification {
        QuotingMetrics metrics;
        address rewardsAddress;
        bytes32 quoteHash;
    }

    struct PaymentVerificationV2 {
        QuotingMetrics metrics;
        address rewardsAddress;
        address relayNodeAddress;
        bytes32 quoteHash;
    }

    struct PaymentVerificationResult {
        bytes32 quoteHash;
        uint256 amountPaid;
        bool isValid;
    }

    error AntTokenNull();
    error BatchLimitExceeded();

    error InvalidInputLength();

    error PriceFeedNull();

    error InvalidChainlinkPrice();

    error SequencerDown();
    error GracePeriodNotOver();

    error InvalidQuoteHash();

    function getQuote(QuotingMetrics[] calldata _metrics) external view returns (uint256[] memory prices);

    function payForQuotes(DataPayment[] calldata _payments) external;

    function verifyPayment(PaymentVerification[] calldata _payments)
        external
        view
        returns (PaymentVerificationResult[3] memory verificationResults);

    function verifyPaymentV2(PaymentVerificationV2[] calldata _payments)
        external
        view
        returns (PaymentVerificationResult[3] memory verificationResults);
}
