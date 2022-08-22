# TokenLock Contract


## 실행 환경
npm install

## Deploy
npx hardhat run ./scripts/deploy-pair.js

npx hardhat run ./scripts/deploy-pair.js

npx hardhat run ./scripts/deploy-pair.js

## 테스트
npx hardhat test ./test/tokenLock-test.js

## ABI Export
npx hardhat export-abi

<hr>

## ERROR CODE

Error String 정의

#### YsCompute.sol

| ErrorCode | Description |
| :--- | :--- |
| `TokenLock: E01` |  admin 계정이 올바르지 않음 |
| `TokenLock: E02` |  일치하는 lokcup 정보 없음 |
| `TokenLock: E03` |  일치하는 lokcup index 없음 |
| `TokenLock: E04` |  address 유효하지 않음 |
| `TokenLock: E05` |  토큰 개수가 올바르지 않음음 |
| `TokenLock: E06` |  lockup 기간이 올바르지 않음 |


#### YsFactory.sol

| ErrorCode | Description |
| :--- | :--- |
| `TokenLock: E01` |  admin 계정이 올바르지 않음 |
| `TokenLock: E02` |  일치하는 lokcup 정보 없음 |
| `TokenLock: E03` |  일치하는 lokcup index 없음 |
| `TokenLock: E04` |  address 유효하지 않음 |
| `TokenLock: E05` |  토큰 개수가 올바르지 않음음 |
| `TokenLock: E06` |  lockup 기간이 올바르지 않음 |
<hr>