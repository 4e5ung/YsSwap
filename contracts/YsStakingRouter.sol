// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import './libraries/YsLibrary.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IYsStakingFactory.sol';
import './interfaces/IYsStakingPool.sol';


import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

contract YsStakingRouter {
    address public factory;
    address public WETH;

    uint256 maxPriceImpact = 500;   //  5.00%

    uint32 public deadlineSeconds = 180 seconds;

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

    function _isStaking(
        address pool,
        uint liquidity
    )internal view{
        (uint256 amount,, ) = IYsStakingPool(pool).userState(msg.sender);
        require( amount > 0, "YsStakingRouter: E02");
        require( amount >= liquidity, "YsStakingRouter: E03");
    }


    function userInfo( 
        address token, 
        address to
    ) external view returns(uint256, uint256, uint256){
        address pool = IYsStakingFactory(factory).getPool(token);
        return IYsStakingPool(pool).userState(to);
    }

    function investSingle(
        address token,
        uint256 amountDesired,
        uint256 period,
        uint deadline
    )external ensure(deadline){
        address pool = IYsStakingFactory(factory).getPool(token);

        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amountDesired);
        
        uint allowance = IERC20(token).allowance(address(this), pool);

        if( allowance == 0 )
            IERC20(token).approve(pool, type(uint256).max);

        IYsStakingPool(pool).deposit(amountDesired, msg.sender, period);
    }

    function investSingleETH(
        uint period,
        uint deadline
    )external payable ensure(deadline){
        require( msg.value > 0, "YsStakingRouter: E02");

        address pool = IYsStakingFactory(factory).getPool(WETH);

        IWETH(WETH).deposit{value: msg.value}();

        uint allowance = IERC20(WETH).allowance(address(this), pool);

        if( allowance == 0 )
            IERC20(WETH).approve(pool, type(uint256).max);

        IYsStakingPool(pool).deposit(msg.value, msg.sender, period);
    }

    function withdrawSingle( 
        address token,
        uint256 liquidity,
        uint deadline
    ) external ensure(deadline){
        require(liquidity > 0, "YsStakingRouter: E04");

        address pool = IYsStakingFactory(factory).getPool(token);

        _isStaking(pool, liquidity);

        uint256 pending = IYsStakingPool(pool).withdraw(liquidity, msg.sender, msg.sender);

        if( pending > 0 )
            TransferHelper.safeTransfer(IYsStakingPool(pool).rewardToken(), msg.sender, pending);
    }

    function withdrawSingleETH( 
        uint liquidity,
        uint deadline
    ) external ensure(deadline){
        require(liquidity > 0, "YsStakingRouter: E04");

        address pool = IYsStakingFactory(factory).getPool(WETH);

        _isStaking(pool, liquidity);

        uint256 pending = IYsStakingPool(pool).withdraw(liquidity, address(this), msg.sender);

        if( pending > 0 )
            TransferHelper.safeTransfer(IYsStakingPool(pool).rewardToken(), msg.sender, pending);

        IWETH(WETH).withdraw(liquidity);
        TransferHelper.safeTransferETH(msg.sender, liquidity);
    }


    function harvest( 
        address token,
        uint deadline
    ) external ensure(deadline){
        address pool = IYsStakingFactory(factory).getPool(token);

        (uint256 amount, uint256 reward,) = IYsStakingPool(pool).userState(msg.sender);
        require( amount > 0, "YsStakingRouter: E02");
        require( reward > 0, "YsStakingRouter: E05");

        uint256 pending = IYsStakingPool(pool).withdraw(0, msg.sender, msg.sender);

        if( pending > 0 )
            TransferHelper.safeTransfer(IYsStakingPool(pool).rewardToken(), msg.sender, pending);
    }

    function getShareOfPool(
        address token, 
        uint amountDesired,  
        bool owned
    )external view returns (uint poolRatio){
        address pool = IYsStakingFactory(factory).getPool(token);

        uint totalLiquidity = IERC20(token).balanceOf(address(pool));
        require( totalLiquidity > 0, 'YsStakingRouter: E06');

        uint liquidity = amountDesired;
        if( owned ){
            (liquidity,, ) = IYsStakingPool(pool).userState(msg.sender);
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
