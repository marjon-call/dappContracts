// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/StakingManager.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/AuctionManager.sol";
import "../src/NodeOperatorKeyManager.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract TNFTTest is Test {
    StakingManager public stakingManagerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;
    AuctionManager public auctionInstance;
    Treasury public treasuryInstance;
    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
        auctionInstance = new AuctionManager(address(nodeOperatorKeyManagerInstance));
        treasuryInstance.setAuctionManagerContractAddress(address(auctionInstance));
        auctionInstance.updateMerkleRoot(root);
        stakingManagerInstance = new StakingManager(address(auctionInstance));
        auctionInstance.setStakingManagerContractAddress(address(stakingManagerInstance));
        TestBNFTInstance = BNFT(address(stakingManagerInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(stakingManagerInstance.TNFTInstance()));
        vm.stopPrank();
    }

    function test_TNFTContractGetsInstantiatedCorrectly() public {
        assertEq(
            TestTNFTInstance.stakingManagerContractAddress(),
            address(stakingManagerInstance)
        );
        assertEq(TestTNFTInstance.nftValue(), 0.03 ether);
    }

    function test_TNFTMintsFailsIfNotCorrectCaller() public {
        vm.startPrank(alice);
        vm.expectRevert("Only deposit contract function");
        TestTNFTInstance.mint(address(alice), 1);
    }

    function _merkleSetup() internal {
        merkle = new Merkle();

        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931)
            )
        );
        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf)
            )
        );
        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B)
            )
        );

        root = merkle.getRoot(whiteListedAddresses);
    }
}
