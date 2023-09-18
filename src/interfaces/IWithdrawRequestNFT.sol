// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWithdrawRequestNFT {
    struct WithdrawRequest {
        uint96  amountOfEEth;
        uint96  shareOfEEth;
        bool    isValid;
    }

    function initialize() external;
    function requestWithdraw(uint96 amountOfEEth, uint96 shareOfEEth, address requester, uint64 fee) external payable returns (uint256);
    function claimWithdraw(uint256 requestId) external returns (WithdrawRequest memory);

    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory);
    function isFinalized(uint256 requestId) external view returns (bool);
    function ownerOf(uint256 tokenId) external view returns (address);

    function getNextRequestId() external view returns (uint256);

    function invalidateRequest(uint256 requestId) external;
    function finalizeRequests(uint256 upperBound) external;
    function updateAdmin(address _address, bool _isAdmin) external;
    function updateLiqudityPool(address _newLiquidityPool) external;
}
