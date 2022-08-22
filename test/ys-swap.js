const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");
const { Bignumber } = require("ethers");

const { GasTracker, GetGas } = require('hardhat')

describe("Ys, Swap", function () {

    let accounts;
    let YsFactoryContract;
    let mockToken0Contract;
    let mockToken1Contract;
    let WMATICContract;
    let swapRouterContract;
    let routerContract;

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
      
    it("swapExactTokensForTokens", async function() {
        pair = await YsFactoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
        pairContract = (await ethers.getContractFactory("YsPair")).attach(pair);

        // swap estimate price
        let amountOuts = await routerContract.getAmountsOut(ethers.utils.parseEther("1.0"), [mockToken0Contract.address, mockToken1Contract.address]);

        // get beforeBalance
        let beforeBalance = await mockToken1Contract.balanceOf(pairContract.address);

        await mockToken0Contract.connect(accounts[1]).approve(swapRouterContract.address, MaxUint256)
        await swapRouterContract.connect(accounts[1]).swapExactTokensForTokens(
            ethers.utils.parseEther("1.0"),
            0,
            [mockToken0Contract.address, mockToken1Contract.address],
            accounts[1].address,
            MaxUint256,
            overrides
        )

        // get afterBalance
        let afterBalance = await mockToken1Contract.balanceOf(pairContract.address);
        assert.equal( Number(beforeBalance.sub(afterBalance)), Number(amountOuts[1]) );
    });

    it("swapTokensForExactTokens", async function() {
        pair = await YsFactoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
        pairContract = (await ethers.getContractFactory("YsPair")).attach(pair);

        // swap estimate price
        amountsIn = await routerContract.getAmountsIn( 5000, [mockToken0Contract.address, mockToken1Contract.address])

        // // get beforeBalance
        let beforeBalance = await mockToken0Contract.balanceOf(accounts[1].address);

        let slippagePercentage = 0.5;
        const slippageMax = 1 + slippagePercentage / 100;

        await mockToken0Contract.connect(accounts[1]).approve(swapRouterContract.address, MaxUint256)
        await swapRouterContract.connect(accounts[1]).swapTokensForExactTokens(
            5000,
            Math.floor(amountsIn[0]*slippageMax),
            [mockToken0Contract.address, mockToken1Contract.address],
            accounts[1].address,
            MaxUint256,
            overrides
        )

      // get afterBalance
        let afterBalance = await mockToken0Contract.balanceOf(accounts[1].address);

        assert.equal( Number(beforeBalance.sub(afterBalance)), Number(amountsIn[0]) );
    });

    it("swapExactTokensForETH", async function() {   
        pair = await YsFactoryContract.getPair(mockToken0Contract.address, WMATICContract.address);
        pairContract = (await ethers.getContractFactory("YsPair")).attach(pair);

        // swap estimate price
        let amountOuts = await routerContract.getAmountsOut(5000, [mockToken0Contract.address, WMATICContract.address]);

        // get beforeBalance
        let beforeBalance = await WMATICContract.balanceOf(pairContract.address);


        await mockToken0Contract.connect(accounts[1]).approve(swapRouterContract.address, MaxUint256)
        await swapRouterContract.connect(accounts[1]).swapExactTokensForETH(
            5000,
            0,
            [mockToken0Contract.address, WMATICContract.address],
            accounts[1].address,
            MaxUint256,
            overrides
        )

        // get afterBalance
        let afterBalance = await WMATICContract.balanceOf(pairContract.address);

        assert.equal( Number(beforeBalance.sub(afterBalance)), Number(amountOuts[1]) );
    });
    
    it("swapTokensForExactETH", async function() {
        pair = await YsFactoryContract.getPair(mockToken0Contract.address, WMATICContract.address);
        pairContract = (await ethers.getContractFactory("YsPair")).attach(pair);

        // swap estimate price
        let amountsIn = await routerContract.getAmountsIn(5000, [mockToken0Contract.address, WMATICContract.address]);

        // get beforeBalance
        let beforeBalance = await mockToken0Contract.balanceOf(accounts[1].address);

        let slippagePercentage = 0.5;
        const slippageMax = 1 + slippagePercentage / 100;

        await mockToken0Contract.connect(accounts[1]).approve(swapRouterContract.address, MaxUint256)
        await swapRouterContract.connect(accounts[1]).swapTokensForExactETH(
            5000,
            Math.floor(amountsIn[1]*slippageMax),
            [mockToken0Contract.address, WMATICContract.address],
            accounts[0].address,
            MaxUint256,
            overrides
        )

        // get afterBalance
        let afterBalance = await mockToken0Contract.balanceOf(accounts[1].address);

        assert.equal( Number(beforeBalance.sub(afterBalance)), Number(amountsIn[0]) );
    });
    

    it("swapExactETHForTokens", async function() {
        pair = await YsFactoryContract.getPair(mockToken0Contract.address, WMATICContract.address);
        pairContract = (await ethers.getContractFactory("YsPair")).attach(pair);

        // swap estimate price
        let amountOuts = await routerContract.getAmountsOut(5000, [WMATICContract.address, mockToken0Contract.address]);


        // get beforeBalance
        let beforeBalance = await mockToken0Contract.balanceOf(pairContract.address);

        const overrides = {
            gasLimit: 9999999,
            value : 5000
        }

        await swapRouterContract.connect(accounts[1]).swapExactETHForTokens(
            0,
            [WMATICContract.address, mockToken0Contract.address],
            accounts[1].address,
            MaxUint256,
            overrides
        )

        // get afterBalance
        let afterBalance = await mockToken0Contract.balanceOf(pairContract.address);

        assert.equal( Number(beforeBalance.sub(afterBalance)), Number(amountOuts[1]) );
    });

    it("swapETHForExactTokens", async function() {
        pair = await YsFactoryContract.getPair(mockToken0Contract.address, WMATICContract.address);
        pairContract = (await ethers.getContractFactory("YsPair")).attach(pair);

        // swap estimate price
        let amountsIn = await routerContract.getAmountsIn(5000, [WMATICContract.address, mockToken0Contract.address]);

        // get beforeBalance
        let beforeBalance = await ethers.provider.getBalance(accounts[1].address);

        const overrides = {
            gasLimit: 9999999,
            value : amountsIn[0]
        }

        tx = await swapRouterContract.connect(accounts[1]).swapETHForExactTokens(
            5000,
            [WMATICContract.address, mockToken0Contract.address],
            accounts[1].address,
            MaxUint256,
            overrides
        );
        
        gas = await GetGas(tx)

        // get afterBalance
        let afterBalance = await ethers.provider.getBalance(accounts[1].address);

        assert.equal(ethers.BigNumber.from(beforeBalance).sub(afterBalance), Number(gas*tx.gasPrice) + Number(amountsIn[0]));
    });
});
