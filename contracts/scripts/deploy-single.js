const { ethers, waffle } = require("hardhat");

const MaxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

const overrides = {
    gasLimit: 9999999
}


async function main() {

    //CVTX
    const mockToken0Contract = (await ethers.getContractFactory("TokenERC20")).attach('0x3F2c28b656e2B40FB8Ff9517dB0286A412b62EE3');
    //MTIX
    const mockToken1Contract = (await ethers.getContractFactory("TokenERC20")).attach('0xB36251BE91f78b24533e746992509000E20bde46');
    //WMAITX
    const WMATICContract = (await ethers.getContractFactory("YsMatic")).attach('0xe11577d241e05D7e6419b4996c1B47eD47f6E37b');

    accounts = await ethers.getSigners();

    // 1. 싱글 스테이킹 팩토리 생성
    // const stakingFactoryContract = await (await ethers.getContractFactory("YsStakingFactory")).deploy(overrides);
    // stakingFactoryContract.deployed();
    // console.log("stakingFactoryContract: ", stakingFactoryContract.address)

    const stakingFactoryContract = (await ethers.getContractFactory("YsStakingFactory")).attach('0x03612359Ca5056d51daE98F99D23e3baf719eFC0');

    //  2. 라우터 생성
    // const stakingRouterContract = await (await ethers.getContractFactory("YsStakingRouter")).deploy(stakingFactoryContract.address, WMATICContract.address, overrides);
    // stakingRouterContract.deployed();
    // console.log("stakingRouterContract: ", stakingRouterContract.address)

    const stakingRouterContract = (await ethers.getContractFactory("YsStakingRouter")).attach('0x0ED16072FB51a4b207c409FA18A7cA5243d8bA51');

    // 3. 스테이킹 풀 생성
    // const rewardPerSecond = ethers.utils.parseEther("1.0").div(86400);
    // const startTimestamp = parseInt(new Date().getTime() / 1000)
    // const bonusPeriodInSeconds = 86400*120;
    // const bonusEndTimestamp = startTimestamp + bonusPeriodInSeconds;

    // await stakingFactoryContract.deployPool(
    //     stakingRouterContract.address,
    //     mockToken0Contract.address, 
    //     mockToken0Contract.address,
    //     rewardPerSecond,
    //     startTimestamp,
    //     bonusEndTimestamp
    // );

    // 4. 풀 컨트랙트 주소 얻기
    // pool = await stakingFactoryContract.getPool(mockToken0Contract.address);
    // const poolContract = (await ethers.getContractFactory("YsStakingPool")).attach(pool);
    // console.log("poolContract: ", poolContract.address)


    // 5. 리워드 입금(라우터에)
    // await mockToken0Contract.approve(accounts[0].address, MaxUint256);
    // await mockToken0Contract.transferFrom(accounts[0].address, stakingRouterContract.address, ethers.utils.parseEther("100.0"));

    // 6. 초기 스테이킹
    // await mockToken0Contract.approve(stakingRouterContract.address, MaxUint256)
    // await stakingRouterContract.investSingle(
    //     mockToken0Contract.address,
    //     ethers.utils.parseEther("10000.0"),
    //     0,
    //     MaxUint256);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
