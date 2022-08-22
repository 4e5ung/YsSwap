// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IYsStakingFactory {
    event PoolCreated(address indexed token);

    function getPool(address token) external view returns (address pool);
    function allPools(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function deployPool(
        address _router,
        address _stakedToken,
        address _rewardToken,
        uint256 _rewardPerSecond,
        uint256 _startTimestamp,
        uint256 _bonusEndTimestamp
    ) external returns(address pool);
}
