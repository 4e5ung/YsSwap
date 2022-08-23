# YsSwap Contract


## 실행 환경
npm install

## Deploy
npx hardhat run ./scripts/deploy-pair.js

npx hardhat run ./scripts/deploy-single.js

## 테스트
npx hardhat test ./test/tokenLock-test.js

## ABI Export
npx hardhat export-abi

<hr>

## Slippage

- Max Slippage

```
let slipagePercentage = 0.5;
const slippageMax = 1 + slipagePercentage / 100;

let max = amountsIn[0]*slippageMax;
```

- Min Slippage

```
let slipagePercentage = 0.5;
const slippageMin = 1 - slipagePercentage / 100;

let min = amountsOut[0]*slippageMin;
```


<hr>

## ERROR CODE

Error String 정의


#### YsFactory.sol

| ErrorCode | Description |
| :--- | :--- |
| `YsFactory: E01` |  토큰A,B 주소 같은 경우 |
| `YsFactory: E02` |  토큰 주소가 0인 경우 |
| `YsFactory: E03` |  이미 생성된 페어풀 인 경우 |
| `YsFactory: E04` |  권한없는 계정 접근 |
| `YsFactory: E05` |  올바르지 않는 FEE 금액 |

#### YsPairRouter.sol

| ErrorCode | Description |
| :--- | :--- |
| `YsPairRouter: E01` |  트랜잭션 시간 초과 |
| `YsPairRouter: E02` |  토큰 주소가 0인 경우 |
| `YsPairRouter: E03` |  불충분한 토큰A |
| `YsPairRouter: E04` |  불충분한 토큰B |
| `YsPairRouter: E05` |  토큰 개수 0 |
| `YsPairRouter: E06` |  요청된 토큰 개수가 유동성 초과 |
| `YsPairRouter: E07` |  유동성 0 |
| `YsPairRouter: E08` |  리워드 토큰 개수 0 |
| `YsPairRouter: E09` |  전체 유동성 0 |


#### YsSwapRouter.sol

| ErrorCode | Description |
| :--- | :--- |
| `YsSwapRouter: E01` |  트랜잭션 시간 초과 |
| `YsSwapRouter: E02` |  가격 영향도 초과 |
| `YsSwapRouter: E03` |  불충분한 교환 될 토큰 개수 |
| `YsSwapRouter: E04` |  초과된 교환 토큰 개수 |
| `YsSwapRouter: E05` |  유효하지 않은 주소(WETH) |

#### YsPair.sol

| ErrorCode | Description |
| :--- | :--- |
| `YsPair: E01` |  트랜잭션 시간 초과 |
| `YsPair: E02` |  가격 영향도 초과 |
| `YsPair: E03` |  불충분한 교환 될 토큰 개수 |
| `YsPair: E04` |  초과된 교환 토큰 개수 |
| `YsPair: E05` |  Factory 주소가 일치하지 않음 |
| `YsPair: E06` |  업데이트 할 토큰 개수 초과 |
| `YsPair: E07` |  생성된 유동성 불충분 한 경우 |
| `YsPair: E08` |  제거될 유동성 불충분 한 경우 |
| `YsPair: E09` |  불충분한 토큰 교환 개수 |
| `YsPair: E10` |  불충분한 유동성 |
| `YsPair: E11` |  교환 주소가 올바르지 않은 경우 |
| `YsPair: E12` |  불충분한 교환할 토큰 개수 |
| `YsPair: E13` |  교환 시 수수료 계산 오류 |

#### YsStakingRouter.sol

| ErrorCode | Description |
| :--- | :--- |
| `YsStakingRouter: E01` |  트랜잭션 시간 초과 |
| `YsStakingRouter: E02` |  토큰 개수 0 |
| `YsStakingRouter: E03` |  요청된 토큰 개수가 유동성 초과 |
| `YsStakingRouter: E04` |  유동성 0 |
| `YsStakingRouter: E05` |  리워드 토큰 개수 0 |
| `YsStakingRouter: E06` |  전체 유동성 0 |

#### YsLibrary.sol

| ErrorCode | Description |
| :--- | :--- |
| `YsLibrary: E01` |  토큰A, B 같은 경우 |
| `YsLibrary: E02` |  토큰 주소가 0인 경우 |
| `YsLibrary: E03` |  불충분한 토큰 개수 |
| `YsLibrary: E04` |  불충분한 유동성 |
| `YsLibrary: E05` |  불충분한 Input 토큰 개수 |
| `YsLibrary: E06` |  불충분한 Output 토큰 개수 |
| `YsLibrary: E07` |  유효하지 않은 주소 |

<hr>