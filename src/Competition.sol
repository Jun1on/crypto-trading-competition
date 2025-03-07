// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/access/Ownable.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {MockToken} from "./MockToken.sol";

contract TradingGame is Ownable {
    address constant router = 0x4A7b5Da61326A6379179b40d00F57E5bbDC962c2; // Optimism
    address public immutable USDM;
    address[] public participants;
    mapping(address => bool) public isParticipant;
    uint256 totalAirdropUSDM;
    address public currentToken;

    event RoundStarted(string name, string symbol, address token);
    event RoundEnded(address token);

    constructor(
        address _USDM,
        address[] memory _participants
    ) Ownable(msg.sender) {
        USDM = _USDM;
        IERC20(USDM).approve(router, type(uint256).max);

        uint256 length = _participants.length;
        for (uint256 i = 0; i < length; ) {
            address participant = _participants[i];
            participants.push(participant);
            isParticipant[participant] = true;
            unchecked {
                i++;
            }
        }
    }

    function startRound(
        string memory name,
        string memory symbol,
        uint256 liquidityUSDM,
        uint256 price,
        uint256 airdropUSDM,
        uint256 devShare
    ) external onlyOwner {
        MockToken newToken = new MockToken(name, symbol);
        currentToken = address(newToken);

        uint256 length = participants.length;
        for (uint256 i = 0; i < length; ) {
            address participant = participants[i];
            MockToken(USDM).mint(participant, airdropUSDM);
            totalAirdropUSDM += airdropUSDM;
            unchecked {
                i++;
            }
        }

        newToken.mint(owner, devShare);

        uint256 liquidityToken = (liquidityUSDM * 1e18) / price;

        newToken.mint(address(this), liquidityToken);
        IERC20(USDM).mint(address(this), liquidityUSDM);

        newToken.approve(router, liquidityToken);

        IUniswapV2Router02(router).addLiquidity(
            address(newToken),
            USDM,
            liquidityToken,
            liquidityUSDM,
            0,
            0,
            address(this),
            type(uint256).max
        );

        emit RoundStarted(name, symbol, address(newToken));
    }

    function endRound() external onlyOwner {
        require(currentToken != address(0), "No current token to pause");
        MockToken(currentToken).pause();
        currentToken = address(0);
        emit RoundEnded(currentToken);
    }

    // Add a new player mid-game
    function addPlayer(address player) external onlyOwner {
        require(!isParticipant[player], "Player already added");

        participants.push(player);
        isParticipant[player] = true;

        IERC20(USDM).mint(player, totalAirdropUSDM);
        totalAirdropUSDM[player] += totalAirdropUSDM;
    }
}
