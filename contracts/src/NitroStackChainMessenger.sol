// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IController} from "./interfaces/IController.sol";
import {IControllerOracle} from "./interfaces/IControllerOracle.sol";
import {IChainMessenger} from "./interfaces/IChainMessenger.sol";
import {IInbox} from "./interfaces/arb/IInbox.sol";

contract NitroStackChainMessenger is Ownable, IChainMessenger {
    address private _controllerRelayer;
    address private _controllerOracle;
    IInbox private _inbox;
    uint256 private _maxSubmissionCost;
    uint256 private _maxFeePerGas;

    event MessageRelayed(uint256 indexed ticketId, uint256 groupIndex, uint256 groupEpoch);

    error WrongControllerRelayer();

    constructor(address controllerRelayer, address controllerOracle, address inbox) {
        _controllerRelayer = controllerRelayer;
        _controllerOracle = controllerOracle;
        _inbox = IInbox(inbox);
    }

    function relayMessage(address committer, IController.Group memory group) external {
        if (msg.sender != _controllerRelayer) {
            revert WrongControllerRelayer();
        }
        bytes memory data = abi.encodeWithSelector(IControllerOracle.updateGroup.selector, committer, group);

        uint256 ticketId = _inbox.createRetryableTicket(
            _controllerOracle,
            0,
            _maxSubmissionCost,
            msg.sender,
            msg.sender,
            (344270 + 157160 * uint32(group.size)) * 6 / 5,
            _maxFeePerGas,
            data
        );

        emit MessageRelayed(ticketId, group.index, group.epoch);
    }

    function setControllerRelayer(address controllerRelayer) external onlyOwner {
        _controllerRelayer = controllerRelayer;
    }

    function setControllerOracle(address controllerOracle) external onlyOwner {
        _controllerOracle = controllerOracle;
    }

    function setInbox(address inbox) external onlyOwner {
        _inbox = IInbox(inbox);
    }

    function setRetryableTicketParams(uint256 maxSubmissionCost, uint256 maxFeePerGas) external onlyOwner {
        _maxSubmissionCost = maxSubmissionCost;
        _maxFeePerGas = maxFeePerGas;
    }
}
