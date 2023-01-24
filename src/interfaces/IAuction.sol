// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAuction {
    struct Bid {
        uint256 amount;
        uint256 timeOfBid;
        address bidderAddress;
        bool isActive;
    }

    function bidOnStake(bytes32[] calldata _merkleProof) external payable;

    function calculateWinningBid() external returns (address);

    function cancelBid(uint256 _bidId) external;

    function increaseBid(uint256 _bidId) external payable;

    function decreaseBid(uint256 _bidId, uint256 _amount) external;

    function getNumberOfActivebids() external view returns (uint256);

    function setDepositContractAddress(address _depositContractAddress)
        external;
}
