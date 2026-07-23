// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {NodeRegistry} from "../src/NodeRegistry.sol";
import {INodeRegistryOwner} from "../src/interfaces/INodeRegistryOwner.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract UpgradeNodeRegistryScript is Script {
    uint256 internal _admin = vm.envUint("ADMIN_PRIVATE_KEY");

    address internal _nodeRegistryAddress = vm.envAddress("NODE_REGISTRY_ADDRESS");
    // address internal _controller = vm.envAddress("CONTROLLER_ADDRESS");
    // address internal _staking = vm.envAddress("STAKING_ADDRESS");
    // address internal _serviceManager = vm.envAddress("SERVICE_MANAGER_ADDRESS");

    // uint256 internal _pendingBlockAfterQuit = vm.envUint("PENDING_BLOCK_AFTER_QUIT");
    // uint256 internal _operatorStakeAmount = vm.envUint("OPERATOR_STAKE_AMOUNT");
    // uint256 internal _eigenlayerOperatorStakeAmount = vm.envUint("EIGENLAYER_OPERATOR_STAKE_AMOUNT");

    function run() external {
        // _adapter can be upgraded by the owner
        vm.broadcast(_admin);
        NodeRegistry nodeRegistryImpl2 = new NodeRegistry();

        vm.broadcast(_admin);
        UUPSUpgradeable(_nodeRegistryAddress).upgradeTo(address(nodeRegistryImpl2));

        // vm.broadcast(_admin);
        // INodeRegistryOwner(_nodeRegistryAddress).setNodeRegistryConfig(
        //     _controller,
        //     _staking,
        //     _serviceManager,
        //     _operatorStakeAmount,
        //     _eigenlayerOperatorStakeAmount,
        //     _pendingBlockAfterQuit
        // );
    }
}
