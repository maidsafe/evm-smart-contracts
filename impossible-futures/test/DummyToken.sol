// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DummyToken is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name,_symbol) {
        _mint(msg.sender, 1000000000000000000000000000);
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}