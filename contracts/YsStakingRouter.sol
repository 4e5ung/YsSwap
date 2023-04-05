// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import './libraries/YsLibrary.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IYsStakingFactory.sol';
import './interfaces/IYsStakingPool.sol';


import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

contract YsStakingRouter {
    address public immutable factory;
    address public immutable WETH;

    uint32 public deadlineSeconds = 180 seconds;

    event investSingleEvent(address indexed sender, address pool, uint256 amount);
    event investSingleETHEvent(address indexed sender, address pool, uint256 amount);
    event withdrawSingleEvent(address indexed sender, address pool, uint256 liquidity);
    event withdrawSingleETHEvent(address indexed sender, address pool, uint256 liquidity);
    event harvestEvent(address indexed sender, address pool, uint256 reward);


    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'YsStakingRouter: E01');
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    /// @dev checking staking (almost modifier)
    /// @param _pool pool address
    /// @param _liquidity liquidity amount
    function _isStaking(
        address _pool,
        uint _liquidity
    )internal view{
        (uint256 amount,,,) = IYsStakingPool(_pool).userState(msg.sender);
        require( amount > 0, "YsStakingRouter: E02");
        require( amount >= _liquidity, "YsStakingRouter: E03");
    }

    /// @dev user staking state
    /// @param _token staking token address
    /// @param _to confirm user eoa
    /// @return liquidity staking amount
    /// @return reward reward token amount
    /// @return cumulativeReward cumulative reward amount
    /// @return endTime staking end time
    function userInfo( 
        address _token, 
        address _to
    ) external view returns(
        uint256 liquidity, 
        uint256 reward, 
        uint256 cumulativeReward,
        uint256 endTime
    ){
        address pool = IYsStakingFactory(factory).getPool(_token);
        return IYsStakingPool(pool).userState(_to);
    }

    /// @dev staking single token
    /// @param _token staking token address
    /// @param _amountDesired staking token amount
    /// @param _period staking period time
    /// @param _deadline transaction timeout
    function investSingle(
        address _token,
        uint256 _amountDesired,
        uint256 _period,
        uint _deadline
    )external ensure(_deadline){
        address pool = IYsStakingFactory(factory).getPool(_token);

        TransferHelper.safeTransferFrom(_token, msg.sender, address(this), _amountDesired);
        
        uint allowance = IERC20(_token).allowance(address(this), pool);

        if( allowance == 0 )
            IERC20(_token).approve(pool, type(uint256).max);

        uint256 pending = IYsStakingPool(pool).deposit(_amountDesired, msg.sender, _period);
        if( pending > 0 ) TransferHelper.safeTransfer(IYsStakingPool(pool).rewardToken(), msg.sender, pending);

        emit investSingleEvent(msg.sender, pool, _amountDesired);
    }

    /// @dev staking single eth
    /// @param _period staking period time
    /// @param _deadline transaction timeout
    function investSingleETH(
        uint _period,
        uint _deadline
    )external payable ensure(_deadline){
        require( msg.value > 0, "YsStakingRouter: E02");

        address pool = IYsStakingFactory(factory).getPool(WETH);

        IWETH(WETH).deposit{value: msg.value}();

        uint allowance = IERC20(WETH).allowance(address(this), pool);

        if( allowance == 0 )
            IERC20(WETH).approve(pool, type(uint256).max);

        uint256 pending = IYsStakingPool(pool).deposit(msg.value, msg.sender, _period);
        if( pending > 0 ) TransferHelper.safeTransfer(IYsStakingPool(pool).rewardToken(), msg.sender, pending);

        emit investSingleETHEvent(msg.sender, pool, msg.value);
    }

    /// @dev withdraw single token
    /// @param _token unstaking token address
    /// @param _liquidity staking token amount(liquidity)
    /// @param _deadline transaction timeout
    function withdrawSingle( 
        address _token,
        uint256 _liquidity,
        uint _deadline
    ) external ensure(_deadline){
        require(_liquidity > 0, "YsStakingRouter: E04");

        address pool = IYsStakingFactory(factory).getPool(_token);

        _isStaking(pool, _liquidity);

        uint256 pending = IYsStakingPool(pool).withdraw(_liquidity, msg.sender, msg.sender);
        if( pending > 0 ) TransferHelper.safeTransfer(IYsStakingPool(pool).rewardToken(), msg.sender, pending);

        emit withdrawSingleEvent(msg.sender, pool, _liquidity);
    }

    /// @dev witdraw single coin
    /// @param _liquidity staking coin amount(liquidity)
    /// @param _deadline transaction timeout
    function withdrawSingleETH( 
        uint _liquidity,
        uint _deadline
    ) external ensure(_deadline){
        require(_liquidity > 0, "YsStakingRouter: E04");

        address pool = IYsStakingFactory(factory).getPool(WETH);

        _isStaking(pool, _liquidity);

        uint256 pending = IYsStakingPool(pool).withdraw(_liquidity, address(this), msg.sender);
        if( pending > 0 ) TransferHelper.safeTransfer(IYsStakingPool(pool).rewardToken(), msg.sender, pending);

        IWETH(WETH).withdraw(_liquidity);
        TransferHelper.safeTransferETH(msg.sender, _liquidity);

        emit withdrawSingleETHEvent(msg.sender, pool, _liquidity);
    }

    /// @dev receive reward token
    /// @param _token staking token address
    /// @param _deadline transaction timeout
    function harvest( 
        address _token,
        uint _deadline
    ) external ensure(_deadline){
        address pool = IYsStakingFactory(factory).getPool(_token);

        (uint256 amount, uint256 reward,,) = IYsStakingPool(pool).userState(msg.sender);
        require( amount > 0, "YsStakingRouter: E02");
        require( reward > 0, "YsStakingRouter: E05");

        uint256 pending = IYsStakingPool(pool).withdraw(0, msg.sender, msg.sender);
        if( pending > 0 ) TransferHelper.safeTransfer(IYsStakingPool(pool).rewardToken(), msg.sender, pending);

        emit harvestEvent(msg.sender, pool, pending);
    }

    /// @dev get shareOfPool
    /// @param _token staking token address
    /// @param _amountDesired token amount 
    /// @param _owned checking is owned
    /// @return poolRatio pool ratio(99 = 0.99%)
    function getShareOfPool(
        address _token, 
        uint _amountDesired,  
        bool _owned
    )external view returns (uint poolRatio){
        address pool = IYsStakingFactory(factory).getPool(_token);

        uint totalLiquidity = IERC20(_token).balanceOf(address(pool));
        require( totalLiquidity > 0, 'YsStakingRouter: E06');

        uint liquidity = _amountDesired;
        if( _owned ){
            (liquidity,,,) = IYsStakingPool(pool).userState(msg.sender);
        }else{
            totalLiquidity = totalLiquidity+liquidity;
        }

        uint _numerator  = liquidity * (10 ** 5);
        uint _quotient =  ((_numerator / (totalLiquidity)) + 5) / 10;

        if( liquidity > 0 )
            return _quotient >= 10000 ? 10000 : _quotient;
        else
            return 0;
    }
}
