// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IStakingManager.sol";
import "./IEtherFiNodesManager.sol";

interface IEtherFiNode {
    //The state of the validator
    enum VALIDATOR_PHASE {
        STAKE_DEPOSITED,
        LIVE,
        EXITED,
        CANCELLED
    }

    function setPhase(VALIDATOR_PHASE _phase) external;
    function setIpfsHashForEncryptedValidatorKey(string calldata _ipfs) external;
    function setLocalRevenueIndex(uint256 _localRevenueIndex) external;
    function setExitRequestTimestamp() external;
    function markExited(uint32 _exitTimestamp) external;
    function receiveVestedRewardsForStakers() external payable;
    function updateAfterPartialWithdrawal(bool _vestedAuctionFee) external;

    function phase() external view returns (VALIDATOR_PHASE);
    function ipfsHashForEncryptedValidatorKey() external view returns (string memory);
    function localRevenueIndex() external view returns (uint256);
    function stakingStartTimestamp() external view returns (uint32);
    function exitRequestTimestamp() external view returns (uint32);
    function exitTimestamp() external view returns (uint32);
    function vestedAuctionRewards() external view returns (uint256);

    function getWithdrawableBalance() external view returns (uint256);
    function getNonExitPenaltyAmount(uint256 _principal, uint256 _dailyPenalty, uint32 _endTimestamp) external view returns (uint256);
    function getRewards(bool _stakingRewards, bool _protocolRewards, bool _vestedAuctionFee, 
                        IEtherFiNodesManager.RewardsSplit memory _SRsplits, uint256 _SRscale, 
                        IEtherFiNodesManager.RewardsSplit memory _PRsplits, uint256 _PRscale)
                        external view 
                        returns (uint256, uint256, uint256, uint256);
    function getStakingRewards(IEtherFiNodesManager.RewardsSplit memory _splits, uint256 _scale) external view returns (uint256, uint256, uint256, uint256);
    function getProtocolRewards(IEtherFiNodesManager.RewardsSplit memory _splits, uint256 _scale) external view returns (uint256, uint256, uint256, uint256);
    function getFullWithdrawalPayouts(IEtherFiNodesManager.RewardsSplit memory _splits, uint256 _scale, uint256 _principal, uint256 _dailyPenalty) external view returns (uint256, uint256, uint256, uint256);

    function withdrawFunds(
        address _treasury,
        uint256 _treasuryAmount,
        address _operator,
        uint256 _operatorAmount,
        address _tnftHolder,
        uint256 _tnftAmount,
        address _bnftHolder,
        uint256 _bnftAmount
    ) external;

    function receiveProtocolRevenue(uint256 _globalRevenueIndex) payable external;
}
