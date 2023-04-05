// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './interfaces/IYsPair.sol';
import './YsERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IYsFactory.sol';
import './interfaces/IYsCallee.sol';

import './libraries/FullMath.sol';

contract YsPair is YsERC20 {
    using UQ112x112 for uint224;

    uint private constant MINIMUM_LIQUIDITY = 10**4;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    address private immutable factory;
    address private immutable router;
    address private immutable token0;
    address private immutable token1;

    uint256 private accTokenPerShare;
    uint256 private bonusEndTimestamp;
    uint256 private startTimestamp;
    uint256 private lastRewardTimestamp;
    uint256 private poolLimitPerUser;
    uint256 private rewardPerSecond;
    uint256 private PRECISION_FACTOR = 10**12;
    address public immutable rewardToken;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint public swapFee = 30;
    uint public protocolFee = 5;
    address public feeTo;

    uint256 private feeGrowthInside0;
    uint256 private feeGrowthInside1;

    mapping(address => UserInfo) private userInfo;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out
    );
    event Sync(uint112 reserve0, uint112 reserve1);


    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided
        uint256 rewardDebt; // Reward debt
        uint256 cumulativeRewardDebt;
        uint256 feeGrowthInside0;
        uint256 feeGrowthInside1;
        uint256 feeCollect0;
        uint256 feeCollect1;
    }
    
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Collect(address indexed user, uint256 amount0, uint amount1);
    
    /// @dev create setting
    /// @param _factory factory contract address
    /// @param _router PairRouter contract address
    /// @param _tokenA pair tokenA address
    /// @param _tokenB pair tokenB address
    /// @param _swapFee swap fee (percent 30 = 0.3)
    /// @param _protocolFee swap fee (percent 30 = 0.3)
    /// @param _rewardToken reward token address
    /// @param _rewardPerSecond reward per sec amount
    /// @param _startTimestamp pair create starttime
    /// @param _bonusEndTimestamp pari reward endtime
    constructor(
        address _factory,
        address _router,        
        address _tokenA, 
        address _tokenB, 
        uint8 _swapFee, 
        uint8 _protocolFee,
        address _rewardToken,
        uint256 _rewardPerSecond,
        uint256 _startTimestamp,
        uint256 _bonusEndTimestamp
    ){       
        require(_tokenA != _tokenB, 'YsPair: E04');
        (address _token0, address _token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        require(_token0 != address(0), 'YsPair: E05');

        token0 = _token0;
        token1 = _token1;
        swapFee = _swapFee;
        protocolFee = _protocolFee;

        rewardToken = _rewardToken;
        rewardPerSecond = _rewardPerSecond;
        startTimestamp = _startTimestamp;
        bonusEndTimestamp = _bonusEndTimestamp;
        lastRewardTimestamp = startTimestamp;

        factory = _factory;
        router = _router;
    }

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'YsPair: E02');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyRouter() {
        require(msg.sender == router, 'YsPair: E01');
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, 'YsPair: E01');
        _;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'YsPair: E04');
    }

    /// @dev update reserves
    /// @param _balance0 update token A balance
    /// @param _balance1 update token B balance
    function _update(uint _balance0, uint _balance1) private {
        require(_balance0 <= type(uint112).max && _balance1 <= type(uint112).max, 'YsPair: E06');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        blockTimestampLast = blockTimestamp;
        reserve0 = uint112(_balance0);
        reserve1 = uint112(_balance1);
        emit Sync(reserve0, reserve1);
    }

    /// @dev if fee is on, mint liquidity equivalent to protocolFee of the growth in sqrt(k)
    /// @param _reserve0 mint reserve0
    /// @param _reserve1 mint reserve1
    /// @param feeOn mint protocol fee cheking
    function _mintFee(
        uint112 _reserve0, 
        uint112 _reserve1
    ) private returns (bool feeOn) {
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0)*uint(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply*(rootK-rootKLast);
                    uint denominator = (rootK*protocolFee)+rootKLast;
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    /// @dev pair token mint (this low-level function should be called from a contract which performs important safety checks)
    /// @param _to mint target eoa
    /// @return liquidity mint result liquidity
    function mint(address _to) internal returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0-_reserve0;
        uint amount1 = balance1-_reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);    // protocolfee(0.05%) 빼고 안빼고
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        
        if (_totalSupply == 0) {
            liquidity = Math.sqrt((amount0*amount1))-MINIMUM_LIQUIDITY;
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min((amount0*_totalSupply) / _reserve0, (amount1*_totalSupply) / _reserve1);
        }

        require(liquidity > 0, 'YsPair: E07');

        _mint(_to, liquidity);

        _update(balance0, balance1);
        if (feeOn) kLast = uint(reserve0)*uint(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(_to, amount0, amount1);
    }

    /// @dev liquidity burn(this low-level function should be called from a contract which performs important safety checks)
    /// @param _to liquidity owner eoa
    /// @param _liquidity liquidity amount
    function burn(
        address _to, 
        uint256 _liquidity
    ) internal returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);

        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = (_liquidity*balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = (_liquidity*balance1) / _totalSupply; // using balances ensures pro-rata distribution

        require(amount0 > 0 && amount1 > 0, 'YsPair: E08');
        _burn(address(this), _liquidity);
        _safeTransfer(_token0, _to, amount0);
        _safeTransfer(_token1, _to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1);
        if (feeOn) kLast = uint(reserve0)*uint(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(_to, amount0, amount1);
    }

    /// @dev get pair token reserves
    /// @return _reserve0 reserve 0
    /// @return _reserve1 reserve 1
    /// @return _blockTimestampLast lp change last time
    function getReserves() public view returns (
        uint112 _reserve0, 
        uint112 _reserve1, 
        uint32 _blockTimestampLast
    ) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /// @dev get token reserves
    /// @param _token token address
    /// @return reserve reserve
    function getReserve(address _token) external view returns(
        uint112 reserve
    ){
        if( _token == token0 ){
            reserve = reserve0;
        }else if( _token == token1 ){
            reserve = reserve1;
        }
    }

        
    
    /// @dev pair token swap(this low-level function should be called from a contract which performs important safety checks)
    /// @param _amount0Out swap token amount0
    /// @param _amount1Out swap token amount1
    /// @param _to swap target eoa
    function swap(
        uint _amount0Out, 
        uint _amount1Out, 
        address _to
    ) external lock {
        require(_amount0Out > 0 || _amount1Out > 0, 'YsPair: E09');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(_amount0Out < _reserve0 && _amount1Out < _reserve1, 'YsPair: E10');

        uint balance0;
        uint balance1;
        address _token0 = token0;
        address _token1 = token1;
        { 
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            require(_to != _token0 && _to != _token1, 'YsPair: E11');
            if (_amount0Out > 0) _safeTransfer(_token0, _to, _amount0Out); // optimistically transfer tokens
            if (_amount1Out > 0) _safeTransfer(_token1, _to, _amount1Out); // optimistically transfer tokens
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - _amount0Out ? balance0 - (_reserve0 - _amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - _amount1Out ? balance1 - (_reserve1 - _amount1Out) : 0;

        require(amount0In > 0 || amount1In > 0, 'YsPair: E12');
        { 
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint balance0Adjusted = (balance0*10000)-(amount0In*swapFee);
            uint balance1Adjusted = (balance1*10000)-(amount1In*swapFee);
            require((balance0Adjusted*balance1Adjusted) >= (uint(_reserve0)*uint(_reserve1))*(10000**2), 'YsPair: E03');
        }
            
        if( amount0In > 0 )  {
            uint feeInside0 = (amount0In*swapFee)/10000;
            feeGrowthInside0 += (((amount0In*swapFee) / 10000)*Q128)/totalSupply;
            _safeTransfer(_token0, router, feeInside0);
            balance0 -= feeInside0;
        }

        if( amount1In > 0 )  {
             uint feeInside1 = (amount1In*swapFee)/10000;
            feeGrowthInside1 += (((amount1In*swapFee) / 10000)*Q128)/totalSupply;
            _safeTransfer(_token1, router, feeInside1);
            balance1 -= feeInside1;
        }        

        _update(balance0, balance1);
        emit Swap(_to, amount0In, amount1In, _amount0Out, _amount1Out);
    }

    /// @dev force balances to match reserves(not use)
    /// @param _to target eoa
    function skim(address _to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, _to, IERC20(_token0).balanceOf(address(this))-reserve0);
        _safeTransfer(_token1, _to, IERC20(_token1).balanceOf(address(this))-reserve1);
    }

    /// @dev force reserves to match balances(not use)
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }

    /// @dev change feeto eoa
    /// @param _newFeeTo feeto target eoa
    function updateFeeTo(address _newFeeTo) external onlyFactory {
        feeTo = _newFeeTo;
    }

    /// @dev change swapfee
    /// @param _newFee fee amount(30 = 0.3% max 100)
    function updateSwapFee(uint8 _newFee) external onlyFactory {
        swapFee = _newFee;
    }

    /// @dev change protocolfee
    /// @param _newFee fee amount(5 = 0.05% max 100)
    function updateProtocolFee(uint8 _newFee) external onlyFactory {
        protocolFee = _newFee;
    }

    /// @dev swap fee sync
    /// @param _liquidity liquidity amount
    /// @param _from target eoa
    function _feeSync(
        uint256 _liquidity, 
        address _from
    ) internal {
        UserInfo storage user = userInfo[_from];
        
        (uint256 collect0, uint256 collect1) = _getCollect(_liquidity, _from);
        
        uint256 _feeGrowthInside0 = feeGrowthInside0;
        uint256 _feeGrowthInside1 = feeGrowthInside1;

        user.feeCollect0 += collect0;
        user.feeGrowthInside0 = _feeGrowthInside0;

        user.feeCollect1 += collect1;
        user.feeGrowthInside1 = _feeGrowthInside1;
    }


    /// @dev get collect pair amount
    /// @param _liquidity liquidity amount
    /// @param _from target eoa
    /// @return feeCollect0 token A swap fee collect  
    /// @return feeCollect1 token B swap fee collect
    function _getCollect(
        uint256 _liquidity, 
        address _from
    ) internal view returns(uint256 feeCollect0, uint256 feeCollect1){
        UserInfo storage user = userInfo[_from];

        uint _feeGrowthInside0 = feeGrowthInside0;
        uint _feeGrowthInside1 = feeGrowthInside1;
        
        if( user.feeGrowthInside0 < _feeGrowthInside0 ){
            feeCollect0 = (_liquidity*(_feeGrowthInside0-user.feeGrowthInside0)/Q128);
        }
        
        if( user.feeGrowthInside1 < feeGrowthInside1 ){
            feeCollect1 = (_liquidity*(_feeGrowthInside1-user.feeGrowthInside1)/Q128);
        }
    }

    /// @dev swap fee receive
    /// @param _from receive target eoa
    /// @return feeCollect0 token A swap fee collect  
    /// @return feeCollect1 token B swap fee collect
    function collect(address _from) external lock onlyRouter returns(uint256 feeCollect0, uint256 feeCollect1){
        UserInfo storage user = userInfo[_from];

        _feeSync(user.amount, _from);

        address _token0 = token0;
        address _token1 = token1;

        feeCollect0 = user.feeCollect0;
        feeCollect1 = user.feeCollect1;

        _update(IERC20(_token0).balanceOf(address(this))-feeCollect0, IERC20(_token1).balanceOf(address(this))-feeCollect1);

        bool feeOn = feeTo != address(0);
        if (feeOn) kLast = uint(reserve0)*uint(reserve1); // reserve0 and reserve1 are up-to-date

        user.feeCollect0 = 0;
        user.feeCollect1 = 0;

        emit Collect(_from, feeCollect0, feeCollect1);
    } 

    /// @dev pair token deposit 
    /// @param _from target eoa
    function deposit(address _from) external lock onlyRouter returns(uint256 pending){
        UserInfo storage user = userInfo[_from];

        uint _accTokenPerShare = accTokenPerShare;

        _updatePool();

        if (user.amount > 0) {
            // ((기존 개인 스테이킹 한 양 * 공유Token) / 10**12) - rewardDebt
            pending = ((user.amount*_accTokenPerShare)/(PRECISION_FACTOR))-user.rewardDebt;
            // if (pending > 0) {
            //     address _rewardToken = rewardToken;
            //     _safeTransfer(_rewardToken, address(_from), pending);
            // }
        }

        uint256 liquidity = mint(address(this));

        _feeSync(user.amount, _from);

        user.amount = user.amount+liquidity;

        // (개인 스테이킹 양 * 공유Token) / 10**12
        user.rewardDebt = (user.amount*_accTokenPerShare)/PRECISION_FACTOR;

        emit Deposit(_from, liquidity);
    }

    /// @dev pair token withdraw 
    /// @param _liquidity liquidity token amount 
    /// @param _burnFrom burn eoa (case1. weth=owner(router), case2 token=owner(eoa))
    /// @param _owner token owner
    /// @return amount0 token A amount
    /// @return amount1 token B amount
    /// @return pending reward token
    function withdraw(
        uint256 _liquidity, 
        address _burnFrom, 
        address _owner
    ) external lock onlyRouter returns (uint amount0, uint amount1, uint pending ){
        UserInfo storage user = userInfo[_owner];

        _updatePool();

        // ((기존 개인 스테이킹 한 양 * accTokenPerShare) / 10**12) - rewardDebt
        pending = ((user.amount*accTokenPerShare)/PRECISION_FACTOR)-user.rewardDebt;

        if (_liquidity > 0) {
           user.amount = user.amount-_liquidity;
            // 요청한 개인 스테이킹 양만큼 제거
            // _safeTransfer(address(this), address(_from), _amount);
            (amount0, amount1) = burn(_burnFrom, _liquidity);
        }

        if (pending > 0) {
            // pending 금액만큼 Reward
            // _safeTransfer(rewardToken, address(_from), pending);
            user.cumulativeRewardDebt += pending;
        }

        // (개인 스테이킹 양 * accTokenPerShare) / 10**12
        user.rewardDebt = (user.amount*accTokenPerShare)/PRECISION_FACTOR;

        if( user.amount == 0 )
            user.cumulativeRewardDebt = 0;

        emit Withdraw(_owner, _liquidity);
    }

    /// @dev user staking state
    /// @param _owner target eoa
    /// @return amount  liquidity amount
    /// @return rewardDebt reward token amount
    /// @return cumulativeRewardDebt cumulative reward amount
    /// @return feeCollect0 swap fee amount
    /// @return feeCollect1 swap fee amount
    function userState(
        address _owner
    ) external view returns (
        uint256 amount,
        uint256 rewardDebt,
        uint256 cumulativeRewardDebt,
        uint256 feeCollect0,
        uint256 feeCollect1
    ){
        UserInfo storage user = userInfo[_owner];

        amount = user.amount;
        if( amount > 0 ){            
            uint256 stakedTokenSupply = IERC20(address(this)).balanceOf(address(this));

            if (block.timestamp > lastRewardTimestamp && stakedTokenSupply != 0) {
                uint256 reward = _getMultiplier(lastRewardTimestamp, block.timestamp)*rewardPerSecond;
                uint256 adjustedTokenPerShare = accTokenPerShare+(((reward*PRECISION_FACTOR)/stakedTokenSupply));
                rewardDebt = ((user.amount*adjustedTokenPerShare)/PRECISION_FACTOR)-user.rewardDebt;
            } else {
                rewardDebt = ((user.amount*accTokenPerShare)/PRECISION_FACTOR)-user.rewardDebt;
            }
            
            cumulativeRewardDebt = user.cumulativeRewardDebt;

            (feeCollect0, feeCollect1) = _getCollect(user.amount, _owner);
        }
    }

    /// @dev update lp pool(reward)
    function _updatePool() internal {        
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }

        uint256 stakedTokenSupply = IERC20(address(this)).balanceOf(address(this));

        if (stakedTokenSupply == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }

        // 12 * (최소:보정시간, 최대: (현재시간-마지막시간) pool업데이트시간)
        uint256 reward = _getMultiplier(lastRewardTimestamp, block.timestamp)*rewardPerSecond;
        // accTokenPerShare + ((reward * 10**12) / (전체 스테이크 토큰양))
        accTokenPerShare = accTokenPerShare+(((reward*PRECISION_FACTOR)/stakedTokenSupply));
        lastRewardTimestamp = block.timestamp;
    }

    /// @dev Return reward multiplier over the given _from to _to block.
    /// @param _from block to start(last update time)
    /// @param _to block to finsish (time now)
    function _getMultiplier(
        uint256 _from, 
        uint256 _to
    ) internal view returns (uint256) {
        if (_to <= bonusEndTimestamp) { //  현재시간 <= (보상 마지막시간)
            return _to-_from;  //  현재시간-마지막시간뺀차
        } else if (_from >= bonusEndTimestamp) {    // 마지막업데이트시간 >= (보상 마지막시간)
            return 0;
        } else {
            return bonusEndTimestamp-_from;//  (보상 마지막시간) - 마지막시간
        }
    }
}
