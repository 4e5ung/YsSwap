const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");

describe("Ys, factory", function () {

    let accounts;
    let YsFactoryContract;
    let mockToken0Contract;
    let mockToken1Contract;
    let WMATICContract;
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

        await mockToken0Contract.approve(routerContract.address, 0)
        await mockToken1Contract.approve(routerContract.address, 0)
    });
   
    // it("Change Swap Fee", async function() {      
    //     pair = await YsFactoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
    //     pairContract = (await ethers.getContractFactory("YsPair")).attach(pair);

    //     const swapFee = 10;
    //     const protocolFee = 1;

    //     await YsFactoryContract.setSwapFee(mockToken0Contract.address, mockToken1Contract.address, swapFee);
    //     await YsFactoryContract.setProtocolFee(mockToken0Contract.address, mockToken1Contract.address, protocolFee);

    //     expect(await pairContract.swapFee()).to.equals(swapFee);
    //     expect(await pairContract.protocolFee()).to.equals(protocolFee);
    // });
});
