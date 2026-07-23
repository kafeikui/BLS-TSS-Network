// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20, ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract ARPA is ERC20Permit, Ownable {
    constructor() ERC20Permit("Arpa Token") ERC20("Arpa Token", "ARPA") {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
