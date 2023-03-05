// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Treasury.sol";
import "../src/NodeOperatorKeyManager.sol";
import "../src/EtherFiNodesManager.sol";
import "../src/StakingManager.sol";
import "../src/AuctionManager.sol";
import "../lib/murky/src/Merkle.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployScript is Script {
    using Strings for string;

    struct addresses {
        address treasury;
        address nodeOperatorKeyManager;
        address auction;
        address stakingManager;
        address TNFT;
        address BNFT;
        address nodesManager;
    }

    addresses addressStruct;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Treasury treasury = new Treasury();
        NodeOperatorKeyManager nodeOperatorKeyManager = new NodeOperatorKeyManager();
        AuctionManager auction = new AuctionManager(address(nodeOperatorKeyManager));

        treasury.setAuctionManagerContractAddress(address(auction));

        vm.recordLogs();

        StakingManager stakingManager = new StakingManager(address(auction));
        auction.setStakingManagerContractAddress(address(stakingManager));

        Vm.Log[] memory entries = vm.getRecordedLogs();

        (address TNFTAddress, address BNFTAddress) = abi.decode(
            entries[0].data,
            (address, address)
        );

        EtherFiNodesManager nodesManager = new EtherFiNodesManager(
            address(treasury),
            address(auction),
            address(stakingManager),
            TNFTAddress,
            BNFTAddress
        );

        auction.setManagerAddress(address(nodesManager));
        stakingManager.setManagerAddress(address(nodesManager));

        vm.stopBroadcast();

        addressStruct = addresses({
            treasury: address(treasury),
            nodeOperatorKeyManager: address(nodeOperatorKeyManager),
            auction: address(auction),
            stakingManager: address(stakingManager),
            TNFT: TNFTAddress,
            BNFT: BNFTAddress,
            nodesManager: address(nodesManager)
        });

        writeVersionFile();

        // Set path to version file where current verion is recorded
        /// @dev Initial version.txt and X.release files should be created manually
    }

    function _stringToUint(string memory numString)
        internal
        pure
        returns (uint256)
    {
        uint256 val = 0;
        bytes memory stringBytes = bytes(numString);
        for (uint256 i = 0; i < stringBytes.length; i++) {
            uint256 exp = stringBytes.length - i;
            bytes1 ival = stringBytes[i];
            uint8 uval = uint8(ival);
            uint256 jval = uval - uint256(0x30);

            val += (uint256(jval) * (10**(exp - 1)));
        }
        return val;
    }

    function writeVersionFile() internal {
        // Read Current version
        string memory versionString = vm.readLine("release/logs/version.txt");

        // Cast string to uint256
        uint256 version = _stringToUint(versionString);

        version++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/version.txt",
            string(abi.encodePacked(Strings.toString(version)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/",
                    Strings.toString(version),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(version),
                    "\nTreasury: ",
                    Strings.toHexString(addressStruct.treasury),
                    "\nNode Operator Key Manager: ",
                    Strings.toHexString(addressStruct.nodeOperatorKeyManager),
                    "\nAuctionManager: ",
                    Strings.toHexString(addressStruct.auction),
                    "\nStakingManager: ",
                    Strings.toHexString(addressStruct.stakingManager),
                    "\nTNFT: ",
                    Strings.toHexString(addressStruct.TNFT),
                    "\nBNFT: ",
                    Strings.toHexString(addressStruct.BNFT),
                    "\nSafe Manager: ",
                    Strings.toHexString(addressStruct.nodesManager)
                )
            )
        );
    }
}
