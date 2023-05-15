// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ImeETH {
    function totalShares() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address _account) external view returns (uint256);
    function pointsOf(address _account) external view returns (uint40);
    function tierOf(address _user) external view returns (uint8);
    function calculatePointsPerDepositAmount(uint40 _points, uint256 _amount) external view returns (uint40);
    function getPointsEarningsDuringLastMembershipPeriod(address _account) external view returns (uint40);
    function pointsSnapshotTimeOf(address _account) external view returns (uint32);
    function claimableTier(address _account) external view returns (uint8);
    function tierForPointsPerDepositAmount(uint40 _points) external view returns (uint8);
    function recentTierSnapshotTimestamp() external view returns (uint256);
    function allowance(address _owner, address _spender) external view returns (uint256);

    function wrapEEth(uint256 _amount) external;
    function wrapEth(address _account, bytes32[] calldata _merkleProof) external payable;
    function wrapEthForEap(address _account, uint40 _points, bytes32[] calldata _merkleProof) external payable;
    function unwrapForEEth(uint256 _amount) external;
    function unwrapForEth(uint256 _amount) external;
    function stakeForPoints(uint256 _amount) external;
    function unstakeForPoints(uint256 _amount) external;

    function updateTier(address _account) external;
    function updatePoints(address _account) external;
    function updatePointsBoostFactor(uint16 _newPointsBoostFactor) external;
    function claimStakingRewards(address _account) external;
    
    function addNewTier(uint40 _minimumPointsRequirement, uint24 _weight) external returns (uint256);
}
