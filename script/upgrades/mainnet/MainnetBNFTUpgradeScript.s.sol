// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/BNFT.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract BNFTUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address BNFTProxy;
        address BNFTImplementation;
    }

    CriticalAddresses criticalAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address BNFTProxyAddress = vm.envAddress("BNFT_PROXY_ADDRESS");

        // mainnet
        require(BNFTProxyAddress == 0x6599861e55abd28b91dd9d86A826eC0cC8D72c2c, "BNFTProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        BNFT BNFTInstance = BNFT(BNFTProxyAddress);
        BNFT BNFTV2Implementation = new BNFT();

        BNFTInstance.upgradeTo(address(BNFTV2Implementation));
        BNFT BNFTV2Instance = BNFT(BNFTProxyAddress);

        vm.stopBroadcast();

        criticalAddresses = CriticalAddresses({
            BNFTProxy: BNFTProxyAddress,
            BNFTImplementation: address(BNFTV2Implementation)
        });

    }

    function _stringToUint(
        string memory numString
    ) internal pure returns (uint256) {
        uint256 val = 0;
        bytes memory stringBytes = bytes(numString);
        for (uint256 i = 0; i < stringBytes.length; i++) {
            uint256 exp = stringBytes.length - i;
            bytes1 ival = stringBytes[i];
            uint8 uval = uint8(ival);
            uint256 jval = uval - uint256(0x30);

            val += (uint256(jval) * (10 ** (exp - 1)));
        }
        return val;
    }

    function writeUpgradeVersionFile() internal {
        // Read Local Current version
        string memory localVersionString = vm.readLine("release/logs/Upgrades/mainnet/BNFT/version.txt");
        // Read Global Current version
        string memory globalVersionString = vm.readLine("release/logs/Upgrades/mainnet/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);
        uint256 globalVersion = _stringToUint(globalVersionString);

        localVersion++;
        globalVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/mainnet/BNFT/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );
        vm.writeFile(
            "release/logs/Upgrades/mainnet/version.txt",
            string(abi.encodePacked(Strings.toString(globalVersion)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/mainnet/BNFT/",
                    Strings.toString(localVersion),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(localVersion),
                    "\nProxy Address: ",
                    Strings.toHexString(criticalAddresses.BNFTProxy),
                    "\nNew Implementation Address: ",
                    Strings.toHexString(criticalAddresses.BNFTImplementation),
                    "\nOptional Comments: ", 
                    "Comment Here"
                )
            )
        );
    }
}