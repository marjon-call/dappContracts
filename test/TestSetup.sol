pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/interfaces/IScoreManager.sol";
import "../src/interfaces/IEtherFiNode.sol";
import "src/EtherFiNodesManager.sol";
import "../src/StakingManager.sol";
import "../src/NodeOperatorManager.sol";
import "../src/AuctionManager.sol";
import "../src/ProtocolRevenueManager.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../src/ClaimReceiverPool.sol";
import "../src/LiquidityPool.sol";
import "../src/EETH.sol";
import "../src/ScoreManager.sol";
import "../src/UUPSProxy.sol";
import "./DepositDataGeneration.sol";
import "../lib/murky/src/Merkle.sol";
import "./TestERC20.sol";

contract TestSetup is Test {

    TestERC20 public rETH;
    TestERC20 public wstETH;
    TestERC20 public sfrxEth;
    TestERC20 public cbEth;

    UUPSProxy public auctionManagerProxy;
    UUPSProxy public stakingManagerProxy;
    UUPSProxy public etherFiNodeManagerProxy;
    UUPSProxy public protocolRevenueManagerProxy;
    UUPSProxy public TNFTProxy;
    UUPSProxy public BNFTProxy;
    UUPSProxy public claimReceiverPoolProxy;
    UUPSProxy public liquidityPoolProxy;
    UUPSProxy public eETHProxy;
    UUPSProxy public scoreManagerProxy;

    DepositDataGeneration public depGen;
    IDepositContract public depositContractEth2;

    StakingManager public stakingManagerInstance;
    StakingManager public stakingManagerImplementation;

    AuctionManager public auctionImplementation;
    AuctionManager public auctionInstance;

    ProtocolRevenueManager public protocolRevenueManagerInstance;
    ProtocolRevenueManager public protocolRevenueManagerImplementation;

    EtherFiNodesManager public managerInstance;
    EtherFiNodesManager public managerImplementation;

    ScoreManager public scoreManagerInstance;
    ScoreManager public scoreManagerImplementation;

    TNFT public TNFTImplementation;
    TNFT public TNFTInstance;

    BNFT public BNFTImplementation;
    BNFT public BNFTInstance;

    LiquidityPool public liquidityPoolImplementation;
    LiquidityPool public liquidityPoolInstance;
    
    EETH public eETHImplementation;
    EETH public eETHInstance;
    
    ClaimReceiverPool public claimReceiverPoolImplementation;
    ClaimReceiverPool public claimReceiverPoolInstance;

    EtherFiNode public node;
    Treasury public treasuryInstance;
    NodeOperatorManager public nodeOperatorManagerInstance;
    
    Merkle merkle;
    Merkle merkleMigration;
    bytes32 root;
    bytes32 rootMigration;
    bytes32[] public whiteListedAddresses;
    bytes32[] public dataForVerification;
    IStakingManager.DepositData public test_data;
    IStakingManager.DepositData public test_data_2;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);
    address chad = vm.addr(4);
    address dan = vm.addr(5);
    address egg = vm.addr(6);
    address greg = vm.addr(7);
    address henry = vm.addr(8);
    address liquidityPool = vm.addr(9);

    bytes aliceIPFSHash = "AliceIPFS";
    bytes _ipfsHash = "ipfsHash";

    function setUpTests() public {
        vm.startPrank(owner);

        // Deploy Contracts and Proxies
        treasuryInstance = new Treasury();
        nodeOperatorManagerInstance = new NodeOperatorManager();

        auctionImplementation = new AuctionManager();
        auctionManagerProxy = new UUPSProxy(address(auctionImplementation), "");
        auctionInstance = AuctionManager(address(auctionManagerProxy));
        auctionInstance.initialize(address(nodeOperatorManagerInstance));

        stakingManagerImplementation = new StakingManager();
        stakingManagerProxy = new UUPSProxy(address(stakingManagerImplementation), "");
        stakingManagerInstance = StakingManager(address(stakingManagerProxy));
        stakingManagerInstance.initialize(address(auctionInstance));

        TNFTImplementation = new TNFT();
        TNFTProxy = new UUPSProxy(address(TNFTImplementation), "");
        TNFTInstance = TNFT(address(TNFTProxy));
        TNFTInstance.initialize(address(stakingManagerInstance));

        BNFTImplementation = new BNFT();
        BNFTProxy = new UUPSProxy(address(BNFTImplementation), "");
        BNFTInstance = BNFT(address(BNFTProxy));
        BNFTInstance.initialize(address(stakingManagerInstance));

        protocolRevenueManagerImplementation = new ProtocolRevenueManager();
        protocolRevenueManagerProxy = new UUPSProxy(address(protocolRevenueManagerImplementation), "");
        protocolRevenueManagerInstance = ProtocolRevenueManager(payable(address(protocolRevenueManagerProxy)));
        protocolRevenueManagerInstance.initialize();

        managerImplementation = new EtherFiNodesManager();
        etherFiNodeManagerProxy = new UUPSProxy(address(managerImplementation), "");
        managerInstance = EtherFiNodesManager(payable(address(etherFiNodeManagerProxy)));
        managerInstance.initialize(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TNFTInstance),
            address(BNFTInstance),
            address(protocolRevenueManagerInstance)
        );

        scoreManagerImplementation = new ScoreManager();
        scoreManagerProxy = new UUPSProxy(address(scoreManagerImplementation), "");
        scoreManagerInstance = ScoreManager(address(scoreManagerProxy));
        scoreManagerInstance.initialize();

        node = new EtherFiNode();

        rETH = new TestERC20("Rocket Pool ETH", "rETH");
        rETH.mint(alice, 10e18);
        rETH.mint(bob, 10e18);
        cbEth = new TestERC20("Staked ETH", "wstETH");
        cbEth.mint(alice, 10e18);
        cbEth.mint(bob, 10e18);
        wstETH = new TestERC20("Coinbase ETH", "cbEth");
        wstETH.mint(alice, 10e18);
        wstETH.mint(bob, 10e18);
        sfrxEth = new TestERC20("Frax ETH", "sfrxEth");
        sfrxEth.mint(alice, 10e18);
        sfrxEth.mint(bob, 10e18);
        
        claimReceiverPoolImplementation = new ClaimReceiverPool();
        claimReceiverPoolProxy = new UUPSProxy(
            address(claimReceiverPoolImplementation),
            ""
        );
        claimReceiverPoolInstance = ClaimReceiverPool(
            payable(address(claimReceiverPoolProxy))
        );
        claimReceiverPoolInstance.initialize(
            address(rETH),
            address(wstETH),
            address(sfrxEth),
            address(cbEth),
            address(scoreManagerInstance)
        );

        liquidityPoolImplementation = new LiquidityPool();
        liquidityPoolProxy = new UUPSProxy(
            address(liquidityPoolImplementation),
            ""
        );
        liquidityPoolInstance = LiquidityPool(
            payable(address(liquidityPoolProxy))
        );
        liquidityPoolInstance.initialize();

        eETHImplementation = new EETH();
        eETHProxy = new UUPSProxy(address(eETHImplementation), "");
        eETHInstance = EETH(address(eETHProxy));
        eETHInstance.initialize(payable(address(liquidityPoolInstance)));

        // Setup dependencies
        _merkleSetup();
        _merkleSetupMigration();
        nodeOperatorManagerInstance.setAuctionContractAddress(address(auctionInstance));
        nodeOperatorManagerInstance.updateMerkleRoot(root);
        auctionInstance.setStakingManagerContractAddress(address(stakingManagerInstance));
        auctionInstance.setProtocolRevenueManager(address(protocolRevenueManagerInstance));
        protocolRevenueManagerInstance.setAuctionManagerAddress(address(auctionInstance));
        protocolRevenueManagerInstance.setEtherFiNodesManagerAddress(address(managerInstance));
        stakingManagerInstance.setEtherFiNodesManagerAddress(address(managerInstance));
        stakingManagerInstance.registerEtherFiNodeImplementationContract(address(node));
        stakingManagerInstance.registerTNFTContract(address(TNFTInstance));
        stakingManagerInstance.registerBNFTContract(address(BNFTInstance));
        claimReceiverPoolInstance.setLiquidityPool(address(liquidityPoolInstance));
        liquidityPoolInstance.setTokenAddress(address(eETHInstance));
        liquidityPoolInstance.setScoreManager(address(scoreManagerInstance));
        scoreManagerInstance.setCallerStatus(address(claimReceiverPoolInstance), true);
        scoreManagerInstance.addNewScoreType("Early Adopter Pool");

        depGen = new DepositDataGeneration();

        bytes32 deposit_data_root1 = 0x9120ef13437690c401c436a3e454aa08c438eb5908279b0a49dee167fde30399;
        bytes memory pub_key1 = hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c";
        bytes memory signature1 = hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df";
        depositContractEth2 = IDepositContract(0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b);

        vm.stopPrank();
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

        whiteListedAddresses.push(keccak256(abi.encodePacked(alice)));

        whiteListedAddresses.push(keccak256(abi.encodePacked(bob)));

        whiteListedAddresses.push(keccak256(abi.encodePacked(chad)));

        root = merkle.getRoot(whiteListedAddresses);
    }

    function _merkleSetupMigration() internal {
        merkleMigration = new Merkle();
        dataForVerification.push(
            keccak256(
                abi.encodePacked(
                    alice,
                    uint256(0),
                    uint256(10),
                    uint256(0),
                    uint256(0),
                    uint256(0),
                    uint256(400)
                )
            )
        );
        dataForVerification.push(
            keccak256(
                abi.encodePacked(
                    0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
                    uint256(0.2 ether),
                    uint256(0),
                    uint256(0),
                    uint256(0),
                    uint256(0),
                    uint256(652)
                )
            )
        );
        dataForVerification.push(
            keccak256(
                abi.encodePacked(
                    chad,
                    uint256(0),
                    uint256(10),
                    uint256(0),
                    uint256(50),
                    uint256(0),
                    uint256(9464)
                )
            )
        );
        dataForVerification.push(
            keccak256(
                abi.encodePacked(
                    bob,
                    uint256(0.1 ether),
                    uint256(0),
                    uint256(0),
                    uint256(0),
                    uint256(0),
                    uint256(400)
                )
            )
        );
        dataForVerification.push(
            keccak256(
                abi.encodePacked(
                    dan,
                    uint256(0.1 ether),
                    uint256(0),
                    uint256(0),
                    uint256(0),
                    uint256(0),
                    uint256(800)
                )
            )
        );
        rootMigration = merkleMigration.getRoot(dataForVerification);
        claimReceiverPoolInstance.updateMerkleRoot(rootMigration);
    }

    function _getDepositRoot() internal returns (bytes32) {
        bytes32 onchainDepositRoot = depositContractEth2.get_deposit_root();
        return onchainDepositRoot;
    }
}