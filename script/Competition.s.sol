// modify the bottom four parameters
/*
forge script script/Competition.s.sol:DeployCompetition \
  --rpc-url https://mainnet.optimism.io \
  --broadcast \
  --verify \
  --chain 10 \
  --memory-limit 9999999999 \
  --private-key 0x1234 \
  --etherscan-api-key API_KEY \
  --sig "run(address[])" "[0x1,0x2]" \
  --with-gas-price 2000000 \
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MockUSD} from "../src/MockUSD.sol";
import {Competition} from "../src/Competition.sol";

contract DeployCompetition is Script {
    address constant MARKET_MAKER = 0x4F1246A39B02ef2e7432D81fd5bfAA884D72EEEE;
    uint256 constant GAS_DISTRIBUTION = 0.00002 ether; // adjust

    function run(address[] memory participants) external {
        vm.startBroadcast();
        for (uint256 i = 0; i < participants.length; i++) {
            //participants[i].call{value: GAS_DISTRIBUTION}("");
        }
        MockUSD USDM = deployUSDMWithPrefix();
        Competition competition = new Competition(
            address(USDM),
            MARKET_MAKER,
            participants
        );
        USDM.mint(msg.sender, 10_000_000e18);
        uint256 liquidity = 1 ether * participants.length + 5 ether;
        USDM.transferOwnership(address(competition));
        competition.startRound(
            "Test Token",
            "TEST",
            liquidity,
            liquidity,
            1000 ether,
            liquidity,
            liquidity,
            5 ether,
            1440
        );
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
