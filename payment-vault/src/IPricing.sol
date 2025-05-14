// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPaymentVault} from "./IPaymentVault.sol";
interface IPricingCalculator {
    function calculatePrice(uint256 antPrice, IPaymentVault.QuotingMetrics memory metrics)
        external
        view
        returns (uint256);
}
