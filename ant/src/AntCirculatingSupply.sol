// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AntCirculatingSupply is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public constant ANT = IERC20(0xa78d8321B20c4Ef90eCd72f2588AA985A4BDb684);

    address public shareholders;
    address public emissionsReserve;
    address public emissionsService;
    address public foundationLP;
    address public foundation;
    address public foundationNodeRewards;
    address public foundationReserve;
    address public emaidAirdropper;

    constructor(
        address _shareholders,
        address _emissionsReserve,
        address _emissionsService,
        address _foundationLP,
        address _foundation,
        address _foundationNodeRewards,
        address _foundationReserve,
        address _emaidAirdropper
    ) Ownable(msg.sender) {
        shareholders = _shareholders;
        emissionsReserve = _emissionsReserve;
        emissionsService = _emissionsService;
        foundationLP = _foundationLP;
        foundation = _foundation;
        foundationNodeRewards = _foundationNodeRewards;
        foundationReserve = _foundationReserve;
        emaidAirdropper = _emaidAirdropper;
    }

    function totalCirculatingSupply() external view returns (uint256) {
        return ANT.totalSupply() - ANT.balanceOf(shareholders) - ANT.balanceOf(emissionsReserve)
            - ANT.balanceOf(emissionsService) - ANT.balanceOf(foundationLP) - ANT.balanceOf(foundation)
            - ANT.balanceOf(foundationNodeRewards) - ANT.balanceOf(foundationReserve) - ANT.balanceOf(emaidAirdropper);
    }

    function setShareholders(address _shareholders) external onlyOwner {
        shareholders = _shareholders;
    }

    function setEmissionsReserve(address _emissionsReserve) external onlyOwner {
        emissionsReserve = _emissionsReserve;
    }

    function setEmissionsService(address _emissionsService) external onlyOwner {
        emissionsService = _emissionsService;
    }

    function setFoundationLP(address _foundationLP) external onlyOwner {
        foundationLP = _foundationLP;
    }

    function setFoundation(address _foundation) external onlyOwner {
        foundation = _foundation;
    }

    function setFoundationNodeRewards(address _foundationNodeRewards) external onlyOwner {
        foundationNodeRewards = _foundationNodeRewards;
    }

    function setFoundationReserve(address _foundationReserve) external onlyOwner {
        foundationReserve = _foundationReserve;
    }

    function setEmaidAirdropper(address _emaidAirdropper) external onlyOwner {
        emaidAirdropper = _emaidAirdropper;
    }
}
