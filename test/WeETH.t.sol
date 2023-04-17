// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract WethETHTest is TestSetup {

    function setUp() public {
        setUpTests();
    }

    function test_WrapEETHFailsIfZeroAmount() public {
        vm.expectRevert("wstETH: can't wrap zero stETH");
        weEthInstance.wrap(0);
    }

    function test_WrapWorksCorrectly() public {

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (bool sent, ) = address(liquidityPoolInstance).call{value: 100 ether}("");
        require(sent, "Failed to send Ether");

        vm.prank(address(liquidityPoolInstance));
        eETHInstance.mintShares(alice, 100);
        assertEq(eETHInstance.shares(alice), 100);

        vm.startPrank(alice);
        eETHInstance.approve(address(weEthInstance), 100);
        weEthInstance.wrap(50);
        assertEq(eETHInstance.shares(alice), 50);
        assertEq(eETHInstance.shares(address(weEthInstance)), 50);
        assertEq(weEthInstance.balanceOf(alice), 50);

        vm.stopPrank();
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (sent, ) = address(liquidityPoolInstance).call{value: 500 ether}("");
        require(sent, "Failed to send Ether");

        vm.prank(address(liquidityPoolInstance));
        eETHInstance.mintShares(bob, 200);
        assertEq(eETHInstance.shares(bob), 200);

        vm.startPrank(bob);
        eETHInstance.approve(address(weEthInstance), 200);
        weEthInstance.wrap(100);
        assertEq(eETHInstance.shares(bob), 150);
        assertEq(eETHInstance.shares(address(weEthInstance)), 100);
        assertEq(weEthInstance.balanceOf(bob), 50);
        vm.stopPrank();

        vm.prank(address(liquidityPoolInstance));
        eETHInstance.mintShares(dan, 500);
        assertEq(eETHInstance.shares(dan), 500);

        vm.startPrank(dan);
        eETHInstance.approve(address(weEthInstance), 500);
        weEthInstance.wrap(300);
        assertEq(eETHInstance.shares(dan), 100);
        assertEq(eETHInstance.shares(address(weEthInstance)), 500);
        assertEq(weEthInstance.balanceOf(dan), 400);
    }

    function test_UnWrapEETHFailsIfZeroAmount() public {
        vm.expectRevert("Cannot wrap a zero amount");
        weEthInstance.unwrap(0);
    }

    function test_UnWrapWorksCorrectly() public {
        // Total pooled ether = 10
        vm.deal(address(liquidityPoolInstance), 10 ether);
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 10 ether);
        assertEq(eETHInstance.totalSupply(), 10 ether);

        // Total pooled ether = 20
        hoax(alice);
        liquidityPoolInstance.deposit{value: 10 ether}(alice);

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 20 ether);
        assertEq(eETHInstance.totalSupply(), 20 ether);

        // ALice is first so get 100% of shares
        assertEq(eETHInstance.shares(alice), 10 ether);
        assertEq(eETHInstance.totalShares(), 10 ether);

        startHoax(alice);

        //Approve the wrapped eth contract to spend 100 eEth
        eETHInstance.approve(address(weEthInstance), 100 ether);
        weEthInstance.wrap(5 ether);

        assertEq(eETHInstance.shares(alice), 7.5 ether);
        assertEq(eETHInstance.shares(address(weEthInstance)), 2.5 ether);
        assertEq(eETHInstance.totalShares(), 10 ether);
        assertEq(weEthInstance.balanceOf(alice), 2.5 ether);

        weEthInstance.unwrap(2.5 ether);

        assertEq(eETHInstance.shares(alice), 10 ether);
        assertEq(eETHInstance.shares(address(weEthInstance)), 0  ether);
        assertEq(eETHInstance.totalShares(), 10 ether);
        assertEq(weEthInstance.balanceOf(alice), 0 ether);


        // ALice total claimable Ether
        /// (20 * 10) / 10
        // assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 20 ether);

        // hoax(bob);
        // liquidityPoolInstance.deposit{value: 5 ether}(bob);

        // assertEq(liquidityPoolInstance.getTotalPooledEther(), 25 ether);
        // assertEq(eETHInstance.totalSupply(), 25 ether);

        // // Bob Shares = (5 * 10) / (25 - 5) = 2,5
        // assertEq(eETHInstance.shares(bob), 2.5 ether);
        // assertEq(eETHInstance.totalShares(), 12.5 ether);

        // Bob claimable Ether
        /// (25 * 2,5) / 12,5 = 5 ether

        //ALice Claimable Ether
        /// (25 * 10) / 12,5 = 20 ether
        // assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 20 ether);
        // assertEq(liquidityPoolInstance.getTotalEtherClaimOf(bob), 5 ether);

        // assertEq(eETHInstance.balanceOf(alice), 20 ether);
        // assertEq(eETHInstance.balanceOf(bob), 5 ether);

        // Staking Rewards sent to liquidity pool
        /// vm.deal sets the balance of whoever its called on
        /// In this case 10 ether is added as reward 
        // vm.deal(address(liquidityPoolInstance), 35 ether);
        
        // assertEq(liquidityPoolInstance.getTotalPooledEther(), 35 ether);
        // assertEq(eETHInstance.totalSupply(), 35 ether);

        // Bob claimable Ether
        /// (35 * 2,5) / 12,5 = 7 ether
        //assertEq(liquidityPoolInstance.getTotalEtherClaimOf(bob), 7 ether);

        // Alice Claimable Ether
        /// (35 * 10) / 12,5 = 20 ether
        // assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 28 ether);

        // assertEq(eETHInstance.balanceOf(alice), 28 ether);
        // assertEq(eETHInstance.balanceOf(bob), 7 ether);

        // hoax(alice);
        // weEthInstance.wrap()
    }
}
