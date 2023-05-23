// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Adapter} from "../src/Adapter.sol";

contract AdapterForTest is Adapter {
    mapping(bytes32 => RequestDetail) internal _requestDetails;

    constructor(address controller, address arpa, address arpaEthFeed) {
        initialize(controller, arpa, arpaEthFeed);
    }

    function requestRandomness(RandomnessRequestParams memory p) public override returns (bytes32) {
        bytes32 requestId = super.requestRandomness(p);
        uint256 rawSeed = _makeRandcastInputSeed(p.seed, msg.sender, _consumers[msg.sender].nonces[p.subId] - 1);

        // Record RequestDetail struct
        RequestDetail storage rd = _requestDetails[requestId];
        rd.subId = p.subId;
        rd.groupIndex = _lastAssignedGroupIndex;
        rd.requestType = p.requestType;
        rd.params = p.params;
        rd.callbackContract = msg.sender;
        rd.seed = rawSeed;
        rd.requestConfirmations = p.requestConfirmations;
        rd.callbackGasLimit = p.callbackGasLimit;
        rd.callbackMaxGasPrice = p.callbackMaxGasPrice;
        rd.blockNum = block.number;

        return requestId;
    }

    function getPendingRequest(bytes32 requestId) public view returns (RequestDetail memory) {
        return _requestDetails[requestId];
    }
}