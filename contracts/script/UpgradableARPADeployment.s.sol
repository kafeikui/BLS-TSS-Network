// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Deployer} from "./Deployer.s.sol";
import {UpgradableARPA} from "./UpgradableARPA.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// solhint-disable-next-line max-states-count
contract UpgradableARPADeploymentScript is Deployer {
    uint256 internal _deployerPrivateKey = vm.envUint("ADMIN_PRIVATE_KEY");

    function run() external {
        _checkDeploymentAddressesFile();

        vm.broadcast(_deployerPrivateKey);
        UpgradableARPA arpaImpl = new UpgradableARPA();
        _addDeploymentAddress(Network.L2, "UpgradableARPAImpl", address(arpaImpl));

        vm.broadcast(_deployerPrivateKey);
        ERC1967Proxy arpa = new ERC1967Proxy(address(arpaImpl), abi.encodeWithSignature("initialize()"));
        _addDeploymentAddress(Network.L2, "UpgradableARPA", address(arpa));
    }
}
