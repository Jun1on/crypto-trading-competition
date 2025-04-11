// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./Competition.sol";

// helpers for the frontend. not gas optimized.
contract Periphery {
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
     * @notice PNLs for a specific round
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

    function getLatestRoundDetails(
        address _competitionAddress
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
            uint256 airdropPerParticipantUSDM
        )
    {
        Competition competition = Competition(_competitionAddress);
        USDM = competition.USDM();
        latestRound = _latestRound(_competitionAddress);
        (
            name,
            symbol,
            token,
            startTimestamp,
            endTimestamp,
            airdropPerParticipantUSDM
        ) = competition.rounds(latestRound);
    }

    /**
     * @notice PNLs for the latest round
     */
    function getLatestRoundPNL(
        address _competitionAddress
    )
        external
        view
        returns (
            uint256 latestRound,
            address[] memory participants,
            int256[] memory realizedPNLs,
            int256[] memory unrealizedPNLs,
            int256 mmRealized,
            int256 mmUnrealized
        )
    {
        Competition competition = Competition(_competitionAddress);
        latestRound = _latestRound(_competitionAddress);
        uint256 len = competition.participantsLength();
        participants = new address[](len);
        realizedPNLs = new int256[](len);
        unrealizedPNLs = new int256[](len);
        for (uint256 i = 0; i < len; i++) {
            address participant = competition.participants(i);
            (int256 realized, int256 unrealized) = _getPNLAtRound(
                _competitionAddress,
                participant,
                latestRound
            );
            participants[i] = participant;
            realizedPNLs[i] = realized;
            unrealizedPNLs[i] = unrealized;
        }
        (mmRealized, mmUnrealized) = _getMMPNLAtRound(
            _competitionAddress,
            latestRound
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
    ) external view returns (uint256[] memory PNLs, uint256[] memory trades) {
        Competition competition = Competition(_competitionAddress);
        uint256 len = _latestRound(_competitionAddress) + 1;
        PNLs = new uint256[](len);
        trades = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            (int256 realized, int256 unrealized) = _getPNLAtRound(
                _competitionAddress,
                _participant,
                i
            );
            PNLs[i] = uint256(realized + unrealized);
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
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = competition.USDM();
            uint256 amountOut = IUniswapV2Router02(competition.ROUTER())
                .getAmountsOut(tokensOwnedByPeople, path)[1];
            unrealized -= int256(amountOut);
        } else {
            for (uint256 i = 0; i < len; i++) {
                address participant = competition.participants(i);
                (int256 realizedPNL, ) = competition.getPNL(participant);
                realized -= realizedPNL;
            }
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
            (realized, unrealized) = _getMMPNL(_competitionAddress);

            // subtract PNLs of participants in the round
            if (_round != 0) {
                for (uint256 i = 0; i < len; i++) {
                    address participant = competition.participants(i);
                    (int256 realizedPNL, ) = _getPNLAtRound(
                        _competitionAddress,
                        participant,
                        _round - 1
                    );
                    realized -= realizedPNL;
                }
            }
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
}
