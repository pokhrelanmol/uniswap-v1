import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { assert, expect } from "chai";
import { ethers } from "hardhat";
import { Exchange, Token } from "../typechain-types";
const toWei = ethers.utils.parseEther;
const getBalance = ethers.provider.getBalance;
const fromWei = ethers.utils.formatEther;
describe("Exchange Contract", () => {
    let exchange: Exchange;
    let token: Token;
    let signers: SignerWithAddress[];
    beforeEach(async () => {
        const Token = await ethers.getContractFactory("Token");
        token = await Token.deploy("TOKEN", "TKN", toWei("1000000"));
        await token.deployed();
        const Exchange = await ethers.getContractFactory("Exchange");
        exchange = await Exchange.deploy(token.address);
        await exchange.deployed();
    });
    describe("Contructor", () => {
        it("Should set correct token address", async () => {
            const tokenAddress = await exchange.tokenAddress();
            assert.equal(tokenAddress, token.address);
        });
    });
    describe("Add Liquidity", async () => {
        it("Should add liquidity to the exchange", async () => {
            const amount = toWei("100");
            await token.approve(exchange.address, amount);
            await exchange.addLiquidity(amount, {
                value: toWei("1"),
            });
            const liquidity = await exchange.getReserve();
            const etherBalance = await getBalance(exchange.address);
            expect(etherBalance.toString()).to.eq(toWei("1").toString());
            assert.equal(liquidity.toString(), amount.toString());
        });
    });
    describe("Get Token Amount", () => {
        it("Should return correct token amount", async () => {
            const amount = toWei("2000");
            await token.approve(exchange.address, amount);
            await exchange.addLiquidity(amount, {
                value: toWei("1000"),
            });
            let tokenOut = await exchange.getTokenAmount(toWei("1"));
            assert.equal(fromWei(tokenOut.toString()), "1.998001998001998001");

            tokenOut = await exchange.getTokenAmount(toWei("100"));
            expect(fromWei(tokenOut)).to.equal("181.818181818181818181");

            tokenOut = await exchange.getTokenAmount(toWei("1000"));
            expect(fromWei(tokenOut)).to.equal("1000.0");
        });
    });
    describe("Get Ether Amount", () => {
        it("Should return correct ether amount", async () => {
            const amount = toWei("2000");
            await token.approve(exchange.address, amount);
            await exchange.addLiquidity(amount, {
                value: toWei("1000"),
            });
            let ethOut = await exchange.getEthAmount(toWei("2"));
            assert.equal(fromWei(ethOut.toString()), "0.999000999000999");

            ethOut = await exchange.getEthAmount(toWei("100"));
            expect(fromWei(ethOut)).to.equal("47.619047619047619047");

            ethOut = await exchange.getEthAmount(toWei("2000"));
            expect(fromWei(ethOut)).to.equal("500.0");
        });
    });
});
