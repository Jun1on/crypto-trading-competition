// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/access/Ownable.sol";
import "./Competition.sol";
import "../interfaces/IUniswapV2Factory.sol";

// helpers for the frontend. not gas optimized.
contract Periphery is Ownable(msg.sender) {
    address constant FACTORY = 0x0c3c1c532F1e39EdF36BE9Fe0bE1410313E074Bf;

    function distributeGas(
        address _competitionAddress,
        uint256 amount
    ) external payable {
        Competition competition = Competition(_competitionAddress);
        uint256 len = competition.participantsLength();

        for (uint256 i = 0; i < len; ) {
            address payable p = payable(competition.participants(i));
            unchecked {
                uint256 diff = amount > p.balance ? amount - p.balance : 0;
                p.call{value: diff}("");
                i++;
            }
        }

        payable(msg.sender).call{value: address(this).balance}("");
    }

    function mmInfo(
        address _competitionAddress,
        address _mm
    )
        external
        view
        returns (
            address token,
            uint256 usdmBalance,
            uint256 tokenBalance,
            uint256 usdmLP,
            uint256 tokenLP
        )
    {
        Competition competition = Competition(_competitionAddress);

        uint256 endTimestamp;
        (, , token, , endTimestamp, ) = competition.rounds(
            competition.currentRound()
        );

        // Round closed → nothing to report
        if (block.timestamp >= endTimestamp) {
            return (address(0), 0, 0, 0, 0);
        }

        address usdm = competition.USDM();
        address pair = IUniswapV2Factory(FACTORY).getPair(token, usdm);

        usdmBalance = IERC20(usdm).balanceOf(_mm);
        tokenBalance = IERC20(token).balanceOf(_mm);

        if (pair != address(0)) {
            usdmLP = IERC20(usdm).balanceOf(pair);
            tokenLP = IERC20(token).balanceOf(pair);
        }

        return (token, usdmBalance, tokenBalance, usdmLP, tokenLP);
    }

    /**
     * @notice cumulative PNLs
     */
    function getPNLs(
        address _competitionAddress
    )
        external
        view
        returns (
            address[] memory participants,
            int256[] memory realizedPNLs,
            int256[] memory unrealizedPNLs,
            int256 mmRealized,
            int256 mmUnrealized
        )
    {
        Competition competition = Competition(_competitionAddress);
        uint256 len = competition.participantsLength();
        participants = new address[](len);
        realizedPNLs = new int256[](len);
        unrealizedPNLs = new int256[](len);
        for (uint256 i = 0; i < len; i++) {
            address participant = competition.participants(i);
            (int256 realized, int256 unrealized) = competition.getPNL(
                participant
            );
            participants[i] = participant;
            realizedPNLs[i] = realized;
            unrealizedPNLs[i] = unrealized;
        }
        (mmRealized, mmUnrealized) = _getMMPNL(_competitionAddress);
    }

    /**
     * @param _round use max for current round
     */
    function getRoundDetails(
        address _competitionAddress,
        uint256 _round,
        address _participant
    )
        external
        view
        returns (
            address USDM,
            uint256 latestRound,
            string memory name,
            string memory symbol,
            address token,
            uint256 startTimestamp,
            uint256 endTimestamp,
            uint256 airdropPerParticipantUSDM,
            uint256 usdmBalance,
            uint256 tokenBalance,
            uint256 trades
        )
    {
        Competition competition = Competition(_competitionAddress);
        USDM = competition.USDM();
        latestRound = _latestRound(_competitionAddress);
        if (_round == type(uint256).max) {
            _round = latestRound;
        }
        (
            name,
            symbol,
            token,
            startTimestamp,
            endTimestamp,
            airdropPerParticipantUSDM
        ) = competition.rounds(_round);

        if (_participant != address(0)) {
            usdmBalance = IERC20(USDM).balanceOf(_participant);
            tokenBalance = IERC20(token).balanceOf(_participant);
            trades = MockToken(token).trades(_participant);
        }
    }

    /**
     * @param _round use max for current round
     */
    function getRoundPNLs(
        address _competitionAddress,
        uint256 _round
    )
        external
        view
        returns (
            address[] memory participants,
            int256[] memory realizedPNLs,
            int256[] memory unrealizedPNLs,
            int256 mmRealized,
            int256 mmUnrealized
        )
    {
        Competition competition = Competition(_competitionAddress);
        if (_round == type(uint256).max) {
            _round = _latestRound(_competitionAddress);
        }
        uint256 len = competition.participantsLength();
        participants = new address[](len);
        realizedPNLs = new int256[](len);
        unrealizedPNLs = new int256[](len);
        for (uint256 i = 0; i < len; i++) {
            address participant = competition.participants(i);
            (int256 realized, int256 unrealized) = _getPNLAtRound(
                _competitionAddress,
                participant,
                _round
            );
            participants[i] = participant;
            realizedPNLs[i] = realized;
            unrealizedPNLs[i] = unrealized;
        }
        (mmRealized, mmUnrealized) = _getMMPNLAtRound(
            _competitionAddress,
            _round
        );
    }

    /*
    @return participationScores: 0, 1, or 2 based on tasks done in the latest round
    */
    function getParticipation(
        address _competitionAddress
    )
        external
        view
        returns (
            uint256 latestRound,
            address[] memory participants,
            uint256[] memory participationScores,
            uint256[] memory trades
        )
    {
        Competition competition = Competition(_competitionAddress);
        latestRound = _latestRound(_competitionAddress);
        uint256 len = competition.participantsLength();
        participants = new address[](len);
        participationScores = new uint256[](len);
        trades = new uint256[](len);
        (, , address token, , , ) = competition.rounds(latestRound);
        for (uint256 i = 0; i < len; i++) {
            address participant = competition.participants(i);

            (int256 roundRealized, int256 roundUnrealized) = _getPNLAtRound(
                _competitionAddress,
                participant,
                latestRound
            );
            int256 roundPNL = roundRealized + roundUnrealized;
            bool hasPNL = roundPNL != 0;

            if (hasPNL) {
                bool hasToken = MockToken(token).balanceOf(participant) >
                    100 gwei;
                participationScores[i] = hasToken ? 1 : 2;
            } else {
                participationScores[i] = 0;
            }

            (, , address roundToken, , , ) = competition.rounds(latestRound);
            trades[i] = MockToken(roundToken).trades(participant);

            participants[i] = participant;
        }
    }

    function getStats(
        address _competitionAddress,
        address _participant
    ) external view returns (int256[] memory PNLs, uint256[] memory trades) {
        Competition competition = Competition(_competitionAddress);
        uint256 len = _latestRound(_competitionAddress) + 1;
        PNLs = new int256[](len);
        trades = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            (int256 realized, int256 unrealized) = _getPNLAtRound(
                _competitionAddress,
                _participant,
                i
            );
            PNLs[i] = realized + unrealized;
            (, , address roundToken, , , ) = competition.rounds(i);
            trades[i] = MockToken(roundToken).trades(_participant);
        }
    }

    function _getPNLAtRound(
        address _competitionAddress,
        address _participant,
        uint256 _round
    ) public view returns (int256 realized, int256 unrealized) {
        Competition competition = Competition(_competitionAddress);
        uint256 currentRound = competition.currentRound();
        require(_round <= currentRound, "Round does not exist");

        int256 previousPNL = _round == 0
            ? int256(0)
            : competition.playerPNLHistory(_participant, _round - 1);

        if (_round == currentRound) {
            (realized, unrealized) = competition.getPNL(_participant);
        } else {
            realized = competition.playerPNLHistory(_participant, _round);
            // unrealized is always zero for past rounds
        }
        realized -= previousPNL;
    }

    /**
     * @notice Market Maker PNL is calculated as 0 - sum of everyone's PNL
     */
    function _getMMPNL(
        address _competitionAddress
    ) public view returns (int256 realized, int256 unrealized) {
        Competition competition = Competition(_competitionAddress);
        uint256 currentRound = competition.currentRound();

        (, , address token, , , ) = competition.rounds(currentRound);
        uint256 len = competition.participantsLength();
        bool roundStarted = token != address(0);
        if (roundStarted) {
            uint256 tokensOwnedByPeople;
            for (uint256 i = 0; i < len; i++) {
                address participant = competition.participants(i);
                (int256 realizedPNL, ) = competition.getPNL(participant);
                realized -= realizedPNL;
                tokensOwnedByPeople += MockToken(token).balanceOf(participant);
            }
            if (tokensOwnedByPeople > 0) {
                address[] memory path = new address[](2);
                path[0] = token;
                path[1] = competition.USDM();
                uint256 amountOut = IUniswapV2Router02(competition.ROUTER())
                    .getAmountsOut(tokensOwnedByPeople, path)[1];
                unrealized -= int256(amountOut);
            }
        } else {
            for (uint256 i = 0; i < len; i++) {
                address participant = competition.participants(i);
                (int256 realizedPNL, ) = competition.getPNL(participant);
                realized -= realizedPNL;
            }
        }
    }

    function _getMMPnlAtLatestRound(
        address _competitionAddress
    ) public view returns (int256 realized, int256 unrealized) {
        Competition competition = Competition(_competitionAddress);
        uint256 currentRound = competition.currentRound();
        (, , address token, , , ) = competition.rounds(currentRound);
        require(token != address(0), "Round has not started");
        uint256 len = competition.participantsLength();
        uint256 tokensOwnedByPeople;

        for (uint256 i = 0; i < len; i++) {
            address participant = competition.participants(i);
            (int256 realizedPNL, ) = _getPNLAtRound(
                _competitionAddress,
                participant,
                currentRound
            );
            realized -= realizedPNL;
            tokensOwnedByPeople += MockToken(token).balanceOf(participant);
        }
        if (tokensOwnedByPeople > 0) {
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = competition.USDM();
            uint256 amountOut = IUniswapV2Router02(competition.ROUTER())
                .getAmountsOut(tokensOwnedByPeople, path)[1];
            unrealized -= int256(amountOut);
        }
    }

    function _getMMPNLAtRound(
        address _competitionAddress,
        uint256 _round
    ) public view returns (int256 realized, int256 unrealized) {
        Competition competition = Competition(_competitionAddress);
        uint256 currentRound = competition.currentRound();
        require(_round <= currentRound, "Round does not exist");

        uint256 len = competition.participantsLength();
        bool latestRoundAndStarted = _round == currentRound &&
            currentRound == _latestRound(_competitionAddress);
        if (latestRoundAndStarted) {
            (realized, unrealized) = _getMMPnlAtLatestRound(
                _competitionAddress
            );
        } else {
            for (uint256 i = 0; i < len; i++) {
                address participant = competition.participants(i);
                (int256 realizedPNL, ) = _getPNLAtRound(
                    _competitionAddress,
                    participant,
                    _round
                );
                realized -= realizedPNL;
            }
        }
    }

    function _latestRound(
        address _competitionAddress
    ) public view returns (uint256 latestRound) {
        Competition competition = Competition(_competitionAddress);
        uint256 currentRound = competition.currentRound();
        (, , address token, , , ) = competition.rounds(currentRound);
        if (token != address(0)) {
            latestRound = currentRound;
        } else {
            latestRound = currentRound - 1;
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
