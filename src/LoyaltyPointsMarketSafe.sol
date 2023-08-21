// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LoyaltyPointsMarketSafe is Ownable {

    event PointsPurchased(address indexed buyer, uint256 indexed tokenId, uint256 amountWei, uint256 weiPerPoint);

    uint256 public weiPerPoint;

    constructor(uint256 _weiPerPoint) {
        weiPerPoint = _weiPerPoint;
    }

    function purchasePoints(uint256 tokenId) external payable {
        emit PointsPurchased(msg.sender, tokenId, msg.value, weiPerPoint);
    }

    //-----------------------------------------------------------------------------
    //-------------------------------  Admin  -------------------------------------
    //-----------------------------------------------------------------------------

    function withdrawFunds(address payable _to) external onlyOwner {
        _to.transfer(address(this).balance);
    }

    function setWeiPerPoint(uint256 _weiPerPoint) external onlyOwner {
        weiPerPoint = _weiPerPoint;
    }
}