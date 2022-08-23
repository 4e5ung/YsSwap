const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");
const { Bignumber } = require("ethers");

describe("Ys, PairStaking", function () {

    let accounts;
    let YsFactoryContract;
    let mockToken0Contract;
    let mockToken1Contract;
    let WMATICContract;
    let routerContract;
    let swapRouterContract;
    let mockRewardTokenContract;
    let pairContract;

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
    
    
    it("Token+Token Staking, investPair", async function(){
        pair = await YsFactoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
        pairContract = (await ethers.getContractFactory("YsPair")).attach(pair);

        beforeBalance = await pairContract.balanceOf(pairContract.address);

        await mockToken0Contract.connect(accounts[1]).approve(routerContract.address, MaxUint256)
        await mockToken1Contract.connect(accounts[1]).approve(routerContract.address, MaxUint256)    
        tx = await routerContract.connect(accounts[1]).investPair(
            mockToken0Contract.address,
            mockToken1Contract.address,
            10000,
            5000,
            0,
            0,
            MaxUint256
        )

        afterBalance = await pairContract.balanceOf(pairContract.address);

        assert.equal( ethers.BigNumber.from(afterBalance).sub(beforeBalance), 7071 );
    });

    it("Token+Token Staking, withdrawPair", async function(){
        beforeToken0 = await mockToken0Contract.balanceOf(accounts[0].address);
        beforeToken1 = await mockToken1Contract.balanceOf(accounts[0].address);

        await routerContract.withdrawPair( 
            mockToken0Contract.address,
            mockToken1Contract.address,
            100000, 
            0, 
            0,
            MaxUint256
        )

        afterToken0 = await mockToken0Contract.balanceOf(accounts[0].address);
        afterToken1 = await mockToken1Contract.balanceOf(accounts[0].address);

        assert.equal( ethers.BigNumber.from(afterToken0).sub(beforeToken0), 49999999986950511n );
        assert.equal( ethers.BigNumber.from(afterToken1).sub(beforeToken1), 70710 );
    });

    it("Token+Coin Staking, investPairETH", async function(){
        pair = await YsFactoryContract.getPair(mockToken0Contract.address, WMATICContract.address);
        pairContract = (await ethers.getContractFactory("YsPair")).attach(pair);

        beforeBalance = await pairContract.balanceOf(pairContract.address);

        await mockToken0Contract.connect(accounts[1]).approve(routerContract.address, MaxUint256)
    
        const overrides = {
            gasLimit: 9999999,
            value : ethers.utils.parseEther("50.0")
        }

        await routerContract.connect(accounts[1]).investPairETH(
            mockToken0Contract.address,
            ethers.utils.parseEther("20.0"),
            0,
            0,
            MaxUint256,
            overrides);

        afterBalance = await pairContract.balanceOf(pairContract.address);

        assert.equal( ethers.BigNumber.from(afterBalance).sub(beforeBalance), 28284271247461900976n );
    });

    it("Token+Coin Staking, withdrawPairETH", async function(){
        beforeToken0 = await mockToken0Contract.balanceOf(accounts[0].address);

        await routerContract.connect(accounts[0]).withdrawPairETH( 
            mockToken0Contract.address,
            31622776601683793219n, 
            0, 
            0,
            MaxUint256);

        afterToken0 = await mockToken0Contract.balanceOf(accounts[0].address);

        assert.equal( ethers.BigNumber.from(afterToken0).sub(beforeToken0), 22390679774947555939n );
    });

    it("PairStaking, userInfo", async function(){

        await mockToken0Contract.connect(accounts[1]).approve(swapRouterContract.address, MaxUint256)
        
        await swapRouterContract.connect(accounts[1]).swapExactTokensForTokens(
            ethers.utils.parseEther("1.0"),
            0,
            [mockToken0Contract.address, mockToken1Contract.address],
            accounts[1].address,
            MaxUint256,
            overrides
        )

        expect(await routerContract.userInfo(
            mockToken0Contract.address,
            mockToken1Contract.address,
            accounts[0].address
        ))
        .to.deep.eq([ethers.BigNumber.from(70710678118654742440n), ethers.BigNumber.from(59999999970028773n),  ethers.BigNumber.from(0), ethers.BigNumber.from(2999999999999999), ethers.BigNumber.from(0)]);        
    });

    it("PairStaking, harvest", async function(){
        await routerContract.connect(accounts[0]).harvest(
            mockToken0Contract.address, 
            mockToken1Contract.address, 
            MaxUint256
            );

        expect(await mockRewardTokenContract.balanceOf(accounts[0].address)).to.equals(ethers.BigNumber.from(999999740049999999986809090n));
    });

    it("PairStaking, collect", async function(){
        await mockToken0Contract.connect(accounts[1]).approve(swapRouterContract.address, MaxUint256)
        
        await swapRouterContract.connect(accounts[1]).swapExactTokensForTokens(
            ethers.utils.parseEther("1.0"),
            0,
            [mockToken0Contract.address, mockToken1Contract.address],
            accounts[1].address,
            MaxUint256,
            overrides
        )
        
        beforeBalance = await mockToken0Contract.balanceOf(accounts[0].address);
        
        await routerContract.connect(accounts[0]).collect(
            mockToken0Contract.address, 
            mockToken1Contract.address,
            MaxUint256
            );

        afterBalance = await mockToken0Contract.balanceOf(accounts[0].address);

        assert.equal(ethers.BigNumber.from(afterBalance).sub(beforeBalance), 2999999999999999);
    });   
});
