// modify the bottom three parameters
/*
forge script script/Periphery.s.sol:DeployPeriphery \
  --rpc-url https://mainnet.optimism.io \
  --broadcast \
  --verify \
  --chain 10 \
  --memory-limit 9999999999 \
  --private-key 0x1234 \
  --etherscan-api-key API_KEY \
  --with-gas-price 2000000 \
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Periphery} from "../src/Periphery.sol";

contract DeployPeriphery is Script {
    function setUp() public {}

    function run() public returns (Periphery) {
        vm.startBroadcast();
        Periphery periphery = new Periphery();
        vm.stopBroadcast();
        return periphery;
    }
}
