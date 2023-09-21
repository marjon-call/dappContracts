// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IEtherFiNode.sol";
import "@eigenlayer/contracts/interfaces/IEigenPodManager.sol";
import "@eigenlayer/contracts/interfaces/IDelayedWithdrawalRouter.sol";

interface IEtherFiNodesManager {
    enum ValidatorRecipientType {
        TNFTHOLDER,
        BNFTHOLDER,
        TREASURY,
        OPERATOR
    }

    struct RewardsSplit {
        uint64 treasury;
        uint64 nodeOperator;
        uint64 tnft;
        uint64 bnft;
    }

    function etherfiNodeAddressForBidID(uint256 _bidId) external returns (address);

    // VIEW functions
    function numberOfValidators() external view returns (uint64);
    function nonExitPenaltyPrincipal() external view returns (uint64);
    function nonExitPenaltyDailyRate() external view returns (uint64);

    function eigenPodManager() external view returns (IEigenPodManager);
    function delayedWithdrawalRouter() external view returns (IDelayedWithdrawalRouter);

    function phase(
        uint256 _validatorId
    ) external view returns (IEtherFiNode.VALIDATOR_PHASE phase);

    function ipfsHashForEncryptedValidatorKey(
        uint256 _validatorId
    ) external view returns (string memory);

    function generateWithdrawalCredentials(
        address _address
    ) external view returns (bytes memory);

    function getWithdrawalCredentials(
        uint256 _validatorId
    ) external view returns (bytes memory);

    function calculateTVL(
        uint256 _validatorId,
        uint256 _beaconBalance
    ) external view returns (uint256, uint256, uint256, uint256);

    function isExitRequested(uint256 _validatorId) external view returns (bool);

    function isExited(uint256 _validatorId) external view returns (bool);
    function isFullyWithdrawn(uint256 _validatorId) external view returns (bool);
    function isEvicted(uint256 _validatorId) external view returns (bool);

    function getNonExitPenalty(
        uint256 _validatorId
    ) external view returns (uint256);

    function getRewardsPayouts(
        uint256 _validatorId,
        uint256 _beaconBalance
    ) external view returns (uint256, uint256, uint256, uint256);

    function getFullWithdrawalPayouts(
        uint256 _validatorId
    ) external view returns (uint256, uint256, uint256, uint256);

    // Non-VIEW functions
    function initialize(
        address _treasuryContract,
        address _auctionContract,
        address _stakingManagerContract,
        address _tnftContract,
        address _bnftContract,
        address _protocolRevenueManagerContract
    ) external;

    function incrementNumberOfValidators(uint64 _count) external;

    function registerEtherFiNode(uint256 _validatorId) external returns (address);

    function unregisterEtherFiNode(uint256 _validatorId) external;

    function setStakingRewardsSplit(
        uint64 _treasury,
        uint64 _nodeOperator,
        uint64 _tnft,
        uint64 _bnft
    ) external;

    function setProtocolRewardsSplit(
        uint64 _treasury,
        uint64 _nodeOperator,
        uint64 _tnft,
        uint64 _bnft
    ) external;

    function setNonExitPenaltyPrincipal(
        uint64 _nonExitPenaltyPrincipal
    ) external;

    function setNonExitPenaltyDailyRate(
        uint64 _nonExitPenaltyDailyRate
    ) external;

    function setEtherFiNodePhase(
        uint256 _validatorId,
        IEtherFiNode.VALIDATOR_PHASE _phase
    ) external;

    function setEtherFiNodeIpfsHashForEncryptedValidatorKey(
        uint256 _validatorId,
        string calldata _ipfs
    ) external;

    function sendExitRequest(uint256 _validatorId) external;
    function batchSendExitRequest(uint256[] calldata _validatorIds) external;

    function processNodeExit(
        uint256[] calldata _validatorIds,
        uint32[] calldata _exitTimestamp
    ) external;

    function markBeingSlashed(uint256[] calldata _validatorIds) external;

    function partialWithdraw(uint256 _validatorId) external;

    function partialWithdrawBatch(uint256[] calldata _validatorIds) external;

    function partialWithdrawBatchGroupByOperator(
        address _operator,
        uint256[] memory _validatorIds
    ) external;

    function fullWithdraw(uint256 _validatorId) external;

    function fullWithdrawBatch(uint256[] calldata _validatorIds) external;

    function updateAdmin(address _address, bool _isAdmin) external;

    function getUnusedWithdrawalSafesLength() external view returns (uint256);
}
