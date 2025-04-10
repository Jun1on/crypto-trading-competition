// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./Competition.sol";

// helpers for the frontend
contract Periphery {
    function getParticipants(
        address _competitionAddress
    ) external view returns (address[] memory) {
        Competition competition = Competition(_competitionAddress);
        uint256 len = competition.participantsLength();
        address[] memory participantsArray = new address[](len);
        for (uint256 i = 0; i < len; ) {
            participantsArray[i] = competition.participants(i);
            unchecked {
                i++;
            }
        }
        return participantsArray;
    }

    function getPNLs(
        address _competitionAddress
    )
        external
        view
        returns (
            address[] memory participantsArray,
            int256[] memory realizedPNLs,
            int256[] memory unrealizedPNLs
        )
    {
        Competition competition = Competition(_competitionAddress);
        uint256 len = competition.participantsLength();
        participantsArray = new address[](len);
        realizedPNLs = new int256[](len);
        unrealizedPNLs = new int256[](len);
        for (uint256 i = 0; i < len; ) {
            address participant = competition.participants(i);
            (int256 realized, int256 unrealized) = competition.getPNL(
                participant
            );
            participantsArray[i] = participant;
            realizedPNLs[i] = realized;
            unrealizedPNLs[i] = unrealized;
            unchecked {
                i++;
            }
        }
    }
}
