// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IOPCrossDomainMessenger {
    function sendMessage(address _target, bytes calldata _message, uint32 _minGasLimit) external payable;

    function xDomainMessageSender() external view returns (address);
}
