// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

interface IFactory {
    function getExchange(address _tokenAddress) external returns (address);
}

interface IExchange {
    function ethToTokenSwap(uint256 minToken) external payable;

    function ethToTokenTransfer(uint256 _minTokens, address _recipient)
        external
        payable;
}

contract Exchange is ERC20 {
    using SafeMath for uint256;
    address public tokenAddress;
    address public factoryAddress;

    constructor(address _token) ERC20("UNISWAP", "UNI") {
        require(_token != address(0), "Invalid token address");
        tokenAddress = _token;
        factoryAddress = msg.sender;
    }

    function addLiquidity(uint256 tokenAmount)
        public
        payable
        returns (uint256)
    {
        require(tokenAmount > 0, "Invalid amount");
        if (getReserve() == 0) {
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), tokenAmount);
            // LP tokens are minted at a rate of 1:1 with ETH deposited
            uint256 liquidity = address(this).balance;
            _mint(msg.sender, liquidity); // mint LP tokens
            return liquidity;
        } else {
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = getReserve();
            uint256 _tokenAmount = (msg.value * tokenReserve) / ethReserve;
            require(tokenAmount >= _tokenAmount, "Insufficient token amount");
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _tokenAmount
            );
            uint256 liquidity = (totalSupply() * msg.value) / ethReserve;
            // LP token mint is proportional to the amount of ETH deposited
            _mint(msg.sender, liquidity); // mint LP tokens
        }
    }

    /**
     * @param inputAmount: amount of input token
     * @param inputReserve: amount of input token in the pool
     * @param outputReserve: amount of output token in the pool
     * @return amount of output token 
     
     */
    /*  if ethRes == 1000 and tokenRes == 2000 and inputAmoun is 
     2 eth. then we get 2 * 2000 / (1000 + 2) = 3.999 tokens, P.S this is without fees */
    function getAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) private pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
        uint256 inputWithFees = inputAmount * 99; // 1% fee i.e 100 - 1, if inputAmount is 2 then inputWithFees is 2 * 99 = 198
        uint256 numerator = inputWithFees * outputReserve; // 198 * 2000(tokenReserve) = 396000
        uint256 denominator = (inputReserve * 100) + inputWithFees; // (1000 * 100) + 198 = 119800
        return numerator / denominator; // 396000 / 119800 = 3.299
    }

    function getTokenAmount(uint256 ethAmount) public view returns (uint256) {
        uint256 tokenReserve = getReserve();
        uint256 ethReserve = address(this).balance;
        return getAmount(ethAmount, ethReserve, tokenReserve);
    }

    function getEthAmount(uint256 tokenAmount) public view returns (uint256) {
        uint256 tokenReserve = getReserve();
        uint256 ethReserve = address(this).balance;
        return getAmount(tokenAmount, tokenReserve, ethReserve);
    }

    function ethToToken(uint256 minToken, address recipient) private {
        uint256 tokenReserve = getReserve();
        uint256 ethReserve = address(this).balance - msg.value; // when code reaches here msg.value is already added to address(this).balance
        uint256 amount = getAmount(msg.value, ethReserve, tokenReserve);
        require(amount >= minToken, "Insufficient output amount");
        IERC20(tokenAddress).transfer(recipient, amount);
    }

    function ethToTokenSwap(uint256 minToken) public payable {
        ethToToken(minToken, msg.sender);
    }

    function ethToTokenTransfer(uint256 _minTokens, address _recipient)
        public
        payable
    {
        ethToToken(_minTokens, _recipient);
    }

    function tokenToEthSwap(uint256 tokenSold, uint256 minEth) public {
        uint256 tokenReserve = getReserve();
        uint256 ethReserve = address(this).balance;
        uint256 amount = getAmount(tokenSold, tokenReserve, ethReserve);
        require(amount >= minEth, "Insufficient output amount");
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), tokenSold);
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed.");
    }

    function tokenToTokenSwap(
        uint256 tokenSold,
        uint256 minTokenBought,
        address tokenBought
    ) public {
        address exchangeAddress = IFactory(factoryAddress).getExchange(
            tokenBought
        );
        require(
            exchangeAddress != address(0) && exchangeAddress != address(this),
            "Invalid exchange address"
        );

        uint256 tokenReserve = getReserve();
        uint256 ethReserve = address(this).balance;
        uint256 amount = getAmount(tokenSold, tokenReserve, ethReserve);
        require(amount >= minTokenBought, "Insufficient output amount");
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), tokenSold);
        IExchange(exchangeAddress).ethToTokenTransfer{value: amount}(
            minTokenBought,
            msg.sender
        );
        IERC20(tokenBought).transfer(msg.sender, amount);
    }

    function removeLiquidity(uint256 _amount)
        public
        returns (uint256, uint256)
    {
        require(_amount > 0, "Invalid amount");
        uint256 ethAmount = (address(this).balance * _amount) / totalSupply();
        uint256 tokenAmount = (getReserve() * _amount) / totalSupply();
        _burn(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: ethAmount}("");
        require(success, "Transfer failed.");
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
        return (ethAmount, tokenAmount);
    }

    /********************
     * GETTER FUNTIONS *
     ********************/
    function getReserve() public view returns (uint256) {
        IERC20 token = IERC20(tokenAddress);
        return token.balanceOf(address(this));
    }
}
