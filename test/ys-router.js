const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");
const { Bignumber } = require("ethers");

describe("Ys, router", function () {

    let accounts;
    let YsFactoryContract;
    let mockToken0Contract;
    let mockToken1Contract;
    let WMATICContract;
    let routerContract;
    let swapRouterContract;

    const MaxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

    const overrides = {
        gasLimit: 9999999
    }


    beforeEach(async function () { 
        accounts = await ethers.getSigners();

        YsFactoryContract = await (await ethers.getContractFactory("YsFactory")).deploy(accounts[0].address);
        
        const MockTokenContract = await ethers.getContractFactory("TokenERC20");
        mockToken0Contract = await MockTokenContract.deploy("TestToken", "TOKENA");
        mockToken1Contract = await MockTokenContract.deploy("TestToken", "TOKENB");
        // mockRewardTokenContract = await MockTokenContract.deploy("TestToken", "YS");

        mockRewardTokenContract = mockToken0Contract;


        WMATICContract = await (await ethers.getContractFactory("YsMatic")).deploy();

        routerContract = await (await ethers.getContractFactory("YsPairRouter")).deploy(YsFactoryContract.address, WMATICContract.address);
        swapRouterContract = await (await ethers.getContractFactory("YsSwapRouter")).deploy(YsFactoryContract.address, WMATICContract.address);

        const swapFee = 30;
        const protocolFee = 5;

        const rewardPerSecond = ethers.utils.parseEther("0.01");
        const startTimestamp = parseInt(new Date().getTime() / 1000) //uint256
        // const bonusPeriodInSeconds = 2419200
        const bonusPeriodInSeconds = 86400*30;
        const bonusEndTimestamp = startTimestamp + bonusPeriodInSeconds; //uint256
        // const poolLimitPerUser = 100000000000; //uint256
        const poolLimitPerUser = 0; //uint256

        await YsFactoryContract.createPair(routerContract.address,
            mockToken0Contract.address, 
            mockToken1Contract.address, 
            swapFee, 
            protocolFee,
            mockRewardTokenContract.address,
            rewardPerSecond,
            startTimestamp,
            bonusEndTimestamp
            );

        await YsFactoryContract.createPair(routerContract.address,
                mockToken0Contract.address, 
                WMATICContract.address, 
                swapFee, 
                protocolFee,
                mockRewardTokenContract.address,
                rewardPerSecond,
                startTimestamp,
                bonusEndTimestamp
                );

        await mockToken0Contract.approve(accounts[0].address, MaxUint256);
        await mockToken0Contract.transferFrom(accounts[0].address, accounts[1].address, ethers.utils.parseEther("100.0"));
        
        await mockToken1Contract.approve(accounts[0].address, MaxUint256);
        await mockToken1Contract.transferFrom(accounts[0].address, accounts[1].address, ethers.utils.parseEther("100.0"));

        
        await mockRewardTokenContract.approve(accounts[0].address, MaxUint256);
        await mockRewardTokenContract.transferFrom(accounts[0].address, routerContract.address, ethers.utils.parseEther("10.0"));



        await mockToken0Contract.approve(routerContract.address, MaxUint256)
        await mockToken1Contract.approve(routerContract.address, MaxUint256)
        await routerContract.connect(accounts[0]).investPair(
            mockToken0Contract.address,
            mockToken1Contract.address,
            ethers.utils.parseEther("100.0"),
            ethers.utils.parseEther("50.0"),
            0,
            0,
            MaxUint256);

        const overrides = {
            gasLimit: 9999999,
            value : ethers.utils.parseEther("100.0")
        }
        await mockToken0Contract.approve(routerContract.address, MaxUint256)
        await routerContract.connect(accounts[0]).investPairETH(
            mockToken0Contract.address,
            ethers.utils.parseEther("50.0"),
            0,
            0,
            MaxUint256,
            overrides);


        await mockToken0Contract.approve(routerContract.address, 0)
        await mockToken1Contract.approve(routerContract.address, 0)
    });
      
    it("Estimate Price, getAmountsOut", async function() {
        expect(await routerContract.getAmountsOut(10000, [mockToken0Contract.address, mockToken1Contract.address])).to.deep.eq([ethers.BigNumber.from(10000), ethers.BigNumber.from(4984)]);
        //ethers.utils.formatUnits(ethers.BigNumber.from(498), 18)        
    });

    
    it("Estimate Price, getAmountsIn", async function() {
        let slippagePercentage = 0.5;
        const slippageMax = 1 + slippagePercentage / 100;

        expect(await routerContract.getAmountsIn( 5000, [mockToken0Contract.address, mockToken1Contract.address])).to.deep.eq([ethers.BigNumber.from(10031), ethers.BigNumber.from(5000)]);
        assert.equal( ethers.BigNumber.from(10031)*slippageMax, 10081.154999999999 );
    });

    it("Estimate Slippage, getAmountsOut", async function() {
        let slippagePercentage = 0.5;
        const slippage = 1- slippagePercentage / 100;

        expect(await routerContract.getAmountsOut(1000, [mockToken0Contract.address, mockToken1Contract.address])).to.deep.eq([ethers.BigNumber.from(1000), ethers.BigNumber.from(498)]);
        assert.equal( ethers.BigNumber.from(498)*slippage, 495.51 );

        // let slippageAmount = ethers.BigNumber.from(498)*slippage;
        // console.log("slippageAmount: ", slippageAmount);

        //ethers.utils.formatUnits(ethers.BigNumber.from(498), 18)        
    });

    it("Price impact", async function() {
        expect(await swapRouterContract.getPriceImpact(10000, [mockToken0Contract.address, mockToken1Contract.address])).to.equals(2);
    });

     it("Liquidity Share of pool", async function() {
        expect(await routerContract.getShareOfPool(
            mockToken0Contract.address, 
            mockToken1Contract.address, 
            ethers.utils.parseEther("10.0"), 
            ethers.utils.parseEther("5.0"),
            false)).to.equals(909);        

        expect(await routerContract.getShareOfPool(
            mockToken0Contract.address, 
            mockToken1Contract.address, 
            0, 
            0,
            true)).to.equals(10000);
    }); 
});
