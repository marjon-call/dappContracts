// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/MembershipManager.sol";
import "../../src/MembershipNFT.sol";
import "../../src/WeETH.sol";
import "../../src/EETH.sol";
import "../../src/NFTExchange.sol";
import "../../src/LiquidityPool.sol";
import "../../src/helpers/AddressProvider.sol";
import "../../src/RegulationsManager.sol";
import "../../src/UUPSProxy.sol";

contract DeployPhaseOnePointFiveScript is Script {

    /*---- Storage variables ----*/

    UUPSProxy public membershipManagerProxy;
    UUPSProxy public membershipNFTProxy;
    UUPSProxy public eETHProxy;
    UUPSProxy public weETHProxy;
    UUPSProxy public liquidityPoolProxy;
    UUPSProxy public regulationsManagerProxy;
    UUPSProxy public nftExchangeProxy;

    MembershipManager public membershipManagerImplementation;
    MembershipManager public membershipManager;

    MembershipNFT public membershipNFTImplementation;
    MembershipNFT public membershipNFT;

    WeETH public weETHImplementation;
    WeETH public weETH;

    EETH public eETHImplementation;
    EETH public eETH;

    LiquidityPool public liquidityPoolImplementation;
    LiquidityPool public liquidityPool;

    RegulationsManager public regulationsManagerImplementation;
    RegulationsManager public regulationsManager;

    NFTExchange public nftExchangeImplementation;
    NFTExchange public nftExchange;

    AddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        bytes32[] memory emptyProof;
        
        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = AddressProvider(addressProviderAddress);

        address stakingManagerProxyAddress = addressProvider.getContractAddress("StakingManager");
        address etherFiNodesManagerProxyAddress = addressProvider.getContractAddress("EtherFiNodesManager");
        address treasury = addressProvider.getImplementationAddress("Treasury");
        address protocolRevenueManagerProxy = addressProvider.getContractAddress("ProtocolRevenueManager");
        address tnft = addressProvider.getContractAddress("TNFT");
        address admin = vm.envAddress("DEPLOYER");

        bytes32 initialHash = vm.envBytes32("INITIAL_HASH");

        string memory baseURI = vm.envString("BASE_URI");

        // Deploy contracts
        regulationsManagerImplementation = new RegulationsManager();
        regulationsManagerProxy = new UUPSProxy(address(regulationsManagerImplementation),"");
        regulationsManager = RegulationsManager(address(regulationsManagerProxy));
        regulationsManager.initialize();
        addressProvider.addContract(address(regulationsManagerProxy), "RegulationsManager");

        liquidityPoolImplementation = new LiquidityPool();
        liquidityPoolProxy = new UUPSProxy(address(liquidityPoolImplementation),"");
        liquidityPool = LiquidityPool(payable(address(liquidityPoolProxy)));
        liquidityPool.initialize(address(regulationsManager));
        liquidityPool.setTnft(tnft);
        liquidityPool.setStakingManager(stakingManagerProxyAddress);
        liquidityPool.setEtherFiNodesManager(etherFiNodesManagerProxyAddress);
        addressProvider.addContract(address(liquidityPoolProxy), "LiquidityPool");

        eETHImplementation = new EETH();
        eETHProxy = new UUPSProxy(address(eETHImplementation),"");
        eETH = EETH(address(eETHProxy));
        eETH.initialize(address(liquidityPool));
        addressProvider.addContract(address(eETHProxy), "EETH");

        membershipNFTImplementation = new MembershipNFT();
        membershipNFTProxy = new UUPSProxy(address(membershipNFTImplementation),"");
        membershipNFT = MembershipNFT(payable(address(membershipNFTProxy)));
        membershipNFT.initialize(baseURI);
        addressProvider.addContract(address(membershipNFTProxy), "MembershipNFT");

        membershipManagerImplementation = new MembershipManager();
        membershipManagerProxy = new UUPSProxy(address(membershipManagerImplementation),"");
        membershipManager = MembershipManager(payable(address(membershipManagerProxy)));
        membershipManager.initialize(address(eETH), address(liquidityPool), address(membershipNFT), treasury, protocolRevenueManagerProxy);
        addressProvider.addContract(address(membershipManagerProxy), "MembershipManager");

        weETHImplementation = new WeETH();
        weETHProxy = new UUPSProxy(address(weETHImplementation),"");
        weETH = WeETH(address(weETHProxy));
        weETH.initialize(address(liquidityPool), address(eETH));
        addressProvider.addContract(address(weETHProxy), "WeETH");

        nftExchangeImplementation = new NFTExchange();
        nftExchangeProxy = new UUPSProxy(address(nftExchangeImplementation),"");
        nftExchange = NFTExchange(address(nftExchangeProxy));
        nftExchange.initialize(tnft, address(membershipNFT), address(etherFiNodesManagerProxyAddress));
        addressProvider.addContract(address(nftExchangeProxy), "NFTExchange");

        setUpAdmins(admin);

        liquidityPool.setTokenAddress(address(eETH));
        liquidityPool.setMembershipManager(address(membershipManager));
        regulationsManager.initializeNewWhitelist(initialHash);
        regulationsManager.confirmEligibility(initialHash);
        membershipNFT.setMembershipManager(address(membershipManager));
        membershipManager.setTopUpCooltimePeriod(28 days);
        membershipManager.setFeeSplits(0, 100);

        initializeTiers();
        preMint();
        membershipManager.setFeeAmounts(0.05 ether, 0.05 ether, 0);
        membershipManager.pauseContract();
        
        vm.stopBroadcast();
    }

    function setUpAdmins(address _admin) internal {
        liquidityPool.updateAdmin(_admin);
        regulationsManager.updateAdmin(_admin);
        membershipManager.updateAdmin(_admin);
        membershipNFT.updateAdmin(_admin);
        nftExchange.updateAdmin(_admin);
    }

    function initializeTiers() internal {
        membershipManager.addNewTier(0, 1);
        membershipManager.addNewTier(672, 2);
        membershipManager.addNewTier(2016, 3);
        membershipManager.addNewTier(4704, 4);
    }

    function preMint() internal {
        bytes32[] memory emptyProof;
        uint256 minAmount = membershipManager.minimumAmountForMint();
        membershipManager.wrapEthBatch{value: 100 * minAmount}(100, minAmount, 0, emptyProof);
    }
}