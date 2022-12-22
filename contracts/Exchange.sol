// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract Exchange {
    using SafeMath for uint;
    address public tokenAddress;

    constructor(address _token) {
        require(_token != address(0), "Invalid token address");
        tokenAddress = _token;
    }

    function addLiquidity(uint tokenAmount) public payable {
        require(tokenAmount > 0, "Invalid amount");
        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, address(this), tokenAmount);
    }

    function getAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) private pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

        return (inputAmount * outputReserve) / (inputReserve + inputAmount);
    }

    function getTokenAmount(uint ethAmount) public view returns (uint) {
        uint tokenReserve = getReserve();
        uint ethReserve = address(this).balance;
        return getAmount(ethAmount, ethReserve, tokenReserve);
    }

    function getEthAmount(uint tokenAmount) public view returns (uint) {
        uint tokenReserve = getReserve();
        uint ethReserve = address(this).balance;
        return getAmount(tokenAmount, tokenReserve, ethReserve);
    }

    function ethToTokenSwap(uint minToken) public payable {
        uint tokenReserve = getReserve();
        uint ethReserve = address(this).balance - msg.value; // when code reaches here msg.value is already added to address(this).balance
        uint amount = getAmount(msg.value, ethReserve, tokenReserve);
        require(amount >= minToken, "Insufficient output amount");
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }

    function tokenToEthSwap(uint tokenSold, uint minEth) public {
        uint tokenReserve = getReserve();
        uint ethReserve = address(this).balance;
        uint amount = getAmount(tokenSold, tokenReserve, ethReserve);
        require(amount >= minEth, "Insufficient output amount");
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), tokenSold);
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed.");
    }

    /********************
     * GETTER FUNTIONS *
     ********************/
    function getReserve() public view returns (uint) {
        IERC20 token = IERC20(tokenAddress);
        return token.balanceOf(address(this));
    }
}
