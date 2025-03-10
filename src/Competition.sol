// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/access/Ownable.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {MockToken} from "./MockToken.sol";
import {MockUSD} from "./MockUSD.sol";

contract Competition is Ownable {
    address public constant ROUTER = 0x4A7b5Da61326A6379179b40d00F57E5bbDC962c2;
    address public immutable USDM;
    address public immutable marketMaker;
    address[] public participants;
    mapping(address => bool) public isParticipant;
    uint256 public totalAirdropUSDM;
    address public currentToken;
    uint256 public currentRound;
    mapping(address => mapping(uint256 => int256)) public playerPNLHistory;
    uint256 public participantsLength;

    event RoundStarted(string name, string symbol, address token);
    event RoundEnded(address token);

    constructor(
        address _USDM,
        address _marketMaker,
        address[] memory _participants
    ) Ownable(msg.sender) {
        USDM = _USDM;
        marketMaker = _marketMaker;
        IERC20(USDM).approve(ROUTER, type(uint256).max);

        participantsLength = _participants.length;
        for (uint256 i = 0; i < participantsLength; ) {
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
        uint256 liquidityToken,
        uint256 devShare,
        uint256 marketMakerShare,
        uint256 marketMakerUSDM,
        uint256 airdropUSDM
    ) external onlyOwner {
        require(currentToken == address(0), "already started");

        MockToken newToken = new MockToken(name, symbol);
        currentToken = address(newToken);

        uint256 length = participants.length;
        for (uint256 i = 0; i < length; ) {
            address participant = participants[i];
            MockUSD(USDM).mint(participant, airdropUSDM);
            unchecked {
                i++;
            }
        }
        totalAirdropUSDM += airdropUSDM;

        newToken.mint(owner(), devShare);
        newToken.mint(marketMaker, marketMakerShare);
        MockUSD(USDM).mint(marketMaker, marketMakerUSDM);

        newToken.mint(address(this), liquidityToken);
        MockUSD(USDM).mint(address(this), liquidityUSDM);

        newToken.approve(ROUTER, liquidityToken);

        IUniswapV2Router02(ROUTER).addLiquidity(
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
        require(currentToken != address(0), "already ended");

        // todo: autosell tokens
        uint256 length = participants.length;
        for (uint256 i = 0; i < length; ) {
            address participant = participants[i];
            MockToken(currentToken).burn(
                participant,
                MockToken(currentToken).balanceOf(participant)
            );
            unchecked {
                i++;
            }
        }
        MockToken(currentToken).pause();
        MockUSD(USDM).burn(marketMaker, ERC20(USDM).balanceOf(marketMaker));
        emit RoundEnded(currentToken);

        currentToken = address(0);
        _logPNL();
        unchecked {
            currentRound++;
        }
    }

    /**
     * @notice Add a new player mid-game
     */
    function addPlayer(address player) external onlyOwner {
        require(!isParticipant[player], "already added");

        participants.push(player);
        isParticipant[player] = true;
        participantsLength++;

        MockToken(USDM).mint(player, totalAirdropUSDM);
    }

    function _logPNL() internal {
        uint256 length = participants.length;
        for (uint256 i = 0; i < length; ) {
            address player = participants[i];
            playerPNLHistory[player][currentRound] = _realizedPNL(player);
            unchecked {
                i++;
            }
        }
    }

    function _realizedPNL(
        address player
    ) internal view returns (int256 realizedPNL) {
        uint256 balanceUSDM = IERC20(USDM).balanceOf(player);
        unchecked {
            if (balanceUSDM >= totalAirdropUSDM) {
                realizedPNL = int256(balanceUSDM - totalAirdropUSDM);
            } else {
                realizedPNL = -int256(totalAirdropUSDM - balanceUSDM);
            }
        }
    }

    /**
     * @notice Calculates the realized and unrealized PNL for a given player
     * @param player The address of the player
     * @return realizedPNL The players realized PNL from USDM balance (signed integer)
     * @return unrealizedPNL The players unrealized PNL from current token holdings (integer)
     */
    function getPNL(
        address player
    ) external view returns (int256 realizedPNL, int256 unrealizedPNL) {
        require(isParticipant[player], "Not a participant");

        realizedPNL = _realizedPNL(player);

        unrealizedPNL = 0;
        if (currentToken != address(0)) {
            uint256 tokenBalance = IERC20(currentToken).balanceOf(player);
            if (tokenBalance > 0) {
                address[] memory path = new address[](2);
                path[0] = currentToken;
                path[1] = USDM;
                uint256[] memory amounts = IUniswapV2Router02(ROUTER)
                    .getAmountsOut(tokenBalance, path);
                uint256 valueInUSDM = amounts[1];
                unrealizedPNL = int256(valueInUSDM);
            }
        }
    }

    /**
     * @dev Executes an arbitrary call
     */
    function executeCall(
        address target,
        bytes calldata data,
        uint256 value
    ) external onlyOwner returns (bool success, bytes memory result) {
        (success, result) = target.call{value: value}(data);
        return (success, result);
    }
}
