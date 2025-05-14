// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/* 
Please also see Emissions.csv supporting file column 1,2,3

50 year release schedule
total of 292,699,223 tokens

released according to the following schedule:
year 1 - 20% - already released at vesting start timestamp
year 2,3,4 - 8% every year
year 5 - 10%
year 6,7 - 8% every year
year 8 - 4%
year 9,10,11 - 3%
year 12 - 2%
year 13,14,15,16 - 1%
year 17 - 28 - 0.5%
year 29 - 40 - 0.25%
year 41 - 50 - 0.2%
 */
contract FoundationEmissions {
    using SafeERC20 for IERC20;

    // Tue Feb 11 2025 14:00:00 GMT+0000 - when ANT trading went live
    uint256 public constant VESTING_START_TIMESTAMP = 1739282400;

    uint256 public constant BASE_VESTING_PERIOD = 365 days; // 1 year

    uint256 public constant TOTAL_FOUNDATION_ALLOCATION = 292_699_223 ether;
    IERC20 public immutable ANT_TOKEN;

    address public immutable FOUNDATION;

    uint256 public totalAlreadyClaimed;

    error Unauthorized();

    error ZeroAddressNotAllowed();

    event Claimed(uint256 indexed amount, uint256 indexed timestamp);

    mapping(uint256 => uint256) elapsedYearsToPercentage;

    constructor(IERC20 antToken, address foundation) {
        if (address(antToken) == address(0) || address(foundation) == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        ANT_TOKEN = antToken;
        FOUNDATION = foundation;

        _setPercentagesForElapsedYears();
    }

    function claim() external {
        if (msg.sender != FOUNDATION) {
            revert Unauthorized();
        }

        uint256 claimable = _claimable();

        totalAlreadyClaimed += claimable;

        ANT_TOKEN.safeTransfer(FOUNDATION, claimable);

        emit Claimed(claimable, block.timestamp);
    }

    function getClaimable() external view returns (uint256) {
        return _claimable();
    }

    function _claimable() internal view returns (uint256 claimable) {
        uint256 elapsedTime = block.timestamp - VESTING_START_TIMESTAMP;
        uint256 elapsedYears = elapsedTime / BASE_VESTING_PERIOD;

        if (elapsedYears == 0) {
            return 0;
        }

        uint256 percentage = _getPercentageForElapsedYears(elapsedYears);

        claimable = ((TOTAL_FOUNDATION_ALLOCATION * percentage) / 10000) - totalAlreadyClaimed;
    }

    function _getPercentageForElapsedYears(uint256 elapsedYears) internal view returns (uint256) {
        if (elapsedYears > 48) {
            return 8000;
        }
        return elapsedYearsToPercentage[elapsedYears];
    }

    function _setPercentagesForElapsedYears() internal {
        elapsedYearsToPercentage[1] = 800;
        elapsedYearsToPercentage[2] = 1600;
        elapsedYearsToPercentage[3] = 2400;
        elapsedYearsToPercentage[4] = 3400;
        elapsedYearsToPercentage[5] = 4200;
        elapsedYearsToPercentage[6] = 5000;
        elapsedYearsToPercentage[7] = 5400;
        elapsedYearsToPercentage[8] = 5700;
        elapsedYearsToPercentage[9] = 6000;
        elapsedYearsToPercentage[10] = 6300;
        elapsedYearsToPercentage[11] = 6500;
        elapsedYearsToPercentage[12] = 6600;
        elapsedYearsToPercentage[13] = 6700;
        elapsedYearsToPercentage[14] = 6800;
        elapsedYearsToPercentage[15] = 6900;
        elapsedYearsToPercentage[16] = 6950;
        elapsedYearsToPercentage[17] = 7000;
        elapsedYearsToPercentage[18] = 7050;
        elapsedYearsToPercentage[19] = 7100;
        elapsedYearsToPercentage[20] = 7150;
        elapsedYearsToPercentage[21] = 7200;
        elapsedYearsToPercentage[22] = 7250;
        elapsedYearsToPercentage[23] = 7300;
        elapsedYearsToPercentage[24] = 7350;
        elapsedYearsToPercentage[25] = 7400;
        elapsedYearsToPercentage[26] = 7450;
        elapsedYearsToPercentage[27] = 7500;
        elapsedYearsToPercentage[28] = 7525;
        elapsedYearsToPercentage[29] = 7550;
        elapsedYearsToPercentage[30] = 7575;
        elapsedYearsToPercentage[31] = 7600;
        elapsedYearsToPercentage[32] = 7625;
        elapsedYearsToPercentage[33] = 7650;
        elapsedYearsToPercentage[34] = 7675;
        elapsedYearsToPercentage[35] = 7700;
        elapsedYearsToPercentage[36] = 7725;
        elapsedYearsToPercentage[37] = 7750;
        elapsedYearsToPercentage[38] = 7775;
        elapsedYearsToPercentage[39] = 7800;
        elapsedYearsToPercentage[40] = 7820;
        elapsedYearsToPercentage[41] = 7840;
        elapsedYearsToPercentage[42] = 7860;
        elapsedYearsToPercentage[43] = 7880;
        elapsedYearsToPercentage[44] = 7900;
        elapsedYearsToPercentage[45] = 7920;
        elapsedYearsToPercentage[46] = 7940;
        elapsedYearsToPercentage[47] = 7960;
        elapsedYearsToPercentage[48] = 7980;
    }
}
