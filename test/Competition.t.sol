// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../src/Competition.sol";
import "../src/MockToken.sol";

contract CompetitionTest is Test {
    Competition competition;
    MockToken USDM;
    address owner = address(0x1);
    address[] participants = [address(0x2), address(0x3)];
    address constant ROUTER = 0x4A7b5Da61326A6379179b40d00F57E5bbDC962c2;

    function setUp() public {
        vm.createSelectFork("https://mainnet.optimism.io");

        vm.startPrank(owner);
        USDM = new MockToken("Mock USD", "USDM");
        competition = new Competition(address(USDM), address(99), participants);

        USDM.transferOwnership(address(competition));
        vm.stopPrank();
    }

    function testConstructor() public view {
        assertEq(competition.USDM(), address(USDM));
        assertEq(competition.participants(0), address(0x2));
        assertEq(competition.participants(1), address(0x3));
        assertTrue(competition.isParticipant(address(0x2)));
        assertEq(competition.owner(), owner);
    }

    function testStartRound() public {
        vm.startPrank(owner);
        competition.startRound(
            "TestToken",
            "TTK",
            1000e18,
            1000e18,
            100e18,
            0,
            0,
            50e18,
            10
        );

        (, , address currentToken, , , ) = competition.rounds(
            competition.currentRound()
        );
        assertTrue(currentToken != address(0));
        assertEq(MockToken(currentToken).balanceOf(owner), 100e18); // devShare
        assertEq(USDM.balanceOf(address(0x2)), 50e18);
        assertEq(USDM.balanceOf(address(0x3)), 50e18);
        assertEq(competition.totalAirdropUSDM(), 50e18);

        competition.endRound();

        competition.startRound(
            "TestToken2",
            "TTK2",
            1000e18,
            1000e18,
            100e18,
            100e18,
            100e18,
            50e18,
            10
        );
        competition.addPlayer(address(0x4));
        vm.stopPrank();
    }

    function testAddPlayer() public {
        vm.startPrank(owner);
        competition.startRound(
            "TestToken",
            "TTK",
            1000e18,
            1000e18,
            100e18,
            0,
            0,
            50e18,
            10
        );
        competition.addPlayer(address(0x4));

        assertTrue(competition.isParticipant(address(0x4)));
        assertEq(USDM.balanceOf(address(0x4)), 50e18);
        vm.stopPrank();
    }

    function testEndRound() public {
        vm.startPrank(owner);
        competition.startRound(
            "TestToken",
            "TTK",
            1000e18,
            1000e18,
            100e18,
            0,
            0,
            50e18,
            10
        );

        (, , address token, , , ) = competition.rounds(
            competition.currentRound()
        );

        competition.endRound();

        (, , address tokenAfterEnd, , , ) = competition.rounds(
            competition.currentRound()
        );
        assertEq(tokenAfterEnd, address(0));
        assertTrue(MockToken(token).tokenStatus() == 2);
        vm.stopPrank();
    }
}
