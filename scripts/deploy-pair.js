const { ethers, waffle } = require("hardhat");

const MaxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

const overrides = {
    gasLimit: 9999999
}


async function main() {

    //CVTX
    const mockToken0Contract = (await ethers.getContractFactory("TokenERC20")).attach('0x7B6acf22c1e90E2073d3C0D325EC61116e2F77de');
    //MTIX
    const mockToken1Contract = (await ethers.getContractFactory("TokenERC20")).attach('0x7BdcC2AC8A880A28CaB38A4733A9B3AC1F51897D');
    //WMAITX
    const WMATICContract = (await ethers.getContractFactory("YsMatic")).attach('0x5AC6BE7984Ed33CfD0872f6AFDD78d38d1859693');

    accounts = await ethers.getSigners();

    // 1. 팩토리 생성
    // const factoryContract = await (await ethers.getContractFactory("YsFactory")).deploy(accounts[0].address, overrides);
    // factoryContract.deployed();
    // console.log("factoryContract: ", factoryContract.address)
    const factoryContract = (await ethers.getContractFactory("YsFactory")).attach('0x73B5FCF31B8486d4e8700206580C1CF3bf8B299a');

    // 2. 스테이킹 라우터 생성
    // const routerContract = await (await ethers.getContractFactory("YsPairRouter")).deploy(factoryContract.address, WMATICContract.address, overrides);
    // routerContract.deployed();
    // console.log("routerContract: ", routerContract.address)
    const routerContract = (await ethers.getContractFactory("YsPairRouter")).attach('0x3C65C1Edde34bC02d0ab75dEDe241244111193a0');

    // 3. swap 라우터 생성
    // const swapRouterContract = await (await ethers.getContractFactory("YsSwapRouter")).deploy(factoryContract.address, WMATICContract.address, overrides);
    // swapRouterContract.deployed();
    // console.log("swapRouterContract: ", swapRouterContract.address)
    const swapRouterContract = (await ethers.getContractFactory("YsSwapRouter")).attach('0xC9B6548Eb51441B800e7baFD1186DD9e656e3B30');


    // 4. 페어쌍 생성
    // const swapFee = 30;
    // const protocolFee = 0;

    // const rewardPerSecond = ethers.utils.parseEther("1.0").div(86400);
    // const startTimestamp = parseInt(new Date().getTime() / 1000)
    // const bonusPeriodInSeconds = 86400*120;
    // const bonusEndTimestamp = startTimestamp + bonusPeriodInSeconds;

    // await factoryContract.createPair(routerContract.address,
    //     mockToken0Contract.address, 
    //     mockToken1Contract.address, 
    //     swapFee, 
    //     protocolFee,
    //     mockToken0Contract.address,
    //     rewardPerSecond,
    //     startTimestamp,
    //     bonusEndTimestamp,
    //     overrides
    // );

    // 5. 페어 컨트랙트 주소 얻기
    // pair = await factoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
    // const pairContract = (await ethers.getContractFactory("YsPair")).attach(pair);
    // console.log("pairContract: ", pairContract.address)

    // 6. 리워드 토큰 주입(라우터에)
    // await mockToken0Contract.approve(accounts[0].address, ethers.utils.parseEther("100.0"), overrides);
    // await mockToken0Contract.transferFrom(accounts[0].address, routerContract.address, ethers.utils.parseEther("100.0"), overrides);


    // 7. 예치(초기 LP풀 생성)
    // await mockToken0Contract.approve(routerContract.address, MaxUint256, overrides)
    // await mockToken1Contract.approve(routerContract.address, MaxUint256, overrides)

    // allowance = await mockToken0Contract.allowance(accounts[0].address, routerContract.address);
    // console.log(allowance);
    // allowance = await mockToken1Contract.allowance(accounts[0].address, routerContract.address);
    // console.log(allowance);

    // await routerContract.investPair(
    //     mockToken0Contract.address,
    //     mockToken1Contract.address,
    //     ethers.utils.parseEther("10000.0"),
    //     ethers.utils.parseEther("10000.0"),
    //     0,
    //     0,
    //     MaxUint256,
    //     overrides
    // )   

    // 8. 계산 컨트랙트 생성
    // const computeLiquidityContract = await (await ethers.getContractFactory("YsCompute")).deploy(factoryContract.address, overrides);
    // console.log("computeLiquidityContract: ", computeLiquidityContract.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
