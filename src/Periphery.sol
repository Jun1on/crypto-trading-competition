// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {Competition} from "./Competition.sol";

contract Periphery {
    Competition public competition;
    address constant ROUTER = 0x4A7b5Da61326A6379179b40d00F57E5bbDC962c2; // Uniswap V2 Router on Optimism

    constructor(address _competition) {
        competition = Competition(_competition);
    }

    /**
     * @notice Calculates the PNL for a given player
     * @param player The address of the player
     * @return pnl The player's PNL as a signed integer (positive for profit, negative for loss)
     */
    function getPNL(address player) external view returns (int256 pnl) {
        require(competition.isParticipant(player), "Not a participant");

        address usdm = competition.USDM();
        address currentToken = competition.currentToken();
        uint256 totalAirdropUSDM = competition.totalAirdropUSDM();

        uint256 balanceUSDM = IERC20(usdm).balanceOf(player);

        uint256 valueInUSDM = 0;
        if (currentToken != address(0)) {
            uint256 tokenBalance = IERC20(currentToken).balanceOf(player);
            if (tokenBalance > 0) {
                address[] memory path = new address[](2);
                path[0] = currentToken;
                path[1] = usdm;
                uint256[] memory amounts = IUniswapV2Router02(ROUTER)
                    .getAmountsOut(tokenBalance, path);
                valueInUSDM = amounts[1];
            }
        }

        // Calculate total value and PNL
        uint256 totalValue = balanceUSDM + valueInUSDM;
        if (totalValue >= totalAirdropUSDM) {
            return int256(totalValue - totalAirdropUSDM);
        } else {
            return -int256(totalAirdropUSDM - totalValue);
        }
    }
}
