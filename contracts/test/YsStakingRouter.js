const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");
const { Bignumber } = require("ethers");
const helpers = require("@nomicfoundation/hardhat-network-helpers");
const { userInfo } = require("os");

describe("Ys, SingleStaking", function () {

    let accounts;
    let YsStakingFactoryContract;
    let mockToken0Contract;
    let mockToken1Contract;
    let WMATICContract;
    let stakingRouterContract;
    let mockRewardTokenContract;
    let pairContract;

    const MaxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

    const overrides = {
        gasLimit: 9999999
    }

    beforeEach(async function () { 
        accounts = await ethers.getSigners();

        YsStakingFactoryContract = await (await ethers.getContractFactory("YsStakingFactory")).deploy();
        
        const MockTokenContract = await ethers.getContractFactory("TokenERC20");
        mockToken0Contract = await MockTokenContract.deploy("TestToken", "CVTX");
        mockToken1Contract = await MockTokenContract.deploy("TestToken", "MTIX");
        
        // mockRewardTokenContract = mockToken0Contract;

        mockRewardTokenContract = await MockTokenContract.deploy("TestToken", "YS");

        WMATICContract = await (await ethers.getContractFactory("YsMatic")).deploy();

        stakingRouterContract = await (await ethers.getContractFactory("YsStakingRouter")).deploy(YsStakingFactoryContract.address, WMATICContract.address);

        const rewardPerSecond = ethers.utils.parseEther("1.0").div(86400);
        const startTimestamp = parseInt(new Date().getTime() / 1000)
        const bonusEndTimestamp = startTimestamp + 86400*30;

        pool = await YsStakingFactoryContract.getPool(mockToken0Contract.address);
        poolContract = (await ethers.getContractFactory("YsStakingPool")).attach(pool);

        await YsStakingFactoryContract.deployPool(
            stakingRouterContract.address,
            mockToken0Contract.address, 
            mockRewardTokenContract.address,
            rewardPerSecond,
            startTimestamp,
            bonusEndTimestamp
            );

        await YsStakingFactoryContract.deployPool(
            stakingRouterContract.address,
            WMATICContract.address, 
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
        await mockRewardTokenContract.transferFrom(accounts[0].address, stakingRouterContract.address, ethers.utils.parseEther("10.0"));

        await mockToken0Contract.approve(stakingRouterContract.address, MaxUint256)
        await stakingRouterContract.investSingle(
            mockToken0Contract.address,
            ethers.utils.parseEther("100.0"),
            0,
            MaxUint256);


        const overrides = {
            gasLimit: 9999999,
            value : ethers.utils.parseEther("100.0")
        }

        await stakingRouterContract.investSingleETH(
            0,
            MaxUint256,
            overrides);

        await mockToken0Contract.approve(stakingRouterContract.address, 0)
    });

    it("SingleStaking, investSingle", async function(){
        pool = await YsStakingFactoryContract.getPool(mockToken0Contract.address);
        poolContract = (await ethers.getContractFactory("YsStakingPool")).attach(pool); 

        beforeBalance = await mockToken0Contract.balanceOf(poolContract.address);

        await mockToken0Contract.connect(accounts[1]).approve(stakingRouterContract.address, MaxUint256)
        await stakingRouterContract.connect(accounts[1]).investSingle(
            mockToken0Contract.address,
            ethers.utils.parseEther("1.0"),
            10,
            MaxUint256);

        afterBalance = await mockToken0Contract.balanceOf(poolContract.address);

        assert.equal( ethers.BigNumber.from(afterBalance).sub(beforeBalance), 1000000000000000000n );

        await stakingRouterContract.connect(accounts[1]).investSingle(
            mockToken0Contract.address,
            ethers.utils.parseEther("1.0"),
            10,
            MaxUint256);

        after2Balance = await mockToken0Contract.balanceOf(poolContract.address);

        assert.equal( ethers.BigNumber.from(after2Balance).sub(afterBalance), 1000000000000000000n );
    });

    it("SingleStaking, withdrawSingle", async function(){
        beforeBalance = await mockToken0Contract.balanceOf(accounts[0].address);

        await stakingRouterContract.withdrawSingle(
            mockToken0Contract.address,
            100000,
            MaxUint256
        )

        afterBalance = await mockToken0Contract.balanceOf(accounts[0].address);

        assert.equal( ethers.BigNumber.from(afterBalance).sub(beforeBalance), 100000);
    });


    it("SingleStaking, investSingleETH", async function(){
        pool = await YsStakingFactoryContract.getPool(WMATICContract.address);
        poolContract = (await ethers.getContractFactory("YsStakingPool")).attach(pool); 

        beforeBalance = await WMATICContract.balanceOf(poolContract.address);

        const overrides = {
            gasLimit: 9999999,
            value : ethers.utils.parseEther("1.0")
        }

        await stakingRouterContract.connect(accounts[1]).investSingleETH(
            10,
            MaxUint256,
            overrides);

        afterBalance = await WMATICContract.balanceOf(poolContract.address);

        assert.equal( ethers.BigNumber.from(afterBalance).sub(beforeBalance), 1000000000000000000n );
    });

    it("SingleStaking, withdrawSingleETH", async function(){
        beforeBalance = await mockRewardTokenContract.balanceOf(accounts[0].address);

        await stakingRouterContract.connect(accounts[0]).withdrawSingleETH( 
            ethers.utils.parseEther("1.0"),
            MaxUint256);

        afterBalance = await mockRewardTokenContract.balanceOf(accounts[0].address);

        assert.equal( ethers.BigNumber.from(afterBalance).sub(beforeBalance), 23148100000000n );
    });

    it("SingleStaking, userInfo", async function(){
        userinfo = await stakingRouterContract.userInfo(
            mockToken0Contract.address,
            accounts[0].address
        )

        assert.equal( userinfo[0], 100000000000000000000n );
    });

    it("SingleStaking, harvest", async function(){        
        beforeBalance = await mockRewardTokenContract.balanceOf(accounts[0].address);

        await stakingRouterContract.harvest(
            mockToken0Contract.address, 
            MaxUint256
            );
        
        afterBalance = await mockRewardTokenContract.balanceOf(accounts[0].address);

        assert.equal( ethers.BigNumber.from(afterBalance).sub(beforeBalance), 34722200000000n);
    });  

    it("SingleStaking, harvestEth", async function(){        
        beforeBalance = await mockRewardTokenContract.balanceOf(accounts[0].address);

        await stakingRouterContract.harvest(
            WMATICContract.address, 
            MaxUint256
            );
        
        afterBalance = await mockRewardTokenContract.balanceOf(accounts[0].address);

        assert.equal( ethers.BigNumber.from(afterBalance).sub(beforeBalance), 23148100000000n);
    }); 

    it("SingleStaking, getShareOfPool", async function(){        
        shareOfPool = await stakingRouterContract.getShareOfPool(
            mockToken0Contract.address, 
            ethers.utils.parseEther("1.0"),
            false
            );

        assert.equal(shareOfPool, 99);
        
        shareOfPool = await stakingRouterContract.getShareOfPool(
            mockToken0Contract.address, 
            0,
            true
            );

        assert.equal(shareOfPool, 10000);
    }); 
    
    
});
