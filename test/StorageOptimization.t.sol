// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TestSetup.sol";
import "forge-std/console2.sol";


contract A {
    uint256 a1 = 1;
    uint256 a2 = 2;
    uint256 a3 = 3;
    uint256 a4 = 4;
    uint256 a5 = 5;
    uint256 a6 = 7;
    uint256 a7 = 8;
    uint256 a8 = 8;

    function doSomething(uint256 _referecneCounterPerVariable) external view returns (uint256) {
        uint256 result;
        for (uint i = 0; i < _referecneCounterPerVariable; i++) {
            result += a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8;
        }
        return result;
    }

}

contract B {
    uint16 a1 = 1;
    uint16 a2 = 2;
    uint16 a3 = 3;
    uint16 a4 = 4;
    uint16 a5 = 5;
    uint16 a6 = 6;
    uint16 a7 = 7;
    uint16 a8 = 8;

    function doSomething(uint256 _referecneCounterPerVariable) external view returns (uint256) {
        uint256 result;
        for (uint i = 0; i < _referecneCounterPerVariable; i++) {
            result += a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8;
        }
        return result;
    }

    function doSomethingBetter(uint256 _referecneCounterPerVariable) external view returns (uint256) {
        uint256 result;
        uint256 aa1 = a1;
        uint256 aa2 = a2;
        uint256 aa3 = a3;
        uint256 aa4 = a4;
        uint256 aa5 = a5;
        uint256 aa6 = a6;
        uint256 aa7 = a7;
        uint256 aa8 = a8;
        for (uint i = 0; i < _referecneCounterPerVariable; i++) {
            result += a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8;
        }
        return result;
    }
}

contract StorageOptimizationTest is TestSetup {

    A public a;
    B public b;

    function setUp() public {
        a = new A();
        b = new B();
    }

    function test_doSomethingOnceWithA() public {
        a.doSomething(1);
    }

    function test_doSomethingOnceWithB() public {
        b.doSomething(1);
    }

    function test_doSomethingOnceBetterWithB() public {
        b.doSomethingBetter(1);
    }

    function test_doSomethingAlotWithA() public {
        a.doSomething(10);
    }

    function test_doSomethingAlotWithB() public {
        b.doSomething(10);
    }

    function test_doSomethingAlotBetterWithB() public {
        b.doSomethingBetter(10);
    }
}