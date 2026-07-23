// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {ControllerOracle} from "../src/ControllerOracle.sol";

contract L2ControllerOracleInitializationLocalTestScript is Script {
    uint256 internal _deployerPrivateKey = vm.envUint("ADMIN_PRIVATE_KEY");

    address internal _controllerOracleAddress = vm.envAddress("L2_CONTROLLER_ORACLE_ADDRESS");
    address internal _adapterAddress = vm.envAddress("L2_ADAPTER_ADDRESS");
    address internal _l1ChainMessengerAddress = vm.envAddress("L1_CHAIN_MESSENGER_ADDRESS");

    function run() external {
        vm.broadcast(_deployerPrivateKey);
        ControllerOracle(_controllerOracleAddress).setAdapterContractAddress(_adapterAddress);

        // vm.broadcast(_deployerPrivateKey);
        // ControllerOracle(_controllerOracleAddress).setChainMessenger(_l1ChainMessengerAddress);
    }
}
