// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './access/Ownable.sol';
import "./security/ReentrancyGuard.sol";

import './libraries/TransferHelper.sol';
import './libraries/YsLibrary.sol';

import './interfaces/IYsStakingPool.sol';

import "./interfaces/IERC20.sol";

contract YsStakingPool is Ownable, ReentrancyGuard {

    address private stakeFactory;
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

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => UserInfo) public userInfo;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 cumulativeRewardDebt;
        uint256 endTime;
    }

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event NewStartAndEndBlocks(uint256 startTimestamp, uint256 endBlock);
    event NewrewardPerSecond(uint256 rewardPerSecond);
    // event NewPoolLimit(uint256 poolLimitPerUser);
    event RewardsStop(uint256 blockNumber);
    event Withdraw(address indexed user, uint256 amount);

    constructor() {
        stakeFactory = msg.sender;
    }

    /*
     * @notice Initialize the contract
     * @param _stakedToken: staked token address
     * @param _rewardToken: reward token address
     * @param _rewardPerSecond: reward per block (in rewardToken)
     * @param _startTimestamp: start block
     * @param _bonusEndTimestamp: end block
     * @param _poolLimitPerUser: pool limit per user in stakedToken (if any, else 0)
     * @param _admin: admin address with ownership
     */
    function initialize(
        address _router,
        address _stakedToken,
        address _rewardToken,
        uint256 _rewardPerSecond,
        uint256 _startTimestamp,
        uint256 _bonusEndTimestamp,
        address _admin
    ) external {
        require(msg.sender == stakeFactory, "YsStakingPool: FORBIDDEN");

        stakedToken = _stakedToken;
        rewardToken = _rewardToken;
        rewardPerSecond = _rewardPerSecond;
        startTimestamp = _startTimestamp;
        bonusEndTimestamp = _bonusEndTimestamp;

        lastRewardTimestamp = startTimestamp;
        router = _router;

        transferOwnership(_admin);
    }

    /*
     * @notice Deposit staked tokens and collect reward tokens (if any)
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function deposit(uint256 _amount, address _from, uint256 _period) external nonReentrant  {
        require(msg.sender == router, 'YsStakingPool: FORBIDDEN'); // sufficient check

        UserInfo storage user = userInfo[_from];

        _updatePool();

        if (user.amount > 0) {
            // ((기존 개인 스테이킹 한 양 * 공유Token) / 10**12) - rewardDebt
            uint256 pending = ((user.amount*accTokenPerShare)/(PRECISION_FACTOR))-user.rewardDebt;
            if (pending > 0) {
                // rewardToken.safeTransfer(address(msg.sender), pending);
               TransferHelper.safeTransfer(rewardToken, address(_from), pending);
            }
        }

        if (_amount > 0) {
            // 기존 개인 스테이킹 양에 추가 개인 스테이킹
            user.amount = user.amount+_amount;            
            TransferHelper.safeTransferFrom(stakedToken, msg.sender, address(this), _amount);
        }

        // (개인 스테이킹 양 * 공유Token) / 10**12
        user.rewardDebt = (user.amount*accTokenPerShare)/PRECISION_FACTOR;
        user.endTime = block.timestamp + _period;

        emit Deposit(_from, _amount);
    }

    /*
     * @notice Withdraw staked tokens and collect reward tokens
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function withdraw(uint256 _amount, address _burnFrom, address _from) external nonReentrant returns(uint256 pending){
        require(msg.sender == router, 'YsStakingPool: FORBIDDEN'); // sufficient check

        UserInfo storage user = userInfo[_from];
        
        _updatePool();

        // ((기존 개인 스테이킹 한 양 * accTokenPerShare) / 10**12) - rewardDebt
        pending = ((user.amount*accTokenPerShare)/PRECISION_FACTOR)-user.rewardDebt;

        if (_amount > 0) {
            require( user.endTime <= block.timestamp, 'YsStakingPool: TIMELOCK');

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

        emit Withdraw(_from, _amount);
    }

    /*
     * @notice Withdraw staked tokens without caring about rewards rewards
     * @dev Needs to be for emergency.
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amountToTransfer = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        if (amountToTransfer > 0) {
            // stakedToken.safeTransfer(address(msg.sender), amountToTransfer);
            TransferHelper.safeTransfer(stakedToken, address(msg.sender), amountToTransfer);
        }

        emit EmergencyWithdraw(msg.sender, user.amount);
    }

    /*
     * @notice Stop rewards
     * @dev Only callable by owner. Needs to be for emergency.
     */
    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
        // rewardToken.safeTransfer(address(msg.sender), _amount);
        TransferHelper.safeTransfer(rewardToken, address(msg.sender), _amount);
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of tokens to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(stakedToken), "YsStakingPool: INVALID_ADDRESS");
        require(_tokenAddress != address(rewardToken), "YsStakingPool: INVALID_ADDRESS");

        // _tokenAddress.safeTransfer(address(msg.sender), _tokenAmount);
        TransferHelper.safeTransfer(_tokenAddress, address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /*
     * @notice Stop rewards
     * @dev Only callable by owner
     */
    function stopReward() external onlyOwner {
        bonusEndTimestamp = block.timestamp;
    }

    /*
     * @notice Update reward per block
     * @dev Only callable by owner.
     * @param _rewardPerSecond: the reward per block
     */
    function updaterewardPerSecond(uint256 _rewardPerSecond) external onlyOwner {
        require(block.timestamp < startTimestamp, "YsStakingPool: POOL_STARTED");
        rewardPerSecond = _rewardPerSecond;
        emit NewrewardPerSecond(_rewardPerSecond);
    }

    /**
     * @notice It allows the admin to update start and end blocks
     * @dev This function is only callable by owner.
     * @param _startTimestamp: the new start block
     * @param _bonusEndTimestamp: the new end block
     */
    function updateStartAndEndBlocks(uint256 _startTimestamp, uint256 _bonusEndTimestamp) external onlyOwner {
        require(block.timestamp < startTimestamp, "YsStakingPool: POOL_STARTED");
        require(_startTimestamp < _bonusEndTimestamp, "YsStakingPool: STARTTIME_BOUNUSTIME");
        require(block.timestamp < _startTimestamp, "YsStakingPool: CURRENTTIME_STARTTIME");

        startTimestamp = _startTimestamp;
        bonusEndTimestamp = _bonusEndTimestamp;

        // Set the lastRewardTimestamp as the startTimestamp
        lastRewardTimestamp = startTimestamp;

        emit NewStartAndEndBlocks(_startTimestamp, _bonusEndTimestamp);
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
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

    function userState( address _user ) external view returns (uint256 amount, uint256 rewardDebt, uint256 cumulativeRewardDebt){
        UserInfo storage user = userInfo[_user];
        
        amount = user.amount;

        if( amount > 0 )
            rewardDebt = pendingReward(_user);

        cumulativeRewardDebt = user.cumulativeRewardDebt;
    }

    /*
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() internal {
        
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }

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

    /*
     * @notice Return reward multiplier over the given _from to _to block.
     * @param _from: block to start (마지막 update시간)
     * @param _to: block to finish  (현재시간)
     */
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
