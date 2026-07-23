// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20PermitUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract UpgradableARPA is ERC20PermitUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
    function initialize() public initializer {
        __ERC20_init("ARPA Token", "ARPA");
        __ERC20Permit_init("ARPA Token");
        __Ownable_init();
    }

    constructor() {
        _disableInitializers();
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
