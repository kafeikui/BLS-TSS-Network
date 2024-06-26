// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {GetRandomNumberExample} from "Randcast-User-Contract/user/examples/GetRandomNumberExample.sol";
import {RandcastTestHelper, IAdapter, AdapterForTest} from "./RandcastTestHelper.sol";
import {Adapter} from "../src/Adapter.sol";

// solhint-disable-next-line max-states-count
contract AdapterTest is RandcastTestHelper {
    GetRandomNumberExample internal _getRandomNumberExample;
    uint64 internal _subId;

    uint256 internal _plentyOfEthBalance = 1e6 * 1e18;

    function setUp() public {
        _minimumRequestConfirmations = 3;
        skip(1000);
        _prepareRandcastContracts();

        vm.prank(_user);
        _getRandomNumberExample = new GetRandomNumberExample(address(_adapter));

        _subId = _prepareSubscription(_user, address(_getRandomNumberExample), _plentyOfEthBalance);
    }

    function testAdapterAddress() public {
        emit log_address(address(_adapter));
        assertEq(_getRandomNumberExample.adapter(), address(_adapter));
    }

    function testUserContractOwner() public {
        emit log_address(address(_getRandomNumberExample));
        assertEq(_getRandomNumberExample.owner(), _user);
    }

    function testCannotRequestByEOA() public {
        deal(_user, 1 * 1e18);
        vm.expectRevert(abi.encodeWithSelector(Adapter.InvalidRequestByEOA.selector));

        IAdapter.RandomnessRequestParams memory p;
        vm.broadcast(_user);
        IAdapter(address(_adapter)).requestRandomness(p);
    }

    function testRequestRandomness() public {
        (, uint256 groupSize) = prepareAnAvailableGroup();
        deal(_user, 1 * 1e18);

        uint32 times = 10;
        uint256 _inflightCost;

        for (uint256 i = 0; i < times; i++) {
            vm.prank(_user);
            bytes32 requestId = _getRandomNumberExample.getRandomNumber();
            emit log_bytes32(requestId);
            (,,, uint256 inflightCost,,,,,) = IAdapter(address(_adapter)).getSubscription(_subId);
            emit log_uint(inflightCost);

            // 0 flat fee until the first request is actually fulfilled
            uint256 payment = IAdapter(address(_adapter)).estimatePaymentAmountInETH(
                _getRandomNumberExample.callbackGasLimit()
                    + Adapter(address(_adapter)).RANDOMNESS_REWARD_GAS() * uint32(groupSize)
                    + Adapter(address(_adapter)).VERIFICATION_GAS_OVER_MINIMUM_THRESHOLD()
                        * (uint32(groupSize) - Adapter(address(_adapter)).DEFAULT_MINIMUM_THRESHOLD()),
                _gasExceptCallback,
                0,
                tx.gasprice * 3,
                uint32(groupSize)
            );

            _inflightCost += payment;

            assertEq(inflightCost, _inflightCost);

            IAdapter.RequestDetail memory rd = AdapterForTest(address(_adapter)).getPendingRequest(requestId);
            bytes memory actualSeed = abi.encodePacked(rd.seed, rd.blockNum);

            emit log_named_bytes("actualSeed", actualSeed);

            vm.roll(block.number + 1);
        }
    }

    function testFulfillRandomness() public {
        prepareAnAvailableGroup();
        deal(_user, 1 * 1e18);

        uint32 times = 1;

        vm.broadcast(_user);
        bytes32 requestId = _getRandomNumberExample.getRandomNumber();
        emit log_bytes32(requestId);

        IAdapter.RequestDetail memory rd = AdapterForTest(address(_adapter)).getPendingRequest(requestId);
        bytes memory rawSeed = abi.encodePacked(rd.seed);
        emit log_named_bytes("rawSeed", rawSeed);

        _fulfillRequest(_node1, requestId, 0);

        vm.roll(block.number + 1);
        assertEq(_getRandomNumberExample.randomnessResults(0), IAdapter(address(_adapter)).getLastRandomness());
        assertEq(_getRandomNumberExample.lengthOfRandomnessResults(), times);
    }

    function testDeleteOvertimeRequest() public {
        prepareAnAvailableGroup();
        deal(_user, 1 * 1e18);
        (,,, uint256 inflightCost,,,,,) = IAdapter(address(_adapter)).getSubscription(_subId);

        vm.prank(_user);
        bytes32 requestId = _getRandomNumberExample.getRandomNumber();
        emit log_bytes32(requestId);

        IAdapter.RequestDetail memory rd = AdapterForTest(address(_adapter)).getPendingRequest(requestId);

        bytes32 pendingRequest = IAdapter(address(_adapter)).getPendingRequestCommitment(requestId);
        assertEq(
            pendingRequest,
            keccak256(
                abi.encode(
                    requestId,
                    rd.subId,
                    rd.groupIndex,
                    rd.requestType,
                    rd.params,
                    rd.callbackContract,
                    rd.seed,
                    rd.requestConfirmations,
                    rd.callbackGasLimit,
                    rd.callbackMaxGasPrice,
                    rd.blockNum
                )
            )
        );
        vm.chainId(1);
        vm.prank(_user);
        vm.expectRevert(abi.encodeWithSelector(Adapter.RequestNotExpired.selector));
        IAdapter(address(_adapter)).cancelOvertimeRequest(requestId, rd);

        (,,, inflightCost,,,,,) = IAdapter(address(_adapter)).getSubscription(_subId);
        assertEq(inflightCost > 0, true);

        vm.roll(block.number + 7200);
        vm.prank(_user);
        IAdapter(address(_adapter)).cancelOvertimeRequest(requestId, rd);

        pendingRequest = IAdapter(address(_adapter)).getPendingRequestCommitment(requestId);
        assertEq(pendingRequest, bytes32(0));
        (,,, inflightCost,,,,,) = IAdapter(address(_adapter)).getSubscription(_subId);
        assertEq(inflightCost, 0);

        uint256 inflightPayment = AdapterForTest(address(_adapter)).getInflightCost(_subId, requestId);
        assertEq(inflightPayment, 0);

        vm.prank(_user);
        IAdapter(address(_adapter)).cancelSubscription(_subId, _user);
        vm.expectRevert(abi.encodeWithSelector(Adapter.InvalidSubscription.selector));
        IAdapter(address(_adapter)).getSubscription(_subId);
    }
}
