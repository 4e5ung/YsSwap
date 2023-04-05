// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './access/Ownable.sol';
import "./security/ReentrancyGuard.sol";

import './libraries/TransferHelper.sol';
import './libraries/YsLibrary.sol';

import './interfaces/IYsStakingPool.sol';

import "./interfaces/IERC20.sol";

contract YsStakingPool is Ownable, ReentrancyGuard {

    address private immutable stakeFactory;
    address private router;

    uint256 private accTokenPerShare;
    uint256 private bonusEndTimestamp;
    uint256 private startTimestamp;
    uint256 private lastRewardTimestamp;
    uint256 private rewardPerSecond;
    uint256 private PRECISION_FACTOR = 10**12;
    address public rewardToken;
    address public stakedToken;

    int32 private deadlineSeconds = 180 seconds;

    mapping(address => UserInfo) public userInfo;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 cumulativeRewardDebt;
        uint256 endTime;
    }

    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event NewStartAndEndBlocks(uint256 startTimestamp, uint256 endBlock);
    event NewrewardPerSecond(uint256 rewardPerSecond);
    event RewardsStop(uint256 blockNumber);
    event Withdraw(address indexed user, uint256 amount);

    constructor() {
        stakeFactory = msg.sender;
    }

    modifier onlyFactory(){
        require(msg.sender == stakeFactory, 'YsStakingPool: E01');
        _;
    }

    modifier onlyRouter(){
        require(msg.sender == router, 'YsStakingPool: E02');
        _;
    }

    /// @dev Initialize the contract
    /// @param _router stakingRouter contract address
    /// @param _stakedToken: staked token address
    /// @param _rewardToken: reward token address
    /// @param _rewardPerSecond: reward per block (in rewardToken)
    /// @param _startTimestamp: contract start time
    /// @param _bonusEndTimestamp: end block
    /// @param _admin: admin address with ownership
    function initialize(
        address _router,
        address _stakedToken,
        address _rewardToken,
        uint256 _rewardPerSecond,
        uint256 _startTimestamp,
        uint256 _bonusEndTimestamp,
        address _admin
    ) external onlyFactory{
        stakedToken = _stakedToken;
        rewardToken = _rewardToken;
        rewardPerSecond = _rewardPerSecond;
        startTimestamp = _startTimestamp;
        bonusEndTimestamp = _bonusEndTimestamp;
        lastRewardTimestamp = startTimestamp;
        router = _router;

        transferOwnership(_admin);
    }

    /// @dev Deposit staked tokens and collect reward tokens (if any)
    /// @param _amount deposit token amount
    /// @param _from deposit eoa
    /// @param _period deposit period time
    function deposit(
        uint256 _amount, 
        address _from, 
        uint256 _period
    ) external onlyRouter nonReentrant returns(uint256 pending){

        UserInfo storage user = userInfo[_from];

        _updatePool();

        if (user.amount > 0) {
            // ((기존 개인 스테이킹 한 양 * 공유Token) / 10**12) - rewardDebt
            pending = ((user.amount*accTokenPerShare)/(PRECISION_FACTOR))-user.rewardDebt;
            if (pending > 0) {
                user.cumulativeRewardDebt += pending;
            }
        }

        if (_amount > 0) {
            // 기존 개인 스테이킹 양에 추가 개인 스테이킹
            user.amount = user.amount+_amount;
            // 라우터에서 pool로 옮김
            TransferHelper.safeTransferFrom(stakedToken, router, address(this), _amount);
        }

        // (개인 스테이킹 양 * 공유Token) / 10**12
        user.rewardDebt = (user.amount*accTokenPerShare)/PRECISION_FACTOR;
        user.endTime = block.timestamp + _period;

        emit Deposit(_from, _amount);
    }

    /// @dev Withdraw staked tokens and collect reward tokens
    /// @param _amount widthdraw amount
    /// @param _burnFrom burn eoa(eth=weth)
    /// @param _from withdraw eoa
    /// @return pending reward amount
    function withdraw(
        uint256 _amount, 
        address _burnFrom, 
        address _from
    ) external onlyRouter nonReentrant returns(uint256 pending){
        UserInfo storage user = userInfo[_from];
        
        _updatePool();

        // ((기존 개인 스테이킹 한 양 * accTokenPerShare) / 10**12) - rewardDebt
        pending = ((user.amount*accTokenPerShare)/PRECISION_FACTOR)-user.rewardDebt;

        if (_amount > 0) {
            require( user.endTime <= block.timestamp, 'YsStakingPool: E03');

            user.amount = user.amount-_amount;
            // 요청한 개인 스테이킹 양만큼 제거
            TransferHelper.safeTransfer(stakedToken, address(_burnFrom), _amount);
        }

        if (pending > 0) {
            // pending 금액만큼 Reward
            user.cumulativeRewardDebt += pending;
        }

        // (개인 스테이킹 양 * accTokenPerShare) / 10**12
        user.rewardDebt = (user.amount*accTokenPerShare)/PRECISION_FACTOR;

        if( user.amount == 0 ){
            user.endTime = 0;
        }

        emit Withdraw(_from, _amount);
    }

    /// @dev Withdraw staked tokens without caring about rewards rewards
    /// @param _from emergency eoa
    function emergencyWithdraw(address _from) external onlyOwner nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amountToTransfer = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        if (amountToTransfer > 0) {
            // stakedToken.safeTransfer(address(msg.sender), amountToTransfer);
            TransferHelper.safeTransfer(stakedToken, address(_from), amountToTransfer);
        }

        emit EmergencyWithdraw(msg.sender, user.amount);
    }

    /// @dev Stop rewards
    function stopReward() external onlyOwner {
        bonusEndTimestamp = block.timestamp;
    }

    // /// @dev Update reward per block
    // /// @param _rewardPerSecond the reward persencod
    // function updaterewardPerSecond(uint256 _rewardPerSecond) external onlyOwner {
    //     require(block.timestamp < startTimestamp, "YsStakingPool: E04");
    //     rewardPerSecond = _rewardPerSecond;
    //     emit NewrewardPerSecond(_rewardPerSecond);
    // }

    /// @dev get pending reward
    /// @param _user checking for user eoa
    function pendingReward(address _user) internal view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 stakedTokenSupply = IERC20(stakedToken).balanceOf(address(this));

        if (block.timestamp > lastRewardTimestamp && stakedTokenSupply != 0) {
            uint256 multiplier = _getMultiplier(lastRewardTimestamp, block.timestamp);
            uint256 reward = multiplier*rewardPerSecond;
            uint256 adjustedTokenPerShare = accTokenPerShare+(((reward*PRECISION_FACTOR)/stakedTokenSupply));
            return ((user.amount*adjustedTokenPerShare)/PRECISION_FACTOR)-user.rewardDebt;
        } else {
            return ((user.amount*accTokenPerShare)/PRECISION_FACTOR)-user.rewardDebt;
        }
    }

    /// @dev get user state (amount, reward, cumulativereward)
    /// @param _user checking for user eoa
    /// @return amount staking amount
    /// @return rewardDebt reward amount
    /// @return cumulativeRewardDebt cumulativeReward amount
    /// @return endTime staking end time
    function userState(
        address _user
    ) external view returns (
        uint256 amount, 
        uint256 rewardDebt, 
        uint256 cumulativeRewardDebt,
        uint256 endTime
    ){
        UserInfo storage user = userInfo[_user];
       
        amount = user.amount;
        if( amount > 0 ) rewardDebt = pendingReward(_user);

        cumulativeRewardDebt = user.cumulativeRewardDebt;
        endTime = user.endTime;
    }

    /// @dev Update reward variables of the given pool to be up-to-date.
    function _updatePool() internal {
        
        if (block.timestamp <= lastRewardTimestamp) return;

        uint256 stakedTokenSupply = IERC20(stakedToken).balanceOf(address(this));

        if (stakedTokenSupply == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }

        // _getMultiplier(마지막 시간, 현재시간)
        uint256 multiplier = _getMultiplier(lastRewardTimestamp, block.timestamp);
        // 12 * (최소:보정시간, 최대: (현재시간-마지막시간) pool업데이트시간)
        uint256 reward = multiplier*rewardPerSecond;
        // accTokenPerShare + ((reward * 10**12) / (전체 스테이크 토큰양))
        accTokenPerShare = accTokenPerShare+(((reward*PRECISION_FACTOR)/stakedTokenSupply));
        lastRewardTimestamp = block.timestamp;
    }

     /// @dev Return reward multiplier over the given _from to _to block.
     /// @param _from last update time
     /// @param _to now time
    function _getMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        if (_to <= bonusEndTimestamp) { //  현재시간 <= (보상 마지막시간)
            return _to-_from;  //  현재시간-마지막시간뺀차
        } else if (_from >= bonusEndTimestamp) {    // 마지막업데이트시간 >= (보상 마지막시간)
            return 0;
        } else {
            return bonusEndTimestamp-_from;//  (보상 마지막시간) - 마지막시간
        }
    }
}
