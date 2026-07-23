// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {ServiceManager} from "../src/eigenlayer/ServiceManager.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract UpgradeServiceManagerScript is Script {
    uint256 internal _admin = vm.envUint("ADMIN_PRIVATE_KEY");

    address internal _serviceManagerAddress = vm.envAddress("SERVICE_MANAGER_ADDRESS");

    function run() external {
        // _adapter can be upgraded by the owner
        vm.broadcast(_admin);
        ServiceManager serviceManagerImpl2 = new ServiceManager();

        vm.broadcast(_admin);
        UUPSUpgradeable(_serviceManagerAddress).upgradeTo(address(serviceManagerImpl2));
    }
}
