// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/interfaces/IEtherFiNode.sol";
import "src/EtherFiNodesManager.sol";
import "../src/StakingManager.sol";
import "../src/NodeOperatorKeyManager.sol";
import "../src/AuctionManager.sol";
import "../src/ProtocolRevenueManager.sol";
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
    ProtocolRevenueManager public protocolRevenueManagerInstance;
    Treasury public treasuryInstance;
    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;

    IStakingManager.DepositData public test_data;
    IStakingManager.DepositData public test_data_2;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    string _ipfsHash = "IPFSHash";

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
        auctionInstance = new AuctionManager(
            address(nodeOperatorKeyManagerInstance)
        );
        protocolRevenueManagerInstance = new ProtocolRevenueManager();

        auctionInstance.updateMerkleRoot(root);

        stakingManagerInstance = new StakingManager(address(auctionInstance));
        stakingManagerInstance.setTreasuryAddress(address(treasuryInstance));

        auctionInstance.setStakingManagerContractAddress(
            address(stakingManagerInstance)
        );

        TestBNFTInstance = BNFT(address(stakingManagerInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(stakingManagerInstance.TNFTInstance()));

        managerInstance = new EtherFiNodesManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestBNFTInstance),
            address(TestTNFTInstance)
        );

        protocolRevenueManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );
        protocolRevenueManagerInstance.setAuctionManagerAddress(
            address(auctionInstance)
        );
        stakingManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );
        auctionInstance.setProtocolRevenueManager(
            address(protocolRevenueManagerInstance)
        );

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

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );

        hoax(alice);
        vm.expectRevert("Insufficient staking amount");
        uint256[] memory bidIdArray = new uint256[](1);  
        bidIdArray[0] = 1;

        stakingManagerInstance.batchDepositWithBidIds{value: 0.033 ether}(bidIdArray);

        stakingManagerInstance.switchMode();
        console.logBool(stakingManagerInstance.test());

        hoax(alice);
        vm.expectRevert("Insufficient staking amount");
        stakingManagerInstance.batchDepositWithBidIds{value: 33 ether}(bidIdArray);

        hoax(alice);
        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIdArray);
    }

    function test_StakingManagerContractInstantiatedCorrectly() public {
        assertEq(stakingManagerInstance.stakeAmount(), 0.032 ether);
        assertEq(stakingManagerInstance.owner(), owner);
    }

    function test_GenerateWithdrawalCredentialsCorrectly() public {
        address exampleWithdrawalAddress = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        bytes memory withdrawalCredential = managerInstance
            .generateWithdrawalCredentials(exampleWithdrawalAddress);
        // Generated with './deposit new-mnemonic --eth1_withdrawal_address 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931'
        bytes
            memory trueOne = hex"010000000000000000000000cd5ebc2dd4cb3dc52ac66ceecc72c838b40a5931";
        assertEq(withdrawalCredential.length, trueOne.length);
        assertEq(keccak256(withdrawalCredential), keccak256(trueOne));
    }

    function test_DepositOneWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBidWhitelisted{
            value: 0.1 ether
        }(proof, 1, 0.1 ether);
        
        uint256[] memory bidIdArray = new uint256[](1);  
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIdArray);        
        stakingManagerInstance.registerValidator(bidId[0], test_data);

        uint256 validatorId = bidId[0];
        uint256 winningBid = bidId[0];
        address staker = stakingManagerInstance.bidIdToStaker(validatorId);
        address etherfiNode = managerInstance.getEtherFiNodeAddress(
            validatorId
        );

        assertEq(staker, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(stakingManagerInstance.stakeAmount(), 0.032 ether);
        assertEq(winningBid, bidId[0]);
        assertEq(validatorId, bidId[0]);

        assertEq(
            IEtherFiNode(etherfiNode).ipfsHashForEncryptedValidatorKey(),
            test_data.ipfsHashForEncryptedValidatorKey
        );
        assertEq(
            managerInstance.getEtherFiNodeIpfsHashForEncryptedValidatorKey(
                validatorId
            ),
            test_data.ipfsHashForEncryptedValidatorKey
        );
    }

    function test_BatchDepositWithBidIdsFailsIFInvalidDepositAmount() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 100);

        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );

        uint256[] memory bidIdArray = new uint256[](1);  
        bidIdArray[0] = 1;

        vm.expectRevert("Insufficient staking amount");
        stakingManagerInstance.batchDepositWithBidIds{value: 0.033 ether}(bidIdArray); 
    }

    function test_BatchDepositWithBidIdsFailsIfNotEnoughActiveBids() public {
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 100);

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
        stakingManagerInstance.batchDepositWithBidIds{value: 0.32 ether}(
            bidIdArray
        );
    }

    function test_BatchDepositWithBidIdsFailsIfNoIdsProvided() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 100);
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.1 ether}(
                proof,
                1,
                0.1 ether
            );
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.2 ether}(
                proof,
                1,
                0.2 ether
            );
        }

        assertEq(auctionInstance.numberOfActiveBids(), 20);

        uint256[] memory bidIdArray = new uint256[](0);

        vm.expectRevert("No bid Ids provided");
        stakingManagerInstance.batchDepositWithBidIds{value: 0.32 ether}(
            bidIdArray
        );
    }

    function test_BatchDepositWithBidIdsFailsIfPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 100);

        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.1 ether}(
                proof,
                1,
                0.1 ether
            );
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.2 ether}(
                proof,
                1,
                0.2 ether
            );
        }

        assertEq(auctionInstance.numberOfActiveBids(), 20);

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
        stakingManagerInstance.batchDepositWithBidIds{value: 0.32 ether}(
            bidIdArray
        );
    }

    function test_BatchDepositWithIdsSimpleWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 100);

        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.1 ether}(
                proof,
                1,
                0.1 ether
            );
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.2 ether}(
                proof,
                1,
                0.2 ether
            );
        }

        assertEq(auctionInstance.numberOfActiveBids(), 20);

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

        stakingManagerInstance.batchDepositWithBidIds{value: 0.32 ether}(
            bidIdArray
        );
        assertEq(auctionInstance.numberOfActiveBids(), 10);

        (uint256 amount, , , bool isActive) = auctionInstance.bids(1);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);

        (amount, , , isActive) = auctionInstance.bids(7);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);

        (amount, , , isActive) = auctionInstance.bids(20);
        assertEq(amount, 0.2 ether);
        assertEq(isActive, false);

        (amount, , , isActive) = auctionInstance.bids(3);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, true);

        assertEq(address(stakingManagerInstance).balance, 0.32 ether);
    }

    function test_BatchDepositWithIdsComplexWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 100);

        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.1 ether}(
                proof,
                1,
                0.1 ether
            );
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.2 ether}(
                proof,
                1,
                0.2 ether
            );
        }

        assertEq(auctionInstance.numberOfActiveBids(), 20);
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

        stakingManagerInstance.batchDepositWithBidIds{value: 0.32 ether}(
            bidIdArray
        );
        assertEq(auctionInstance.numberOfActiveBids(), 10);

        (uint256 amount, , , bool isActive) = auctionInstance.bids(1);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);

        (amount, , , isActive) = auctionInstance.bids(7);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);

        (amount, , , isActive) = auctionInstance.bids(20);
        assertEq(amount, 0.2 ether);
        assertEq(isActive, false);

        (amount, , , isActive) = auctionInstance.bids(3);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, true);

        uint256 userBalanceBefore = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;

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

        stakingManagerInstance.batchDepositWithBidIds{value: 0.16 ether}(
            bidIdArray2
        );

        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            userBalanceBefore - 0.064 ether
        );
        assertEq(auctionInstance.numberOfActiveBids(), 8);

        (amount, , , isActive) = auctionInstance.bids(1);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);

        (amount, , , isActive) = auctionInstance.bids(13);
        assertEq(amount, 0.2 ether);
        assertEq(isActive, false);

        (amount, , , isActive) = auctionInstance.bids(3);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);
    }

    function test_EtherFailSafeWorks() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 walletBalance = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );
        
        uint256[] memory bidIdArray = new uint256[](1);  
        bidIdArray[0] = 1;

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIdArray);
        assertEq(address(stakingManagerInstance).balance, 0.032 ether);
        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            walletBalance - 0.132 ether
        );
        vm.stopPrank();

        vm.prank(owner);

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

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBidWhitelisted{
            value: 0.1 ether
        }(proof, 1, 0.1 ether);
        uint256[] memory bidIdArray = new uint256[](1);  
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIdArray);
        
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Not deposit owner");
        stakingManagerInstance.registerValidator(bidId[0], test_data);
    }

    function test_RegisterValidatorFailsIfValidatorDoesNotExist() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );
        uint256[] memory bidIdArray = new uint256[](1);  
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIdArray);
        stakingManagerInstance.cancelDeposit(bidId[0]);

        vm.expectRevert("Deposit does not exist");
        stakingManagerInstance.registerValidator(bidId[0], test_data);
    }

    function test_RegisterValidatorFailsIfContractPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(proof, 1, 0.1 ether);
        uint256[] memory bidIdArray = new uint256[](1);  
        bidIdArray[0] = 1;

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIdArray);
       
        vm.stopPrank();

        vm.prank(owner);
        stakingManagerInstance.pauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Pausable: paused");
        stakingManagerInstance.registerValidator(0, test_data);
    }

    function test_RegisterValidatorWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );
        uint256[] memory bidIdArray = new uint256[](1);  
        bidIdArray[0] = 1;

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIdArray);
        stakingManagerInstance.registerValidator(bidId[0], test_data);

        uint256 selectedBidId = bidId[0];
        address etherFiNode = managerInstance.getEtherFiNodeAddress(bidId[0]);

        assertEq(address(protocolRevenueManagerInstance).balance, 0.1 ether);
        assertEq(selectedBidId, 1);
        assertEq(managerInstance.getNumberOfValidators(), 1);
        assertEq(address(managerInstance).balance, 0 ether);
        assertEq(address(auctionInstance).balance, 0);

        address operatorAddress = auctionInstance.getBidOwner(bidId[0]);
        assertEq(operatorAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);

        address safeAddress = managerInstance.getEtherFiNodeAddress(bidId[0]);
        assertEq(safeAddress, etherFiNode);

        assertEq(
            TestBNFTInstance.ownerOf(bidId[0]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestTNFTInstance.ownerOf(bidId[0]),
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

    function test_BatchRegisterValidatorWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 100);

        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.1 ether}(
                proof,
                1,
                0.1 ether
            );
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.2 ether}(
                proof,
                1,
                0.2 ether
            );
        }

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

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](10);
        depositDataArray[0] = test_data;
        depositDataArray[1] = test_data_2;
        depositDataArray[2] = test_data;
        depositDataArray[3] = test_data_2;
        depositDataArray[4] = test_data;
        depositDataArray[5] = test_data_2;
        depositDataArray[6] = test_data;
        depositDataArray[7] = test_data_2;
        depositDataArray[8] = test_data;
        depositDataArray[9] = test_data_2;

        stakingManagerInstance.batchDepositWithBidIds{value: 0.32 ether}(
            bidIdArray
        );

        assertEq(address(auctionInstance).balance, 3 ether);

        stakingManagerInstance.batchRegisterValidators(
            bidIdArray,
            depositDataArray
        );

        assertEq(address(protocolRevenueManagerInstance).balance, 1.4 ether);
        assertEq(address(auctionInstance).balance, 1.6 ether);

        assertEq(
            TestBNFTInstance.ownerOf(bidIdArray[0]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestBNFTInstance.ownerOf(bidIdArray[4]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestBNFTInstance.ownerOf(bidIdArray[6]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestTNFTInstance.ownerOf(bidIdArray[1]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestTNFTInstance.ownerOf(bidIdArray[2]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestTNFTInstance.ownerOf(bidIdArray[9]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );

        assertEq(managerInstance.getNumberOfValidators(), 10);

        //address safeAddress = managerInstance.getEtherFiNodeAddress(bidIdArray[1]);
        //IEtherFiNode etherFiNode = IEtherFiNode(safeAddress);

        //assertEq(etherFiNode.localRevenueIndex(), 1.1 ether);
    }

    function test_BatchRegisterValidatorFailsIfArrayLengthAreNotEqual() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 100);

        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.1 ether}(
                proof,
                1,
                0.1 ether
            );
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.2 ether}(
                proof,
                1,
                0.2 ether
            );
        }

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

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](9);
        depositDataArray[0] = test_data;
        depositDataArray[1] = test_data_2;
        depositDataArray[2] = test_data;
        depositDataArray[3] = test_data_2;
        depositDataArray[4] = test_data;
        depositDataArray[5] = test_data_2;
        depositDataArray[6] = test_data;
        depositDataArray[7] = test_data_2;
        depositDataArray[8] = test_data;

        stakingManagerInstance.batchDepositWithBidIds{value: 0.32 ether}(
            bidIdArray
        );

        assertEq(address(auctionInstance).balance, 3 ether);

        vm.expectRevert("Array lengths must match");
        stakingManagerInstance.batchRegisterValidators(
            bidIdArray,
            depositDataArray
        );
    }

    function test_BatchRegisterValidatorFailsIfMoreThan16Registers() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 100);

        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.1 ether}(
                proof,
                1,
                0.1 ether
            );
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBidWhitelisted{value: 0.2 ether}(
                proof,
                1,
                0.2 ether
            );
        }

        uint256[] memory bidIdArray = new uint256[](17);
        bidIdArray[0] = 1;
        bidIdArray[1] = 2;
        bidIdArray[2] = 3;
        bidIdArray[3] = 4;
        bidIdArray[4] = 5;
        bidIdArray[5] = 6;
        bidIdArray[6] = 7;
        bidIdArray[7] = 8;
        bidIdArray[8] = 9;
        bidIdArray[9] = 10;
        bidIdArray[10] = 11;
        bidIdArray[11] = 12;
        bidIdArray[12] = 13;
        bidIdArray[13] = 14;
        bidIdArray[14] = 15;
        bidIdArray[15] = 16;
        bidIdArray[16] = 17;

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](17);
        depositDataArray[0] = test_data;
        depositDataArray[1] = test_data_2;
        depositDataArray[2] = test_data;
        depositDataArray[3] = test_data_2;
        depositDataArray[4] = test_data;
        depositDataArray[5] = test_data_2;
        depositDataArray[6] = test_data;
        depositDataArray[7] = test_data_2;
        depositDataArray[8] = test_data;
        depositDataArray[9] = test_data;
        depositDataArray[10] = test_data;
        depositDataArray[11] = test_data;
        depositDataArray[12] = test_data;
        depositDataArray[13] = test_data;
        depositDataArray[14] = test_data;
        depositDataArray[15] = test_data;
        depositDataArray[16] = test_data;

        stakingManagerInstance.batchDepositWithBidIds{value: 0.32 ether}(
            bidIdArray
        );

        assertEq(address(auctionInstance).balance, 3 ether);

        vm.expectRevert("Too many validators");
        stakingManagerInstance.batchRegisterValidators(
            bidIdArray,
            depositDataArray
        );
    }

    function test_cancelDepositFailsIfNotStakeOwner() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBidWhitelisted{
            value: 0.1 ether
        }(proof, 1, 0.1 ether);

        uint256[] memory bidIdArray = new uint256[](1);  
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIdArray);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Not deposit owner");
        stakingManagerInstance.cancelDeposit(bidId[0]);
    }

    function test_cancelDepositFailsIfDepositDoesNotExist() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBidWhitelisted{
            value: 0.1 ether
        }(proof, 1, 0.1 ether);

        uint256[] memory bidIdArray = new uint256[](1);  
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIdArray);
        stakingManagerInstance.cancelDeposit(bidId[0]);

        vm.expectRevert("Deposit does not exist");
        stakingManagerInstance.cancelDeposit(bidId[0]);
    }

    function test_cancelDepositWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId1 = auctionInstance.createBidWhitelisted{
            value: 0.1 ether
        }(proof, 1, 0.1 ether);
        uint256[] memory bidId2 = auctionInstance.createBidWhitelisted{
            value: 0.3 ether
        }(proof, 1, 0.3 ether);
        uint256[] memory bidId3 = auctionInstance.createBidWhitelisted{
            value: 0.2 ether
        }(proof, 1, 0.2 ether);

        assertEq(address(auctionInstance).balance, 0.6 ether);

        uint256[] memory bidIdArray = new uint256[](1);  
        bidIdArray[0] = bidId2[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIdArray);
        uint256 depositorBalance = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;

        uint256 selectedBidId = bidId2[0];
        address staker = stakingManagerInstance.bidIdToStaker(bidId2[0]);
        address etherFiNode = managerInstance.getEtherFiNodeAddress(bidId2[0]);

        assertEq(staker, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(selectedBidId, bidId2[0]);
        assertTrue(
            IEtherFiNode(etherFiNode).phase() ==
                IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED
        );

        (uint256 bidAmount, , address bidder, bool isActive) = auctionInstance
            .bids(selectedBidId);

        assertEq(bidAmount, 0.3 ether);
        assertEq(bidder, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(isActive, false);
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        assertEq(address(auctionInstance).balance, 0.6 ether);

        stakingManagerInstance.cancelDeposit(bidId2[0]);
        assertEq(managerInstance.getEtherFiNodeAddress(bidId2[0]), address(0));
        assertEq(stakingManagerInstance.bidIdToStaker(bidId2[0]), address(0));
        assertTrue(
            IEtherFiNode(etherFiNode).phase() ==
                IEtherFiNode.VALIDATOR_PHASE.CANCELLED
        );

        (bidAmount, , bidder, isActive) = auctionInstance.bids(bidId2[0]);
        assertEq(bidAmount, 0.3 ether);
        assertEq(bidder, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(isActive, true);
        assertEq(auctionInstance.numberOfActiveBids(), 3);
        assertEq(address(auctionInstance).balance, 0.6 ether);

        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            depositorBalance + 0.032 ether
        );
    }

    function test_CorrectValidatorAttatchedToNft() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        bytes32[] memory proof2 = merkle.getProof(whiteListedAddresses, 1);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        vm.prank(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId1 = auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );
        uint256[] memory bidIdArray = new uint256[](1);  
        bidIdArray[0] = bidId1[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIdArray);

        stakingManagerInstance.registerValidator(bidId1[0], test_data);

        vm.stopPrank();
        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        uint256[] memory bidId2 = auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof2,
            1,
            0.1 ether
        );
        uint256[] memory bidIdArray2 = new uint256[](1);  
        bidIdArray2[0] = bidId2[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIdArray2);

        stakingManagerInstance.registerValidator(bidId2[0], test_data);

        assertEq(
            TestBNFTInstance.ownerOf(bidId1[0]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestTNFTInstance.ownerOf(bidId1[0]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestBNFTInstance.ownerOf(bidId2[0]),
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
        assertEq(
            TestTNFTInstance.ownerOf(bidId2[0]),
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
