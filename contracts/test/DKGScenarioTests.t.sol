// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

pragma experimental ABIEncoderV2;

import {
    RandcastTestHelper,
    ERC20,
    ControllerForTest,
    IController,
    IControllerOwner,
    INodeRegistry,
    NodeRegistry,
    ServiceManager,
    ERC1967Proxy,
    INodeRegistryOwner
} from "./RandcastTestHelper.sol";
import {Controller} from "../src/Controller.sol";
import {ICoordinator} from "../src/interfaces/ICoordinator.sol";
import {IControllerForTest} from "./IControllerForTest.sol";
import {BLS} from "../src/libraries/BLS.sol";

contract DKGScenarioTest is RandcastTestHelper {
    function setUp() public {
        // deal nodes
        vm.deal(_node1, 1 * 10 ** 18);
        vm.deal(_node2, 1 * 10 ** 18);
        vm.deal(_node3, 1 * 10 ** 18);
        vm.deal(_node4, 1 * 10 ** 18);
        vm.deal(_node5, 1 * 10 ** 18);

        // deal _owner and create _controller
        vm.deal(_admin, 1 * 10 ** 18);

        vm.prank(_admin);
        _arpa = new ERC20("arpa token", "ARPA");

        address[] memory operators = new address[](5);
        operators[0] = _node1;
        operators[1] = _node2;
        operators[2] = _node3;
        operators[3] = _node4;
        operators[4] = _node5;
        _prepareStakingContract(_stakingDeployer, address(_arpa), operators);

        vm.prank(_admin);
        _controllerImpl = new ControllerForTest();

        vm.prank(_admin);
        _controller =
            new ERC1967Proxy(address(_controllerImpl), abi.encodeWithSignature("initialize(uint256)", _lastOutput));

        vm.prank(_admin);
        _nodeRegistryImpl = new NodeRegistry();

        vm.prank(_admin);
        _nodeRegistry =
            new ERC1967Proxy(address(_nodeRegistryImpl), abi.encodeWithSignature("initialize(address)", address(_arpa)));

        vm.prank(_admin);
        _serviceManagerImpl = new ServiceManager();

        vm.prank(_admin);
        _serviceManager = new ERC1967Proxy(
            address(_serviceManagerImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address)", address(_nodeRegistry), address(0), address(0)
            )
        );

        vm.prank(_admin);
        INodeRegistryOwner(address(_nodeRegistry)).setNodeRegistryConfig(
            address(_controller),
            address(_staking),
            address(_serviceManager),
            _operatorStakeAmount,
            _eigenlayerOperatorStakeAmount,
            _pendingBlockAfterQuit
        );

        vm.prank(_admin);
        IControllerOwner(address(_controller)).setControllerConfig(
            address(_nodeRegistry),
            address(0),
            _disqualifiedNodePenaltyAmount,
            _defaultNumberOfCommitters,
            _defaultDkgPhaseDuration,
            _groupMaxCapacity,
            _idealNumberOfGroups,
            _dkgPostProcessReward
        );

        vm.prank(_stakingDeployer);
        _staking.setController(address(_nodeRegistry));

        // Register Nodes
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey1, false, _node1, _emptyOperatorSignature);
        vm.prank(_node2);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey2, false, _node2, _emptyOperatorSignature);
        vm.prank(_node3);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey3, false, _node3, _emptyOperatorSignature);
        vm.prank(_node4);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey4, false, _node4, _emptyOperatorSignature);
        vm.prank(_node5);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey5, false, _node5, _emptyOperatorSignature);
    }

    struct Params {
        address nodeIdAddress;
        bool shouldRevert;
        bytes revertMessage;
        uint256 groupIndex;
        uint256 groupEpoch;
        bytes _publicKey;
        bytes partialPublicKey;
        address[] disqualifiedNodes;
    }

    function dkgHelper(Params[] memory params) public {
        for (uint256 i = 0; i < params.length; i++) {
            vm.prank(params[i].nodeIdAddress);
            if (params[i].shouldRevert) {
                vm.expectRevert(params[i].revertMessage);
            }
            IControllerForTest(address(_controller)).commitDkg(
                IController.CommitDkgParams(
                    params[i].groupIndex,
                    params[i].groupEpoch,
                    params[i]._publicKey,
                    params[i].partialPublicKey,
                    params[i].disqualifiedNodes
                )
            );
        }
    }

    function setPhase(uint256 groupIndex, uint256 phase) public {
        address coordinatorAddress = IControllerForTest(address(_controller)).getCoordinator(groupIndex);
        ICoordinator coordinator = ICoordinator(coordinatorAddress);
        uint256 startBlock = coordinator.startBlock();
        vm.roll(startBlock + 1 + phase * _defaultDkgPhaseDuration);
    }

    function testDkgReverts() public {
        // Test all "require" checks
        bytes memory err;
        Params[] memory params = new Params[](1);

        err = abi.encodeWithSelector(Controller.GroupNotExist.selector, 999);
        params[0] = Params(_node1, true, err, 999, 3, _publicKey, _partialPublicKey1, new address[](0));
        dkgHelper(params);

        err = abi.encodeWithSelector(Controller.EpochMismatch.selector, 0, 999, 3);
        params[0] = Params(_node1, true, err, 0, 999, _publicKey, _partialPublicKey1, new address[](0));
        dkgHelper(params);

        err = abi.encodeWithSelector(Controller.NodeNotInGroup.selector, 0, address(_node6));
        params[0] = Params(_node6, true, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));
        dkgHelper(params);

        err = abi.encodeWithSelector(BLS.InvalidPublicKeyEncoding.selector);
        params[0] = Params(_node1, true, err, 0, 3, _publicKey, hex"AAAA", new address[](0));
        dkgHelper(params);

        err = abi.encodeWithSelector(BLS.InvalidPartialPublicKey.selector);
        params[0] = Params(_node1, true, err, 0, 3, _publicKey, _badKey, new address[](0));
        dkgHelper(params);

        err = abi.encodeWithSelector(BLS.InvalidPublicKey.selector);
        params[0] = Params(_node1, true, err, 0, 3, _badKey, _partialPublicKey1, new address[](0));
        dkgHelper(params);

        // Happy Path
        Params[] memory params2 = new Params[](2);
        params2[0] = Params(_node1, false, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));

        err = abi.encodeWithSelector(Controller.PartialKeyAlreadyRegistered.selector, 0, address(_node1));
        params2[1] = Params(_node1, true, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));

        dkgHelper(params2);
    }

    // * Happy Path
    function testDkgHappyPath() public {
        Params[] memory params = new Params[](5);
        bytes memory err;
        params[0] = Params(_node1, false, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 3, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 3, _publicKey, _partialPublicKey3, new address[](0));
        params[3] = Params(_node4, false, err, 0, 3, _publicKey, _partialPublicKey4, new address[](0));
        params[4] = Params(_node5, false, err, 0, 3, _publicKey, _partialPublicKey5, new address[](0));
        dkgHelper(params);
        // printGroupInfo(0);

        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 5);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 5);
    }

    // * 1 Disqualified Node
    function test1Dq4Reporter() public {
        Params[] memory params = new Params[](5);
        bytes memory err;
        address[] memory disqualifiedNodes = new address[](1);
        disqualifiedNodes[0] = _node1;

        uint256 node1DelegationRewardBefore = _staking.getDelegationReward(_node1);

        params[0] = Params(_node1, false, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 3, _publicKey, _partialPublicKey2, disqualifiedNodes);
        params[2] = Params(_node3, false, err, 0, 3, _publicKey, _partialPublicKey3, disqualifiedNodes);
        params[3] = Params(_node4, false, err, 0, 3, _publicKey, _partialPublicKey4, disqualifiedNodes);
        params[4] = Params(_node5, false, err, 0, 3, _publicKey, _partialPublicKey5, disqualifiedNodes);
        dkgHelper(params);
        // printGroupInfo(0);

        // assert group state is correct
        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 4);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 4);

        // assert _node1 was slashed
        assertEq(nodeInGroup(_node1, 0), false);
        assertEq(node1DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node1));
    }

    function test1Dq3Reporter() public {
        Params[] memory params = new Params[](5);
        bytes memory err;
        address[] memory disqualifiedNodes = new address[](1);
        disqualifiedNodes[0] = _node1;

        uint256 node1DelegationRewardBefore = _staking.getDelegationReward(_node1);

        params[0] = Params(_node1, false, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 3, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 3, _publicKey, _partialPublicKey3, disqualifiedNodes);
        params[3] = Params(_node4, false, err, 0, 3, _publicKey, _partialPublicKey4, disqualifiedNodes);
        params[4] = Params(_node5, false, err, 0, 3, _publicKey, _partialPublicKey5, disqualifiedNodes);
        dkgHelper(params);
        // printGroupInfo(0);

        // assert group state is correct
        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 4);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 4);

        // assert _node1 was slashed
        assertEq(nodeInGroup(_node1, 0), false);
        assertEq(node1DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node1));
    }

    function test1Dq2Reporter() public {
        Params[] memory params = new Params[](5);
        bytes memory err;
        address[] memory disqualifiedNodes = new address[](1);
        disqualifiedNodes[0] = _node1;

        params[0] = Params(_node1, false, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 3, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 3, _publicKey, _partialPublicKey3, new address[](0));
        params[3] = Params(_node4, false, err, 0, 3, _publicKey, _partialPublicKey4, disqualifiedNodes);
        params[4] = Params(_node5, false, err, 0, 3, _publicKey, _partialPublicKey5, disqualifiedNodes);
        dkgHelper(params);
        // printGroupInfo(0);

        // assert group state is correct
        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 5);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 5);
    }

    function test1Dq1Reporter() public {
        Params[] memory params = new Params[](5);
        bytes memory err;
        address[] memory disqualifiedNodes = new address[](1);
        disqualifiedNodes[0] = _node1;

        params[0] = Params(_node1, false, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 3, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 3, _publicKey, _partialPublicKey3, new address[](0));
        params[3] = Params(_node4, false, err, 0, 3, _publicKey, _partialPublicKey4, new address[](0));
        params[4] = Params(_node5, false, err, 0, 3, _publicKey, _partialPublicKey5, disqualifiedNodes);
        dkgHelper(params);
        // printGroupInfo(0);

        // assert group state is correct
        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 5);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 5);
    }

    // * 2 Disqualified Nodes

    function test2Dq4Reporter() public {
        Params[] memory params = new Params[](5);
        bytes memory err;
        address[] memory disqualifiedNodes = new address[](2);
        disqualifiedNodes[0] = _node1;
        disqualifiedNodes[1] = _node2;

        uint256 node1DelegationRewardBefore = _staking.getDelegationReward(_node1);
        uint256 node2DelegationRewardBefore = _staking.getDelegationReward(_node2);

        params[0] = Params(_node1, false, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 3, _publicKey, _partialPublicKey2, disqualifiedNodes);
        params[2] = Params(_node3, false, err, 0, 3, _publicKey, _partialPublicKey3, disqualifiedNodes);
        params[3] = Params(_node4, false, err, 0, 3, _publicKey, _partialPublicKey4, disqualifiedNodes);
        params[4] = Params(_node5, false, err, 0, 3, _publicKey, _partialPublicKey5, disqualifiedNodes);
        dkgHelper(params);
        // printGroupInfo(0);

        // assert group state is correct
        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 3);

        // assert _node1 was slashed
        assertEq(nodeInGroup(_node1, 0), false);
        assertEq(node1DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node1));
        // assert _node2 was slashed
        assertEq(nodeInGroup(_node2, 0), false);
        assertEq(node2DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node2));
    }

    function test2Dq3Reporter() public {
        Params[] memory params = new Params[](5);
        bytes memory err;
        address[] memory disqualifiedNodes = new address[](2);
        disqualifiedNodes[0] = _node1;
        disqualifiedNodes[1] = _node2;

        uint256 node1DelegationRewardBefore = _staking.getDelegationReward(_node1);
        uint256 node2DelegationRewardBefore = _staking.getDelegationReward(_node2);

        params[0] = Params(_node1, false, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 3, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 3, _publicKey, _partialPublicKey3, disqualifiedNodes);
        params[3] = Params(_node4, false, err, 0, 3, _publicKey, _partialPublicKey4, disqualifiedNodes);
        params[4] = Params(_node5, false, err, 0, 3, _publicKey, _partialPublicKey5, disqualifiedNodes);
        dkgHelper(params);
        // printGroupInfo(0);

        // assert group state is correct
        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 3);

        // assert _node1 and _node2 were slashed
        assertEq(nodeInGroup(_node1, 0), false);
        assertEq(node1DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node1));
        assertEq(nodeInGroup(_node2, 0), false);
        assertEq(node2DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node2));
    }

    function test2Dq2Reporter() public {
        Params[] memory params = new Params[](5);
        bytes memory err;
        address[] memory disqualifiedNodes = new address[](2);
        disqualifiedNodes[0] = _node1;
        disqualifiedNodes[1] = _node2;

        params[0] = Params(_node1, false, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 3, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 3, _publicKey, _partialPublicKey3, new address[](0));
        params[3] = Params(_node4, false, err, 0, 3, _publicKey, _partialPublicKey4, disqualifiedNodes);
        params[4] = Params(_node5, false, err, 0, 3, _publicKey, _partialPublicKey5, disqualifiedNodes);
        dkgHelper(params);
        // printGroupInfo(0);

        // assert group state is correct
        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 5);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 5);
    }

    // * 3 Disqualified Nodes (???)
    function test3Dq3Reporter() public {
        Params[] memory params = new Params[](5);
        bytes memory err;
        address[] memory disqualifiedNodes = new address[](3);
        disqualifiedNodes[0] = _node1;
        disqualifiedNodes[1] = _node2;
        disqualifiedNodes[2] = _node3;

        params[0] = Params(_node1, false, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 3, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 3, _publicKey, _partialPublicKey3, disqualifiedNodes);
        params[3] = Params(_node4, false, err, 0, 3, _publicKey, _partialPublicKey4, disqualifiedNodes);
        params[4] = Params(_node5, false, err, 0, 3, _publicKey, _partialPublicKey5, disqualifiedNodes);
        dkgHelper(params);
        // printGroupInfo(0);

        // * Is this okay?
        // * When non-disqualified majority members < g.threshold (3), group is not formed, nodes are not slashed.

        // assert group state is correct
        assertEq(checkIsStrictlyMajorityConsensusReached(0), false);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 5);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 5);

        // assert _node1, _node2, and _node3 were slashed
        assertEq(nodeInGroup(_node1, 0), true);
        // assertEq(nativeNodeStakingAmount, _staking.getDelegationReward(_node1));
        // assertEq(nodeInGroup(_node1, 0), false);
        // // assertEq(nativeNodeStakingAmount - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node1));
    }

    // * PPDKG with 3 Disqualified Nodes
    function testPPDKG3Dq3Reporter() public {
        test3Dq3Reporter();
        // printGroupInfo(0);

        // Set the coordinator to completed phase
        setPhase(0, 4);

        uint256 node1DelegationRewardBefore = _staking.getDelegationReward(_node1);
        uint256 node2DelegationRewardBefore = _staking.getDelegationReward(_node2);
        uint256 node3DelegationRewardBefore = _staking.getDelegationReward(_node3);

        // call postProcessDkg as _node1
        vm.prank(_node1);
        IControllerForTest(address(_controller)).postProcessDkg(0, 3);
        // printGroupInfo(0);

        // assert group state is correct
        assertEq(checkIsStrictlyMajorityConsensusReached(0), false);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 2);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 2);

        // assert _node1, _node2, and _node3 were slashed
        assertEq(nodeInGroup(_node1, 0), false);
        assertEq(node1DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node1));
        assertEq(nodeInGroup(_node2, 0), false);
        assertEq(node2DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node2));
        assertEq(nodeInGroup(_node3, 0), false);
        assertEq(node3DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node3));
    }

    // *  Disqualified Node Mixed Reporting
    function testMixed1Dq5Reporter5Target() public {
        // 5 nodes all report different disqualified nodes (1 reports 2 reports 3 ...)
        Params[] memory params = new Params[](5);
        bytes memory err;
        address[] memory dn1 = new address[](1);
        address[] memory dn2 = new address[](1);
        address[] memory dn3 = new address[](1);
        address[] memory dn4 = new address[](1);
        address[] memory dn5 = new address[](1);

        dn1[0] = _node1;
        dn2[0] = _node2;
        dn3[0] = _node3;
        dn4[0] = _node4;
        dn5[0] = _node5;

        params[0] = Params(_node1, false, err, 0, 3, _publicKey, _partialPublicKey1, dn2);
        params[1] = Params(_node2, false, err, 0, 3, _publicKey, _partialPublicKey2, dn3);
        params[2] = Params(_node3, false, err, 0, 3, _publicKey, _partialPublicKey3, dn4);
        params[3] = Params(_node4, false, err, 0, 3, _publicKey, _partialPublicKey4, dn5);
        params[4] = Params(_node5, false, err, 0, 3, _publicKey, _partialPublicKey5, dn1);
        dkgHelper(params);
        // printGroupInfo(0);

        // assert group state is correct
        assertEq(checkIsStrictlyMajorityConsensusReached(0), false);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 5);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 5);
    }

    // * PPDKG Node Mixed Reporting
    function testPPDKGMixed1Dq5Reporter5Target() public {
        testMixed1Dq5Reporter5Target();
        printGroupInfo(0);

        // Set the coordinator to completed phase
        setPhase(0, 4);

        uint256 node1DelegationRewardBefore = _staking.getDelegationReward(_node1);
        uint256 node2DelegationRewardBefore = _staking.getDelegationReward(_node2);
        uint256 node3DelegationRewardBefore = _staking.getDelegationReward(_node3);
        uint256 node4DelegationRewardBefore = _staking.getDelegationReward(_node4);
        uint256 node5DelegationRewardBefore = _staking.getDelegationReward(_node5);

        // call postProcessDkg as _node1
        vm.prank(_node1);
        IControllerForTest(address(_controller)).postProcessDkg(0, 3);
        printGroupInfo(0);

        // assert group state is correct
        assertEq(checkIsStrictlyMajorityConsensusReached(0), false);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 0);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 0);

        // assert nodes are slashed
        assertEq(nodeInGroup(_node1, 0), false);
        assertEq(node1DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node1));
        assertEq(nodeInGroup(_node2, 0), false);
        assertEq(node2DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node2));
        assertEq(nodeInGroup(_node3, 0), false);
        assertEq(node3DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node3));
        assertEq(nodeInGroup(_node4, 0), false);
        assertEq(node4DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node4));
        assertEq(nodeInGroup(_node5, 0), false);
        assertEq(node5DelegationRewardBefore - _disqualifiedNodePenaltyAmount, _staking.getDelegationReward(_node5));
    }
}
