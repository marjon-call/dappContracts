// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ILiquidityPool {

    function deposit(address _user) external payable;

    function getTotalPooledEther() external view returns (uint256);
    function getTotalEtherClaimOf(address _user) external view returns (uint256);
    function sharesForAmount(uint256 _amount) external view returns (uint256);
    function amountForShare(uint256 _share) external view returns (uint256);

    function setScoreManager(address _address) external;
}
