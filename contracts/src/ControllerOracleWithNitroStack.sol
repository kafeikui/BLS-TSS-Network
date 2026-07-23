// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ControllerOracle} from "./ControllerOracle.sol";
import {AddressAliasHelper} from "./libraries/arb/AddressAliasHelper.sol";

contract ControllerOracleWithNitroStack is ControllerOracle {
    function initialize(address arpa, uint256 lastOutput) public initializer {
        _arpa = IERC20(arpa);
        _lastOutput = lastOutput;

        __Ownable_init();
    }

    function updateGroup(address committer, Group memory group) external override {
        if (msg.sender != owner() && msg.sender != AddressAliasHelper.applyL1ToL2Alias(_chainMessenger)) {
            revert SenderNotChainMessenger();
        }

        _updateGroup(committer, group);
    }
}
