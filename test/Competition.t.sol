// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Competition} from "../src/Competition.sol";

contract CompetitionTest is Test {
    Competition public competition;

    function setUp() public {
        competition = new Competition();
        competition.setNumber(0);
    }

    function test_Increment() public {
        competition.increment();
        assertEq(competition.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        competition.setNumber(x);
        assertEq(competition.number(), x);
    }
}
