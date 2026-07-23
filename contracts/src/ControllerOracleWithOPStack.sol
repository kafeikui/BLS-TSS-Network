// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IOPCrossDomainMessenger} from "./interfaces/IOPCrossDomainMessenger.sol";
import {ControllerOracle} from "./ControllerOracle.sol";

contract ControllerOracleWithOPStack is ControllerOracle {
    IOPCrossDomainMessenger private _l2CrossDomainMessenger;

    function initialize(address arpa, address l2CrossDomainMessenger, uint256 lastOutput) public initializer {
        _arpa = IERC20(arpa);
        _l2CrossDomainMessenger = IOPCrossDomainMessenger(l2CrossDomainMessenger);
        _lastOutput = lastOutput;

        __Ownable_init();
    }

    function updateGroup(address committer, Group memory group) external override {
        if (
            msg.sender != owner()
                && (
                    msg.sender != address(_l2CrossDomainMessenger)
                        || _l2CrossDomainMessenger.xDomainMessageSender() != _chainMessenger
                )
        ) {
            revert SenderNotChainMessenger();
        }

        _updateGroup(committer, group);
    }

    function setL2CrossDomainMessenger(address l2CrossDomainMessenger) external onlyOwner {
        if (l2CrossDomainMessenger == address(0)) {
            revert InvalidZeroAddress();
        }
        _l2CrossDomainMessenger = IOPCrossDomainMessenger(l2CrossDomainMessenger);
    }
}
