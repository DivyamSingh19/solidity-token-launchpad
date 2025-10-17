 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Token.sol";

contract Launchpad {
    Token public token;
    address public owner;
    uint256 public tokenPrice; 

    constructor(address _tokenAddress, uint256 _tokenPrice) {
        token = Token(_tokenAddress);
        owner = msg.sender;
        tokenPrice = _tokenPrice;
    }

    function buyTokens() external payable {
        require(msg.value > 0, "Send ETH to buy tokens");

        uint256 amountToBuy = (msg.value * 10 ** token.decimals()) / tokenPrice;
        uint256 launchpadBalance = token.balanceOf(address(this));
        require(amountToBuy <= launchpadBalance, "Not enough tokens in Launchpad");

        token.transfer(msg.sender, amountToBuy);
    }

    function withdrawETH() external {
        require(msg.sender == owner, "Only owner");
        payable(owner).transfer(address(this).balance);
    }

    function withdrawUnsoldTokens() external {
        require(msg.sender == owner, "Only owner");
        token.transfer(owner, token.balanceOf(address(this)));
    }
}
