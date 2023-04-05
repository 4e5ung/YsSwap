// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//import "../token/ERC20/ERC20.sol";

contract TokenERC20 is ERC20{

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol){
        _mint(msg.sender, (10 ** 9) * (10 ** 18));
    }
}