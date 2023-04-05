// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './YsStakingPool.sol';
import "./access/Ownable.sol";

contract YsStakingFactory is Ownable {
    event PoolCreated(address indexed newPool);

    mapping(address => address) public getPool;
    address[] public allPools;
    
    constructor() {
    }

    /// @dev get pools length
    function allPoolsLength() external view returns (uint) {
        return allPools.length;
    }


    /// @dev deploy single staking pool
    /// @param _router stakingRouter contract
    /// @param _stakedToken staking token address
    /// @param _rewardToken reward token address
    /// @param _rewardPerSecond reward sec amount
    /// @param _startTimestamp create pool time
    /// @param _bonusEndTimestamp end reward pool time
    function deployPool(
        address _router,
        address _stakedToken,
        address _rewardToken,
        uint256 _rewardPerSecond,
        uint256 _startTimestamp,
        uint256 _bonusEndTimestamp
    ) external onlyOwner returns(YsStakingPool pool){
        require(IERC20(_stakedToken).totalSupply() >= 0, 'YsStakingFactory: E01');
        require(IERC20(_rewardToken).totalSupply() >= 0, 'YsStakingFactory: E02');
        require(getPool[_stakedToken] == address(0), 'YsStakingFactory: E03');

        pool = new YsStakingPool();

        pool.initialize(
            _router,
            _stakedToken,
            _rewardToken,
            _rewardPerSecond,
            _startTimestamp,
            _bonusEndTimestamp,
            msg.sender
        );

        getPool[_stakedToken] = address(pool);
        allPools.push(address(pool));

        emit PoolCreated(address(pool));
    }
}
