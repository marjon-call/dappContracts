// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../src/LPAPoints.sol";

contract LPAPointsTest is Test {

    LPAPoints pointsContract;
    address admin;
    address plebian;

    event PointsPurchased(address indexed buyer, uint256 indexed tokenId, uint256 amountWei);

    function setUp() public {
        admin = address(0x01234);
        plebian = address(0x4321);

        vm.prank(admin);
        pointsContract = new LPAPoints();
    }

    function test_purchasePoints() public {
        vm.deal(plebian, 1 ether);

        vm.startPrank(plebian);

        vm.expectEmit(true, true, false, true);
        emit PointsPurchased(plebian, 1, 0.5 ether);
        pointsContract.purchasePoints{value: 0.5 ether}(1);
        assertEq(address(pointsContract).balance, 0.5 ether);

        vm.expectEmit(true, true, false, true);
        emit PointsPurchased(plebian, 1337, 0.3 ether);
        pointsContract.purchasePoints{value: 0.3 ether}(1337);
        assertEq(address(pointsContract).balance, 0.8 ether);

        vm.expectEmit(true, true, false, true);
        emit PointsPurchased(plebian, 9999, 0.2 ether);
        pointsContract.purchasePoints{value: 0.2 ether}(9999);
        assertEq(address(pointsContract).balance, 1.0 ether);

        vm.stopPrank();
    }

    function test_withdrawFunds() public {
        vm.deal(plebian, 1 ether);
        vm.startPrank(plebian);
        pointsContract.purchasePoints{value: 0.5 ether}(1);
        assertEq(address(pointsContract).balance, 0.5 ether);

        // should fail
        vm.expectRevert("Ownable: caller is not the owner");
        pointsContract.withdrawFunds(payable(plebian));
        vm.stopPrank();

        address receiverAddress = address(0x12121212);

        vm.startPrank(admin); 
        pointsContract.withdrawFunds(payable(receiverAddress));
        assertEq(receiverAddress.balance, 0.5 ether);
        assertEq(address(pointsContract).balance, 0 ether);
        vm.stopPrank();

    }

}
