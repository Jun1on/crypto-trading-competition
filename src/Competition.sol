// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/access/Ownable.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {MockToken} from "./MockToken.sol";
import {MockUSD} from "./MockUSD.sol";

contract Competition is Ownable {
    struct RoundInfo {
        string name;
        string symbol;
        address token;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 airdropPerParticipantUSDM;
    }

    address public constant ROUTER = 0x4A7b5Da61326A6379179b40d00F57E5bbDC962c2;
    address public immutable USDM;
    address public immutable marketMaker;
    address[] public participants;
    mapping(address => bool) public isParticipant;
    uint256 public totalAirdropUSDM;
    uint256 public currentRound;
    mapping(uint256 => RoundInfo) public rounds;
    mapping(address => mapping(uint256 => int256)) public playerPNLHistory;
    uint256 public participantsLength;
    uint256 public constant GRACE_PERIOD = 1 minutes;
    event RoundStarted(
        uint256 roundId,
        string name,
        string symbol,
        address token
    );
    event RoundEnded(uint256 roundId, address token);

    constructor(
        address _USDM,
        address _marketMaker,
        address[] memory _participants
    ) Ownable(msg.sender) {
        USDM = _USDM;
        marketMaker = _marketMaker;

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
        uint256 marketMakerUSDM,
        uint256 marketMakerShare,
        uint256 airdropUSDM,
        uint256 durationMinutes
    ) external onlyOwner {
        require(
            rounds[currentRound].token == address(0),
            "Round already active or not ended"
        );

        MockToken newToken = new MockToken(name, symbol);
        address currentTokenAddress = address(newToken);

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
        IUniswapV2Router02(ROUTER).addLiquidity(
            currentTokenAddress,
            USDM,
            liquidityToken,
            liquidityUSDM,
            0,
            0,
            address(this),
            type(uint256).max
        );

        MockToken(currentTokenAddress).lock();

        uint256 startTimestamp = block.timestamp + GRACE_PERIOD;
        uint256 endTimestamp = startTimestamp + durationMinutes * 60;

        rounds[currentRound] = RoundInfo({
            name: name,
            symbol: symbol,
            token: currentTokenAddress,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            airdropPerParticipantUSDM: airdropUSDM
        });

        emit RoundStarted(currentRound, name, symbol, currentTokenAddress);
    }

    function endRound() external {
        RoundInfo storage currentRoundInfo = rounds[currentRound];
        if (msg.sender == owner()) {
            rounds[currentRound].endTimestamp = block.timestamp;
        } else {
            require(
                block.timestamp >= currentRoundInfo.endTimestamp,
                "Round not ended yet or not authorized"
            );
        }
        require(currentRoundInfo.token != address(0), "Round already ended");

        address tokenToEnd = currentRoundInfo.token;

        MockToken(tokenToEnd).unlock();

        uint256 amountToLiquidate;
        uint256 length = participants.length;
        for (uint256 i = 0; i < length; ) {
            address participant = participants[i];
            amountToLiquidate += MockToken(tokenToEnd).balanceOf(participant);
            unchecked {
                i++;
            }
        }

        if (amountToLiquidate > 0) {
            MockToken(tokenToEnd).mint(address(this), amountToLiquidate);
            address[] memory path = new address[](2);
            path[0] = tokenToEnd;
            path[1] = USDM;
            uint256[] memory amounts = IUniswapV2Router02(ROUTER)
                .swapExactTokensForTokens(
                    amountToLiquidate,
                    0,
                    path,
                    address(this),
                    type(uint256).max
                );

            uint256 totalUSDMReceived = amounts[1];

            for (uint256 i = 0; i < length; ) {
                address participant = participants[i];
                uint256 originalBalance = MockToken(tokenToEnd).balanceOf(
                    participant
                );

                if (originalBalance > 0) {
                    uint256 participantShare = (originalBalance *
                        totalUSDMReceived) / amountToLiquidate;

                    if (participantShare > 1 gwei) {
                        MockUSD(USDM).transfer(participant, participantShare);
                    }

                    MockToken(tokenToEnd).burn(participant, originalBalance);
                }

                unchecked {
                    i++;
                }
            }
        }

        MockUSD(USDM).burn(marketMaker, ERC20(USDM).balanceOf(marketMaker));

        MockToken(tokenToEnd).lock();

        emit RoundEnded(currentRound, tokenToEnd);

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
        uint256 totalReceivedUSDM = totalAirdropUSDM;
        unchecked {
            if (balanceUSDM >= totalReceivedUSDM) {
                realizedPNL = int256(balanceUSDM - totalReceivedUSDM);
            } else {
                realizedPNL = -int256(totalReceivedUSDM - balanceUSDM);
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
        RoundInfo storage currentRoundInfo = rounds[currentRound];
        if (currentRoundInfo.token != address(0)) {
            address currentTokenAddress = currentRoundInfo.token;
            uint256 tokenBalance = IERC20(currentTokenAddress).balanceOf(
                player
            );
            if (tokenBalance > 0) {
                address[] memory path = new address[](2);
                path[0] = currentTokenAddress;
                path[1] = USDM;
                try
                    IUniswapV2Router02(ROUTER).getAmountsOut(tokenBalance, path)
                returns (uint256[] memory amounts) {
                    uint256 valueInUSDM = amounts[1];
                    unrealizedPNL = int256(valueInUSDM);
                } catch {
                    unrealizedPNL = 0;
                }
            }
        }
    }

    /**
     * @dev Executes an arbitrary call
     */
    function zzz_executeCall(
        address target,
        bytes calldata data,
        uint256 value
    ) external onlyOwner returns (bool success, bytes memory result) {
        (success, result) = target.call{value: value}(data);
        return (success, result);
    }
}
