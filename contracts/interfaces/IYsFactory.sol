// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IYsFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(
        address router,
        address tokenA, 
        address tokenB, 
        uint8 swapFee, 
        uint8 protocolFee,
        address rewardToken,
        uint256 rewardPerSecond,
        uint256 startTimestamp,
        uint256 bonusEndTimestamp
        // uint256 poolLimitPerUser
    )external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
