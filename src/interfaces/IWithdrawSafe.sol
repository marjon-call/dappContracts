// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWithdrawSafe {

    struct AuctionContractRevenueSplit {
        uint256 treasurySplit;
        uint256 nodeOperatorSplit;
        uint256 tnftHolderSplit;
        uint256 bnftHolderSplit;
    }

    struct ValidatorExitRevenueSplit {
        uint256 treasurySplit;
        uint256 nodeOperatorSplit;
        uint256 tnftHolderSplit;
        uint256 bnftHolderSplit;
    }

    function setUpNewStake(
        address _nodeOperator, 
        address _tnftHolder, 
        address _bnftHolder) external;
    
}
