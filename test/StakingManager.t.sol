// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "src/EtherFiNodesManager.sol";
import "../src/StakingManager.sol";
import "../src/NodeOperatorKeyManager.sol";
import "../src/AuctionManager.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract StakingManagerTest is Test {
    IStakingManager public depositInterface;
    EtherFiNode public withdrawSafeInstance;
    EtherFiNodesManager public managerInstance;
    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;
    StakingManager public stakingManagerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    AuctionManager public auctionInstance;
    Treasury public treasuryInstance;
    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;

    IStakingManager.DepositData public test_data;
    IStakingManager.DepositData public test_data_2;

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
        stakingManagerInstance.setTreasuryAddress(address(treasuryInstance));

        auctionInstance.setStakingManagerContractAddress(address(stakingManagerInstance));

        TestBNFTInstance = BNFT(address(stakingManagerInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(stakingManagerInstance.TNFTInstance()));

        managerInstance = new EtherFiNodesManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestBNFTInstance),
            address(TestTNFTInstance)
        );

        stakingManagerInstance.setEtherFiNodesManagerAddress(address(managerInstance));
        auctionInstance.setEtherFiNodesManagerAddress(address(managerInstance));

        test_data = IStakingManager.DepositData({
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature",
            ipfsHashForEncryptedValidatorKey: "test_ipfs_hash"
        });

        test_data_2 = IStakingManager.DepositData({
            depositDataRoot: "test_deposit_root_2",
            publicKey: "test_pubkey_2",
            signature: "test_signature_2",
            ipfsHashForEncryptedValidatorKey: "test_ipfs_hash2"
        });

        vm.stopPrank();
    }

    function test_StakingManagerSwitchWorks() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        assertTrue(stakingManagerInstance.test());
        assertEq(stakingManagerInstance.stakeAmount(), 0.032 ether);

        stakingManagerInstance.switchMode();
        console.logBool(stakingManagerInstance.test());

        hoax(owner);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        hoax(alice);
        vm.expectRevert("Insufficient staking amount");
        stakingManagerInstance.depositForAuction{value: 0.033 ether}();

        stakingManagerInstance.switchMode();
        console.logBool(stakingManagerInstance.test());

        hoax(alice);
        vm.expectRevert("Insufficient staking amount");
        stakingManagerInstance.depositForAuction{value: 33 ether}();

        hoax(alice);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
    }

    function test_StakingManagerContractInstantiatedCorrectly() public {
        assertEq(stakingManagerInstance.stakeAmount(), 0.032 ether);
        assertEq(stakingManagerInstance.owner(), owner);
    }

    function test_GenerateWithdrawalCredentialsCorrectly() public {
        address exampleWithdrawalAddress = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        bytes memory withdrawalCredential = managerInstance.generateWithdrawalCredentials(exampleWithdrawalAddress);
        // Generated with './deposit new-mnemonic --eth1_withdrawal_address 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931'
        bytes memory trueOne = hex"010000000000000000000000cd5ebc2dd4cb3dc52ac66ceecc72c838b40a5931";
        assertEq(withdrawalCredential.length, trueOne.length);
        assertEq(keccak256(withdrawalCredential), keccak256(trueOne));
    }

    function test_StakingManagerCorrectlyInstantiatesStakeObject() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        stakingManagerInstance.registerValidator(bidId, test_data);
        
        uint256 validatorId = bidId;
        uint256 winningBid = bidId;
        address staker = stakingManagerInstance.getStakerRelatedToValidator(validatorId);
        address etherfiNode = managerInstance.getEtherFiNodeAddress(validatorId);

        assertEq(staker, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(stakingManagerInstance.stakeAmount(), 0.032 ether);
        assertEq(winningBid, bidId);
        assertEq(validatorId, bidId);

        assertEq(
            IEtherFiNode(etherfiNode).getIpfsHashForEncryptedValidatorKey(),
            test_data.ipfsHashForEncryptedValidatorKey
        );
        assertEq(
            managerInstance.getEtherFiNodeIpfsHashForEncryptedValidatorKey(validatorId),
            test_data.ipfsHashForEncryptedValidatorKey
        );
    }

    function test_BatchDepositForAuctionFailsIFInvalidDepositAmount() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        uint256 bidIdTwo = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        uint256 bidIdThree = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        uint256 bidIdFour = auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        vm.expectRevert("Insufficient staking amount");
        stakingManagerInstance.depositForAuction{value: 0.095 ether}();
    }

    function test_BatchDepositForAuctionFailsIfNoMoreActiveBids() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        uint256 bidIdTwo = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
     
        vm.expectRevert("No bids available at the moment");
        stakingManagerInstance.depositForAuction{value: 0.096 ether}();
    }

    function test_BatchDepositWithBidIdsFailsIfNotEnoughActiveBids() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);

        uint256[] memory bidIdArray = new uint256[](10);        
        bidIdArray[0] = 1;
        bidIdArray[1] = 2;
        bidIdArray[2] = 6;
        bidIdArray[3] = 7;
        bidIdArray[4] = 8;
        bidIdArray[5] = 9;
        bidIdArray[6] = 11;
        bidIdArray[7] = 12;
        bidIdArray[8] = 19;
        bidIdArray[9] = 20;

        vm.expectRevert("No bids available at the moment");
        stakingManagerInstance.batchDepositWithBidIds{value: 0.32 ether}(bidIdArray);
    }

    function test_BatchDepositWithBidIdsFailsIfNoIdsProvided() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        for(uint256 x = 0; x < 10; x++) {
            auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        }
        for(uint256 x = 0; x < 10; x++) {
            auctionInstance.bidOnStake{value: 0.2 ether}(proof);
        }

        assertEq(auctionInstance.numberOfActiveBids(), 20);
        assertEq(auctionInstance.currentHighestBidId(), 11);

        uint256[] memory bidIdArray = new uint256[](0);        

        vm.expectRevert("No bid Ids provided");
        stakingManagerInstance.batchDepositWithBidIds{value: 0.32 ether}(bidIdArray);
    }

    function test_BatchDepositWithBidIdsFailsIfPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        for(uint256 x = 0; x < 10; x++) {
            auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        }
        for(uint256 x = 0; x < 10; x++) {
            auctionInstance.bidOnStake{value: 0.2 ether}(proof);
        }

        assertEq(auctionInstance.numberOfActiveBids(), 20);
        assertEq(auctionInstance.currentHighestBidId(), 11);

        uint256[] memory bidIdArray = new uint256[](10);        
        bidIdArray[0] = 1;
        bidIdArray[1] = 2;
        bidIdArray[2] = 6;
        bidIdArray[3] = 7;
        bidIdArray[4] = 8;
        bidIdArray[5] = 9;
        bidIdArray[6] = 11;
        bidIdArray[7] = 12;
        bidIdArray[8] = 19;
        bidIdArray[9] = 20;

        vm.stopPrank();

        vm.prank(owner);
        stakingManagerInstance.pauseContract();

        vm.expectRevert("Pausable: paused");
        stakingManagerInstance.batchDepositWithBidIds{value: 0.32 ether}(bidIdArray);
    }

    function test_BatchDepositForAuctionWorks() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        uint256 bidIdTwo = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        uint256 bidIdThree = auctionInstance.bidOnStake{value: 0.8 ether}(proof);
        uint256 bidIdFour = auctionInstance.bidOnStake{value: 1.3 ether}(proof);
        uint256 bidIdFive = auctionInstance.bidOnStake{value: 1.8 ether}(proof);
        uint256 bidIdSix = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        uint256 bidIdSeven = auctionInstance.bidOnStake{value: 0.2 ether}(proof);

        stakingManagerInstance.depositForAuction{value: 0.192 ether}();

        assertEq(auctionInstance.numberOfActiveBids(), 1);

        (,,,, bool isActive) = auctionInstance.bids(bidId);
        assertEq(isActive, false);
        (,,,, isActive) = auctionInstance.bids(bidIdTwo);
        assertEq(isActive, false);
        (,,,, isActive) = auctionInstance.bids(bidIdThree);
        assertEq(isActive, false);
        (,,,, isActive) = auctionInstance.bids(bidIdFour);
        assertEq(isActive, false);
        (,,,, isActive) = auctionInstance.bids(bidIdFive);
        assertEq(isActive, false);
        (,,,, isActive) = auctionInstance.bids(bidIdSeven);
        assertEq(isActive, false);
        (,,,, isActive) = auctionInstance.bids(bidIdSix);
        assertEq(isActive, true);

        stakingManagerInstance.registerValidator(bidId, test_data);
        stakingManagerInstance.registerValidator(bidIdTwo, test_data);
        stakingManagerInstance.registerValidator(bidIdThree, test_data);
        stakingManagerInstance.registerValidator(bidIdFour, test_data);
        stakingManagerInstance.registerValidator(bidIdFive, test_data);
        stakingManagerInstance.registerValidator(bidIdSeven, test_data);

        address etherfiNodeBidOne = managerInstance.getEtherFiNodeAddress(bidId);
        assertEq(etherfiNodeBidOne.balance, 0.1 ether);
        address etherfiNodeBidTwo = managerInstance.getEtherFiNodeAddress(bidIdTwo);
        assertEq(etherfiNodeBidTwo.balance, 0.1 ether);
        address etherfiNodeBidThree = managerInstance.getEtherFiNodeAddress(bidIdThree);
        assertEq(etherfiNodeBidThree.balance, 0.8 ether);
        address etherfiNodeBidFour = managerInstance.getEtherFiNodeAddress(bidIdFour);
        assertEq(etherfiNodeBidFour.balance, 1.3 ether);
        address etherfiNodeBidFive = managerInstance.getEtherFiNodeAddress(bidIdFive);
        assertEq(etherfiNodeBidFive.balance, 1.8 ether);
        address etherfiNodeBidSeven = managerInstance.getEtherFiNodeAddress(bidIdSeven);
        assertEq(etherfiNodeBidSeven.balance, 0.2 ether);

    }

    function test_StakingManagerReceivesEther() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        assertEq(address(stakingManagerInstance).balance, 0.032 ether);
    }

    function test_DepositFailsBidDoesntExist() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        auctionInstance.cancelBid(1);
        vm.expectRevert("No bids available at the moment");
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
    }

    function test_DepositFailsIfContractPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(owner);
        stakingManagerInstance.pauseContract();

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        vm.expectRevert("Pausable: paused");
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        assertEq(stakingManagerInstance.paused(), true);
        vm.stopPrank();

        vm.prank(owner);
        stakingManagerInstance.unPauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        assertEq(stakingManagerInstance.paused(), false);
        assertEq(address(stakingManagerInstance).balance, 0.032 ether);
    }

    function test_BatchDepositForAuctionSimpleWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        for(uint256 x = 0; x < 10; x++) {
            auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        }
        for(uint256 x = 0; x < 10; x++) {
            auctionInstance.bidOnStake{value: 0.2 ether}(proof);
        }

        assertEq(auctionInstance.numberOfActiveBids(), 20);
        assertEq(auctionInstance.currentHighestBidId(), 11);

        stakingManagerInstance.depositForAuction{value: 0.352 ether}();
        assertEq(auctionInstance.numberOfActiveBids(), 9);
        assertEq(auctionInstance.currentHighestBidId(), 2);

        (uint256 amount ,,,, bool isActive) = auctionInstance.bids(11);
        assertEq(amount, 0.2 ether);
        assertEq(isActive, false);

        (amount ,,,, isActive) = auctionInstance.bids(7);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, true);

        (amount ,,,, isActive) = auctionInstance.bids(12);
        assertEq(amount, 0.2 ether);
        assertEq(isActive, false);

        (amount ,,,, isActive) = auctionInstance.bids(13);
        assertEq(amount, 0.2 ether);
        assertEq(isActive, false);
    }

    function test_BatchDepositWithIdsSimpleWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        for(uint256 x = 0; x < 10; x++) {
            auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        }
        for(uint256 x = 0; x < 10; x++) {
            auctionInstance.bidOnStake{value: 0.2 ether}(proof);
        }

        assertEq(auctionInstance.numberOfActiveBids(), 20);
        assertEq(auctionInstance.currentHighestBidId(), 11);

        uint256[] memory bidIdArray = new uint256[](10);        
        bidIdArray[0] = 1;
        bidIdArray[1] = 2;
        bidIdArray[2] = 6;
        bidIdArray[3] = 7;
        bidIdArray[4] = 8;
        bidIdArray[5] = 9;
        bidIdArray[6] = 11;
        bidIdArray[7] = 12;
        bidIdArray[8] = 19;
        bidIdArray[9] = 20;

        stakingManagerInstance.batchDepositWithBidIds{value: 0.32 ether}(bidIdArray);
        assertEq(auctionInstance.numberOfActiveBids(), 10);
        assertEq(auctionInstance.currentHighestBidId(), 13);

        (uint256 amount ,,,, bool isActive) = auctionInstance.bids(1);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);

        (amount ,,,, isActive) = auctionInstance.bids(7);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);

        (amount ,,,, isActive) = auctionInstance.bids(20);
        assertEq(amount, 0.2 ether);
        assertEq(isActive, false);

        (amount ,,,, isActive) = auctionInstance.bids(3);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, true);

    }

    function test_BatchDepositWithIdsComplexWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        for(uint256 x = 0; x < 10; x++) {
            auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        }
        for(uint256 x = 0; x < 10; x++) {
            auctionInstance.bidOnStake{value: 0.2 ether}(proof);
        }

        assertEq(auctionInstance.numberOfActiveBids(), 20);
        assertEq(auctionInstance.currentHighestBidId(), 11);
        assertEq(address(auctionInstance).balance, 3 ether);

        uint256[] memory bidIdArray = new uint256[](10);        
        bidIdArray[0] = 1;
        bidIdArray[1] = 2;
        bidIdArray[2] = 6;
        bidIdArray[3] = 7;
        bidIdArray[4] = 8;
        bidIdArray[5] = 9;
        bidIdArray[6] = 11;
        bidIdArray[7] = 12;
        bidIdArray[8] = 19;
        bidIdArray[9] = 20;

        stakingManagerInstance.batchDepositWithBidIds{value: 0.32 ether}(bidIdArray);
        assertEq(auctionInstance.numberOfActiveBids(), 10);
        assertEq(auctionInstance.currentHighestBidId(), 13);

        (uint256 amount ,,,, bool isActive) = auctionInstance.bids(1);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);

        (amount ,,,, isActive) = auctionInstance.bids(7);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);

        (amount ,,,, isActive) = auctionInstance.bids(20);
        assertEq(amount, 0.2 ether);
        assertEq(isActive, false);

        (amount ,,,, isActive) = auctionInstance.bids(3);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, true);

        uint256 userBalanceBefore = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance;

        uint256[] memory bidIdArray2 = new uint256[](10);        
        bidIdArray2[0] = 1;
        bidIdArray2[1] = 3;
        bidIdArray2[2] = 6;
        bidIdArray2[3] = 7;
        bidIdArray2[4] = 8;
        bidIdArray2[5] = 13;
        bidIdArray2[6] = 11;
        bidIdArray2[7] = 12;
        bidIdArray2[8] = 19;
        bidIdArray2[9] = 20;

        stakingManagerInstance.batchDepositWithBidIds{value: 0.16 ether}(bidIdArray2);

        assertEq(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance, userBalanceBefore - 0.064 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 8);
        assertEq(auctionInstance.currentHighestBidId(), 14);

        (amount ,,,, isActive) = auctionInstance.bids(1);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);

        (amount ,,,, isActive) = auctionInstance.bids(13);
        assertEq(amount, 0.2 ether);
        assertEq(isActive, false);

        (amount ,,,, isActive) = auctionInstance.bids(3);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);
    }

    function test_EtherFailSafeWorks() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 walletBalance = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        assertEq(address(stakingManagerInstance).balance, 0.032 ether);
        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            walletBalance - 0.132 ether
        );
        vm.stopPrank();

        vm.prank(owner);
        uint256 walletBalance2 = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;
        stakingManagerInstance.fetchEtherFromContract(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(address(stakingManagerInstance).balance, 0 ether);
        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            walletBalance - 0.1 ether
        );
    }

    function test_RegisterValidatorFailsIfIncorrectCaller() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Not deposit owner");
        stakingManagerInstance.registerValidator(bidId, test_data);
    }

    function test_RegisterValidatorFailsIfValidatorNotInCorrectPhase() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        stakingManagerInstance.cancelDeposit(bidId);

        vm.expectRevert("Deposit does not exist");
        stakingManagerInstance.registerValidator(bidId, test_data);
    }

    function test_RegisterValidatorFailsIfContractPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        vm.stopPrank();

        vm.prank(owner);
        stakingManagerInstance.pauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Pausable: paused");
        stakingManagerInstance.registerValidator(0, test_data);
    }

    function test_RegisterValidatorWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        stakingManagerInstance.registerValidator(bidId, test_data);

        uint256 selectedBidId = bidId;
        address etherFiNode = managerInstance.getEtherFiNodeAddress(bidId);

        assertEq(etherFiNode.balance, 0.1 ether);
        assertEq(selectedBidId, 1);
        assertEq(managerInstance.numberOfValidators(), 1);
        assertEq(address(managerInstance).balance, 0 ether);
        assertEq(address(auctionInstance).balance, 0);

        address operatorAddress = auctionInstance.getBidOwner(bidId);
        assertEq(operatorAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);

        address safeAddress = managerInstance.getEtherFiNodeAddress(bidId);
        assertEq(safeAddress, etherFiNode);

        assertEq(
            TestBNFTInstance.ownerOf(bidId),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestTNFTInstance.ownerOf(bidId),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestBNFTInstance.balanceOf(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            1
        );
        assertEq(
            TestTNFTInstance.balanceOf(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            1
        );
    }

    function test_cancelDepositFailsIfNotStakeOwner() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Not deposit owner");
        stakingManagerInstance.cancelDeposit(bidId);
    }

    function test_cancelDepositFailsIfCancellingAvailabilityClosed() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        stakingManagerInstance.cancelDeposit(bidId);

        vm.expectRevert("Deposit does not exist");
        stakingManagerInstance.cancelDeposit(bidId);
    }

    function test_cancelDepositWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId1 = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        uint256 bidId2 = auctionInstance.bidOnStake{value: 0.3 ether}(proof);
        uint256 bidId3 = auctionInstance.bidOnStake{value: 0.2 ether}(proof);

        assertEq(address(auctionInstance).balance, 0.6 ether);

        stakingManagerInstance.depositForAuction{value: 0.032 ether}(); // bidId2
        uint256 depositorBalance = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;

        uint256 selectedBidId = bidId2;
        address staker = stakingManagerInstance.getStakerRelatedToValidator(bidId2);
        address etherFiNode = managerInstance.getEtherFiNodeAddress(bidId2);

        assertEq(staker, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(selectedBidId, bidId2);
        assertTrue(IEtherFiNode(etherFiNode).getPhase() == IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED);

        (uint256 bidAmount, , , address bidder, bool isActive) = auctionInstance
            .bids(selectedBidId);
        assertEq(bidAmount, 0.3 ether);
        assertEq(bidder, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(isActive, false);
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        assertEq(auctionInstance.currentHighestBidId(), bidId3);
        assertEq(address(auctionInstance).balance, 0.6 ether);

        stakingManagerInstance.cancelDeposit(bidId2);
        assertEq(managerInstance.getEtherFiNodeAddress(bidId2), address(0));
        assertEq(stakingManagerInstance.getStakerRelatedToValidator(bidId2), address(0));
        assertTrue(IEtherFiNode(etherFiNode).getPhase() == IEtherFiNode.VALIDATOR_PHASE.CANCELLED);

        (bidAmount, , , bidder, isActive) = auctionInstance.bids(bidId2);
        assertEq(bidAmount, 0.3 ether);
        assertEq(bidder, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(isActive, true);
        assertEq(auctionInstance.numberOfActiveBids(), 3);
        assertEq(auctionInstance.currentHighestBidId(), bidId2);
        assertEq(address(auctionInstance).balance, 0.6 ether);

        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            depositorBalance + 0.032 ether
        );
    }

    function test_CorrectValidatorAttatchedToNft() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId1 = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        stakingManagerInstance.registerValidator(bidId1, test_data);

        vm.stopPrank();
        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        uint256 bidId2 = auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        stakingManagerInstance.registerValidator(bidId2, test_data);

        assertEq(
            TestBNFTInstance.ownerOf(bidId1),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestTNFTInstance.ownerOf(bidId1),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestBNFTInstance.ownerOf(bidId2),
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
        assertEq(
            TestTNFTInstance.ownerOf(bidId2),
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
        assertEq(
            TestBNFTInstance.balanceOf(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            1
        );
        assertEq(
            TestTNFTInstance.balanceOf(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            1
        );
        assertEq(
            TestBNFTInstance.balanceOf(
                0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
            ),
            1
        );
        assertEq(
            TestTNFTInstance.balanceOf(
                0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
            ),
            1
        );
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
