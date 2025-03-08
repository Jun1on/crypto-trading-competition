// modify the top four parameters
/*
forge script script/Competition.s.sol:DeployCompetition \
  --private-key 0x1234 \
  --sig "run(address[])" "[0x1,0x2]" \
  --etherscan-api-key API_KEY \
  --with-gas-price 2000000 \

  --rpc-url https://mainnet.optimism.io \
  --broadcast \
  --verify \
  --chain 10 \
  --memory-limit 9999999999
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MockUSD} from "../src/MockUSD.sol";
import {Competition} from "../src/Competition.sol";

contract DeployCompetition is Script {
    function run(address[] memory participants) external {
        vm.startBroadcast();
        MockUSD USDM = deployUSDMWithPrefix();
        Competition competition = new Competition(address(USDM), participants);
        USDM.mint(address(this), 1000000e18);
        USDM.transferOwnership(address(competition));
        vm.stopBroadcast();
        console.log("USDM deployed at:", address(USDM));
        console.log("Competition deployed at:", address(competition));
    }

    // deploy USDM with a high address so it's the second token in the univ2 pair
    function deployUSDMWithPrefix() internal returns (MockUSD) {
        // randomness to avoid collisions
        uint256 salt = block.timestamp * 100000;
        address predictedAddress;

        while (true) {
            predictedAddress = computeAddress(
                salt,
                type(MockUSD).creationCode,
                bytes("")
            );
            if (uint160(predictedAddress) >> (160 - 16) == 0xFFFF) {
                break;
            }
            salt++;
        }

        MockUSD USDM = new MockUSD{salt: bytes32(salt)}();
        require(address(USDM) == predictedAddress, "USDM deployment failed");

        return USDM;
    }

    function computeAddress(
        uint256 salt,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) internal pure returns (address predictedAddress) {
        address CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        bytes memory creationCodeWithArgs = abi.encodePacked(
            creationCode,
            constructorArgs
        );
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xFF),
                                CREATE2_DEPLOYER,
                                salt,
                                keccak256(creationCodeWithArgs)
                            )
                        )
                    )
                )
            );
    }
}
