// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IDeposit {

    //The phases of the staking process
    enum STAKE_PHASE {
        STEP_1,
        STEP_2,
        STEP_3,
        INACTIVE
    }

    /// @notice Structure to hold the information on new Stakes
    /// @param staker - the address of the user who staked
    /// @param withdrawCredentials - withdraw credentials of the validator
    /// @param amount - amount of the stake
    /// @param phase - the current step of the stake
    struct Stake {
        address staker;
        bytes32 withdrawCredentials;
        uint256 amount;
        uint256 winningBid;
        uint256 stakeId;
        STAKE_PHASE phase;
    }

    /// @notice Structure to hold the information on validators
    /// @param publicKey - BLS public key of the validator, generated by the operator.
    /// @param signature - BLS signature of the validator, generated by the operator.
    /// @param depositDataRoot -  hash tree root of the deposit data, generated by the operator.
    /// @param StakeId - the stake ID which corresponds to the validator
    struct Validator {
        bytes publicKey;
        bytes signature;
        bytes32 depositDataRoot;
        uint256 StakeId;
    }

    function deposit() external payable;

    function cancelStake(uint256 _stakeId) external;

}
