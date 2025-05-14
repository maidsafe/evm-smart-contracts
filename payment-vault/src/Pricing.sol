// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./IPricing.sol";
import {IPaymentVault} from "./IPaymentVault.sol";
import "@prb/math/src/SD59x18.sol";

/**
 * @title PricingCalculator
 * @dev Implements a pricing function based on the formula:
 * -s/ANT(ln(rCostUnit0 - 1) - ln(rCostUnit1 - 1)) - 1/ANT(rCostUnit1 - rCostUnit0) + pMin(rCostUnit1 - rCostUnit0)
 *
 * The math is detailed here: https://lajosdeme.notion.site/variable-pricing-formula-analytical-solution-18e1a854401f809297e5e6acfd886055?pvs=4
 */
contract PricingCalculator is IPricingCalculator, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    error AntPriceZero();
    error RecordMaxZero();

    uint256 public scalingFactor = 1e18;
    uint256 public minPrice = 1;

    // proxy update 1 //
    uint256 public constant PRECISION = 1e18;

    uint256 public maxCostUnit;

    mapping(IPaymentVault.DataType => uint256) public costUnitPerDataType;

    error InvalidBounds();
    error InvalidPrice();
    // proxy update 1 //

    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 _scalingFactor, uint256 _minPrice, uint256 _maxCostUnit) external initializer {
        scalingFactor = _scalingFactor;
        minPrice = _minPrice;

        maxCostUnit = _maxCostUnit;

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function getTotalCostUnit(IPaymentVault.QuotingMetrics memory metrics)
        public
        view
        returns (uint256 totalCostUnit)
    {
        // loop through the records
        for (uint256 i = 0; i < metrics.recordsPerType.length; i++) {
            IPaymentVault.Record memory _record = metrics.recordsPerType[i];
            // get cost unit for data type
            uint256 _costUnit = costUnitPerDataType[_record.dataType];
            // multiply by records count and sum all of them up
            totalCostUnit += _costUnit * _record.records;
        }
    }

    function calculatePrice(uint256 antPrice, IPaymentVault.QuotingMetrics memory metrics)
        public
        view
        returns (uint256)
    {
        uint256 totalCostUnit = getTotalCostUnit(metrics);
        uint256 _lowerBound = _getLowerBound(totalCostUnit);
        uint256 _upperBound = _getUpperBound(totalCostUnit, metrics.dataType);

        if (_lowerBound == _upperBound) {
            revert InvalidBounds();
        }

        if (_lowerBound == 1e18 || _upperBound == 1e18) {
            revert InvalidBounds();
        }

        // Calculate the logarithmic part: ln|r_CostUnit_1 - 1| - ln|r_CostUnit_0 - 1|
        int256 log_part = calculateLnSigned(int256(absDiff(_upperBound, 1e18)))
            - calculateLnSigned(int256(absDiff(_lowerBound, 1e18)));

        // Calculate the linear part: r_CostUnit_1 - r_CostUnit_0
        uint256 linear_part = _upperBound - _lowerBound;

        // Logarithmic term: (-s / ANT) * log_part
        int256 _partOne = (-int256(scalingFactor) * log_part) / int256(antPrice);
        // Linear term from p_min
        uint256 _partTwo = (linear_part * minPrice) / PRECISION;
        // Linear term from (-1 / ANT)
        uint256 _partThree = (linear_part * PRECISION) / antPrice;

        int256 price = _partOne + int256(_partTwo) - int256(_partThree);

        if (price < 0) {
            revert InvalidPrice();
        }

        return uint256(price);
    }

    function calculateLnSigned(int256 x) public pure returns (int256) {
        SD59x18 fixedX = SD59x18.wrap(x);
        return SD59x18.unwrap(fixedX.ln());
    }

    // Helper function to calculate the absolute difference
    function absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function _getLowerBound(uint256 totalCostUnit) internal view returns (uint256) {
        return (totalCostUnit * 1e18) / maxCostUnit;
    }

    function _getUpperBound(uint256 totalCostUnit, IPaymentVault.DataType dataType) internal view returns (uint256) {
        uint256 _newTotalCostUnit = totalCostUnit + costUnitPerDataType[dataType];
        uint256 upperBound = (_newTotalCostUnit * 1e18) / maxCostUnit;
        if (upperBound == 1e18) {
            ++upperBound;
        }
        return upperBound;
    }

    function setScalingFactor(uint256 newScalingFactor) external onlyOwner {
        scalingFactor = newScalingFactor;
    }

    function setMinPrice(uint256 newMinPrice) external onlyOwner {
        minPrice = newMinPrice;
    }

    function setMaxCostUnit(uint256 _maxCostUnit) external onlyOwner {
        maxCostUnit = _maxCostUnit;
    }

    function setCostUnitPerDataType(IPaymentVault.DataType dataType, uint256 costUnit) external onlyOwner {
        costUnitPerDataType[dataType] = costUnit;
    }

    function setCostUnitForDataTypes(IPaymentVault.DataType[] calldata dataTypes, uint256[] calldata costUnits)
        external
        onlyOwner
    {
        if (dataTypes.length != costUnits.length) {
            revert("InvalidArrayLength");
        }
        for (uint256 i = 0; i < dataTypes.length; i++) {
            costUnitPerDataType[dataTypes[i]] = costUnits[i];
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
