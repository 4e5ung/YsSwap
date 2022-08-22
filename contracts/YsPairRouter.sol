// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './libraries/YsLibrary.sol';
import './libraries/TransferHelper.sol';
import './libraries/Math.sol';

import './interfaces/IYsFactory.sol';

import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

contract YsPairRouter {
    address public factory;
    address public WETH;

    uint256 maxPriceImpact = 500;   //  5.00%

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'YsPairRouter: E01');
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal view virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        require(IYsFactory(factory).getPair(tokenA, tokenB) != address(0), 'YsPairRouter: E02');

        (uint reserveA, uint reserveB) = YsLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = YsLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'YsPairRouter: E04');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = YsLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'YsPairRouter: E03');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _isStaking(
        address pair,
        uint liquidity
    )internal view{
        (uint256 amount,,,, ) = IYsPair(pair).userState(msg.sender);
        require( amount > 0, "YsPairRouter: E05");
        require( amount >= liquidity, "YsPairRouter: E06");
    }

    function userInfo( 
        address tokenA, 
        address tokenB,
        address to
    ) external view returns(uint256 liquidity, uint256 reward, uint256 cumulativeReward, uint256 feeCollect0, uint256 feeCollect1){
        address pair = YsLibrary.pairFor(factory, tokenA, tokenB);
        
        uint256 _feeCollect0;
        uint256 _feeCollect1;
        (liquidity, reward, cumulativeReward, _feeCollect0, _feeCollect1) = IYsPair(pair).userState(to);

        (address token0, ) = YsLibrary.sortTokens(tokenA, tokenB);
        (feeCollect0, feeCollect1) = tokenA == token0 ? (_feeCollect0, _feeCollect1) : (_feeCollect1, _feeCollect0);
    }

    // LP+Staking
    function investPair(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired, 
        uint256 amountAMin, 
        uint256 amountBMin,
        uint deadline
    )external ensure(deadline){        
        (uint amountA, uint amountB) = _addLiquidity(
            tokenA, 
            tokenB, 
            amountADesired, 
            amountBDesired, 
            amountAMin, 
            amountBMin
        );

        address pair = YsLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        IYsPair(pair).deposit(msg.sender);
    }

    // LP+Staking ETH
    function investPairETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    )external payable ensure(deadline){
        (uint amountToken, uint amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );

        address pair = YsLibrary.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));

        IYsPair(pair).deposit(msg.sender);

        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    function withdrawPair( 
        address tokenA,
        address tokenB,
        uint256 liquidity, 
        uint256 amountAMin, 
        uint256 amountBMin,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB) {
        require(liquidity > 0, "YsPairRouter: E07");

        address pair = YsLibrary.pairFor(factory, tokenA, tokenB);
        
        _isStaking(pair, liquidity);

        collect(tokenA, tokenB, deadline);

        (uint amount0, uint amount1, uint pending ) = IYsPair(pair).withdraw(liquidity, msg.sender, msg.sender);

        if( pending > 0 ){
            TransferHelper.safeTransfer(IYsPair(pair).rewardToken(), msg.sender, pending);
        }

        (address token0, ) = YsLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'YsPairRouter: E03');
        require(amountB >= amountBMin, 'YsPairRouter: E04');
    }

    function withdrawPairETH( 
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    ) external ensure(deadline){
        require(liquidity > 0, "YsPairRouter: E07");

        address pair = YsLibrary.pairFor(factory, token, WETH);

        _isStaking(pair, liquidity);

        collect(token, WETH, deadline);

        (uint amount0, uint amount1, uint pending) = IYsPair(pair).withdraw(liquidity, address(this), msg.sender);

        if( pending > 0 ){
            TransferHelper.safeTransfer(IYsPair(pair).rewardToken(), msg.sender, pending);
        }

        (address token0, ) = YsLibrary.sortTokens(token, WETH);
        (uint amountToken, uint amountETH) = token == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountToken >= amountTokenMin, 'YsPairRouter: E03');
        require(amountETH >= amountETHMin, 'YsPairRouter: E04');

        TransferHelper.safeTransfer(token, msg.sender, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(msg.sender, amountETH);
    }


    function harvest( 
        address tokenA,
        address tokenB,
        uint deadline
    ) external ensure(deadline){
        address pair = YsLibrary.pairFor(factory, tokenA, tokenB);

        (uint256 amount, uint256 reward,,,) = IYsPair(pair).userState(msg.sender);
        require( amount > 0, "YsPairRouter: E05");
        require( reward > 0, "YsPairRouter: E08");

        (,,uint pending) = IYsPair(pair).withdraw(0, msg.sender, msg.sender);

        if( pending > 0 ){
            TransferHelper.safeTransfer(IYsPair(pair).rewardToken(), msg.sender, pending);
        }
    }

    function collect(
        address tokenA,
        address tokenB,
        uint deadline
    ) public ensure(deadline) returns(uint256 collect0, uint256 collect1){
        address pair = YsLibrary.pairFor(factory, tokenA, tokenB);
        (collect0, collect1) = IYsPair(pair).collect(msg.sender);

        (address token0, address token1) = YsLibrary.sortTokens(tokenA, tokenB);
        if( collect0 > 0 ) TransferHelper.safeTransfer(token0, msg.sender, collect0);
        if( collect1 > 0 ) TransferHelper.safeTransfer(token1, msg.sender, collect1);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual returns (uint amountB) {
        return YsLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint8 swapFee)
        public
        view
        virtual
        returns (uint amountOut)
    {
        return YsLibrary.getAmountOut(amountIn, reserveIn, reserveOut, swapFee);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, uint8 swapFee)
        public
        view
        virtual
        returns (uint amountIn)
    {
        return YsLibrary.getAmountIn(amountOut, reserveIn, reserveOut, swapFee);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        returns (uint[] memory amounts)
    {
        return YsLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        returns (uint[] memory amounts)
    {
        return YsLibrary.getAmountsIn(factory, amountOut, path);
    }

    function getShareOfPool(
        address tokenA, 
        address tokenB, 
        uint amountADesired, 
        uint amountBDesired, 
        bool owned
    )external view returns (uint poolRatio){
        address pair = YsLibrary.pairFor(factory, tokenA, tokenB);
        uint totalLiquidity = IYsPair(pair).totalSupply();
        require( totalLiquidity > 0, 'YsPairRouter: E09');

        uint liquidity;

        if( owned ){
            (liquidity,,,, ) = IYsPair(pair).userState(msg.sender);
        }else{
            (uint amountA, uint amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, 0, 0);
            (uint amount0, uint amount1) = tokenA < tokenB ? (amountA, amountB) : (amountB, amountA);
            (uint112 _reserve0, uint112 _reserve1,) = IYsPair(pair).getReserves(); // gas savings
            liquidity = Math.min((amount0*totalLiquidity) / _reserve0, (amount1*totalLiquidity) / _reserve1);
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
