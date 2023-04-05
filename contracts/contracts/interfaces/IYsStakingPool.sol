// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IYsStakingPool {
    function deposit(uint256 _amount, address _from, uint256 _period) external returns(uint256 pending);
    function withdraw(uint256 _amount, address _burnFrom, address _from) external returns(uint256 pending);
    // function pendingReward(address _user) external view returns (uint256);
    function userState(address _user) external view returns (uint256 amount, uint256 rewardDebt, uint256 cumulativeRewardDebt, uint256 endTime);
    function rewardToken() external view returns (address);
}
