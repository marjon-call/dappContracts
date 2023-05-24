// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/NodeOperatorManager.sol";
import "../../src/AuctionManager.sol";
import "../../src/UUPSProxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployNodeOperatorManagerScript is Script {
    using Strings for string;
        
    address auctionManagerProxyAddress = vm.envAddress("AUCTION_MANAGER_PROXY_ADDRESS");

    UUPSProxy public nodeOperatorManagerProxy;

    NodeOperatorManager public nodeOperatorManagerImplementation;
    NodeOperatorManager public nodeOperatorManagerInstance;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        nodeOperatorManagerImplementation = new NodeOperatorManager();
        nodeOperatorManagerProxy = new UUPSProxy(address(nodeOperatorManagerImplementation), "");
        nodeOperatorManagerInstance = NodeOperatorManager(address(nodeOperatorManagerProxy));
        nodeOperatorManagerInstance.initialize();

        AuctionManager auctionManagerInstance = AuctionManager(auctionManagerProxyAddress);
        AuctionManagerV2 auctionManagerV2Implementation = new AuctionManagerV2();

        auctionManagerInstance.upgradeTo(address(auctionManagerV2Implementation));
        AuctionManagerV2 auctionManagerV2Instance = AuctionManagerV2(auctionManagerProxyAddress);

        auctionManagerV2Instance.updateNodeOperatorManager(address(nodeOperatorManagerInstance));    
            
        vm.stopBroadcast();
    }
}
