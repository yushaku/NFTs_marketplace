import {
  loadFixture,
  setBalance,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { toWei } from "./helper";
import { Exchange } from "../typechain";

describe("Uniswap v1", function () {
  async function getBalance(address: string) {
    return await ethers.provider.getBalance(address);
  }

  const fromWei = (value: string | bigint) => {
    return ethers.formatEther(
      typeof value === "string" ? value : value.toString(),
    );
  };

  async function deployTokenFixture() {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy("Token", "TKN", toWei(1000000));
    const tokenAddress = await token.getAddress();

    const Exchange = await ethers.getContractFactory("Exchange");
    const exchange = await Exchange.deploy(tokenAddress);
    const exchangeAddress = await exchange.getAddress();

    return {
      token,
      tokenAddress,
      exchangeAddress,
      exchange,
      owner,
      addr1,
      addr2,
    };
  }

  describe("Deployment", function () {
    it("Should deploy new token and exchange", async function () {
      const { token, tokenAddress, exchange, exchangeAddress } =
        await loadFixture(deployTokenFixture);

      // token
      expect(await token.name()).to.equal("Token");
      expect(await token.symbol()).to.equal("TKN");
      expect(await token.decimals()).to.equal(18);
      expect(await token.totalSupply()).to.equal(toWei(1000000));

      // exchange
      expect(await exchange.tokenAddress()).to.equal(tokenAddress);
    });
  });

  describe("addLiquidity", async () => {
    it("adds liquidity", async () => {
      const { token, exchange, exchangeAddress } =
        await loadFixture(deployTokenFixture);

      await token.approve(exchangeAddress, toWei(200));
      // send 200 token + 100 ETH to the exchange
      await exchange.addLiquidity(toWei(200), { value: toWei(100) });

      expect(await getBalance(exchangeAddress)).to.equal(toWei(100));
      expect(await exchange.getReserve()).to.equal(toWei(200));
    });
  });

  describe("getTokenAmount", async () => {
    let exchange: Exchange;

    beforeEach(async () => {
      const {
        token,
        exchange: _exchange,
        exchangeAddress,
      } = await loadFixture(deployTokenFixture);

      await token.approve(exchangeAddress, toWei(200));
      await _exchange.addLiquidity(toWei(200), { value: toWei(100) });

      exchange = _exchange;
    });

    it("returns correct token amount", async () => {
      let tokensOut = await exchange.getTokenAmount(toWei(1));
      expect(fromWei(tokensOut)).to.equal("1.998001998001998001");

      tokensOut = await exchange.getTokenAmount(toWei(100));
      expect(fromWei(tokensOut)).to.equal("181.818181818181818181");

      tokensOut = await exchange.getTokenAmount(toWei(1000));
      expect(fromWei(tokensOut)).to.equal("1000.0");
    });

    it("returns correct ETH amount", async () => {
      let ethOut = await exchange.getEthAmount(toWei(2));
      expect(fromWei(ethOut)).to.equal("0.999000999000999");

      ethOut = await exchange.getEthAmount(toWei(100));
      expect(fromWei(ethOut)).to.equal("47.619047619047619047");

      ethOut = await exchange.getEthAmount(toWei(2000));
      expect(fromWei(ethOut)).to.equal("500.0");
    });
  });
});
