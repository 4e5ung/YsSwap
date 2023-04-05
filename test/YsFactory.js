const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");

describe("YsFactory", function () {

    let accounts;
    let YsFactoryContract;
    let mockToken0Contract;
    let mockToken1Contract;
    let mockRewardTokenContract;
    let WMATICContract;
    let routerContract;
    let pairContract;

    const MaxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

    const overrides = {
        gasLimit: 9999999
    }


    beforeEach(async function () { 
        accounts = await ethers.getSigners();

        YsFactoryContract = await (await ethers.getContractFactory("YsFactory")).deploy(accounts[0].address, accounts[0].address);
        
        const MockTokenContract = await ethers.getContractFactory("TokenERC20");
        mockToken0Contract = await MockTokenContract.deploy("TestToken", "CVTX");
        mockToken1Contract = await MockTokenContract.deploy("TestToken", "MTIX");
        mockRewardTokenContract = await MockTokenContract.deploy("TestToken", "YS");

        mockRewardTokenContract = mockToken0Contract;


        WMATICContract = await (await ethers.getContractFactory("YsMatic")).deploy();
        routerContract = await (await ethers.getContractFactory("YsPairRouter")).deploy(YsFactoryContract.address, WMATICContract.address);

        const swapFee = 30;
        const protocolFee = 5;
        const rewardPerSecond = ethers.utils.parseEther("0.01");
        const startTimestamp = parseInt(new Date().getTime() / 1000)
        const bonusEndTimestamp = startTimestamp + 86400*30;

        pairContract = await (await ethers.getContractFactory("YsPair")).deploy(
            YsFactoryContract.address,
            routerContract.address,
            mockToken0Contract.address, 
            mockToken1Contract.address, 
            swapFee, 
            protocolFee,
            mockRewardTokenContract.address,
            rewardPerSecond,
            startTimestamp,
            bonusEndTimestamp
        );
        
        await YsFactoryContract.setPair(
            pairContract.address,
            mockToken0Contract.address, 
            mockToken1Contract.address
        )

        pairContract = await (await ethers.getContractFactory("YsPair")).deploy(
            YsFactoryContract.address,
            routerContract.address,
            mockToken0Contract.address, 
            WMATICContract.address, 
            swapFee, 
            protocolFee,
            mockRewardTokenContract.address,
            rewardPerSecond,
            startTimestamp,
            bonusEndTimestamp
        );
        
        await YsFactoryContract.setPair(
            pairContract.address,
            mockToken0Contract.address, 
            WMATICContract.address
        )
    });

    it("setProtocolFee", async function() {
        pair = await YsFactoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
        pairContract = (await ethers.getContractFactory("YsPair")).attach(pair);

        const protocolFee = 1;
        await YsFactoryContract.setProtocolFee(
            mockToken0Contract.address, 
            mockToken1Contract.address, 
            protocolFee
        );

        expect(await pairContract.protocolFee()).to.equals(protocolFee);
    });

    it("setSwapFee", async function() {      
        pair = await YsFactoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
        pairContract = (await ethers.getContractFactory("YsPair")).attach(pair);

        const swapFee = 10;
        await YsFactoryContract.setSwapFee(
            mockToken0Contract.address, 
            mockToken1Contract.address, 
            swapFee
        );

        expect(await pairContract.swapFee()).to.equals(swapFee);
    });

    it("setFeeTo", async function() {      
        pair = await YsFactoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
        pairContract = (await ethers.getContractFactory("YsPair")).attach(pair);

        await YsFactoryContract.setFeeTo(mockToken0Contract.address, mockToken1Contract.address, accounts[1].address);

        expect(await pairContract.feeTo()).to.equals(accounts[1].address);
    });
});
