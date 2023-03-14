// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IProtocolRevenueManager {
    function addAuctionRevenue(uint256 _validatorId, uint256 _amount) external payable;
    function distributeAuctionRevenue(uint256 _validatorId) external returns (uint256);

    function setEtherFiNodesManagerAddress(address _etherFiNodesManager) external;

    function getAccruedAuctionRevenueRewards(uint256 _validatorId) external returns (uint256);  
    function getGlobalRevenueIndex() external returns (uint256);
}