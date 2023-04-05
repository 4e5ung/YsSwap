// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './libraries/YsLibrary.sol';
import './libraries/TransferHelper.sol';
import './libraries/Math.sol';

import './interfaces/IYsFactory.sol';

import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

contract YsPairRouter {
    address public immutable factory;
    address public immutable WETH;

    event investPairEvent(address indexed sender, address pair, uint256 amountA, uint256 amountB);
    event investPairETHEvent(address indexed sender, address pair, uint256 amount);
    event withdrawPairEvent(address indexed sender, address pair, uint256 liquidity);
    event withdrawPairETHEvent(address indexed sender, address pair, uint256 liquidity);
    event harvestEvent(address indexed sender, address pair, uint256 reward);
    event collectEvent(address indexed sender, address pair, uint256 collectA, uint256 collectB);

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'YsPairRouter: E01');
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        // only accept ETH via fallback from the WETH contract
        assert(msg.sender == WETH); 
    }

     /// @dev add Liquidity
    /// @param _tokenA  staking token A address
    /// @param _tokenB  staking token B address
    /// @param _amountADesired staking token a amount
    /// @param _amountBDesired staking token b amount
    /// @param _amountAMin staking token a min amount
    /// @param _amountBMin staking token b min amount
    /// @return amountA staking token A amount
    /// @return amountB staking token B amount
    function _addLiquidity(
        address _tokenA,
        address _tokenB,
        uint _amountADesired,
        uint _amountBDesired,
        uint _amountAMin,
        uint _amountBMin
    ) internal view virtual returns (uint amountA, uint amountB) {
        require(IYsFactory(factory).getPair(_tokenA, _tokenB) != address(0), 'YsPairRouter: E02');

        (uint reserveA, uint reserveB) = YsLibrary.getReserves(factory, _tokenA, _tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (_amountADesired, _amountBDesired);
        } else {
            uint amountBOptimal = YsLibrary.quote(_amountADesired, reserveA, reserveB);
            if (amountBOptimal <= _amountBDesired) {
                require(amountBOptimal >= _amountBMin, 'YsPairRouter: E04');
                (amountA, amountB) = (_amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = YsLibrary.quote(_amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= _amountADesired);
                require(amountAOptimal >= _amountAMin, 'YsPairRouter: E03');
                (amountA, amountB) = (amountAOptimal, _amountBDesired);
            }
        }
    }

    /// @dev staking error checking(almost modifier)
    /// @param _pair pair Contract address
    /// @param _liquidity checking liquidity amount
    function _isStaking(
        address _pair,
        uint _liquidity
    )internal view{
        (uint256 amount,,,, ) = IYsPair(_pair).userState(msg.sender);
        require( amount > 0, "YsPairRouter: E05");
        require( amount >= _liquidity, "YsPairRouter: E06");
    }

    /// @dev staking in userinfo
    /// @param _tokenA staking token A address
    /// @param _tokenB staking token B address
    /// @param _to confirm userinfo for eoa
    /// @return liquidity staking amount
    /// @return reward reward token amount
    /// @return cumulativeReward cumulative reward token
    /// @return feeCollect0 token A swapfee
    /// @return feeCollect1 token B swapfee
    function userInfo( 
        address _tokenA, 
        address _tokenB,
        address _to
    ) external view returns(
        uint256 liquidity, 
        uint256 reward, 
        uint256 cumulativeReward, 
        uint256 feeCollect0,
        uint256 feeCollect1
    ){
        address pair = YsLibrary.pairFor(factory, _tokenA, _tokenB);
        
        uint256 _feeCollect0;
        uint256 _feeCollect1;
        (liquidity, reward, cumulativeReward, _feeCollect0, _feeCollect1) = IYsPair(pair).userState(_to);

        (address token0, ) = YsLibrary.sortTokens(_tokenA, _tokenB);
        (feeCollect0, feeCollect1) = _tokenA == token0 ? (_feeCollect0, _feeCollect1) : (_feeCollect1, _feeCollect0);
    }

    /// @dev Token+Token LP+Staking 
    /// @param _tokenA  staking token A address
    /// @param _tokenB  staking token B address
    /// @param _amountADesired staking token a amount
    /// @param _amountBDesired staking token b amount
    /// @param _amountAMin staking token a min amount(slippage)
    /// @param _amountBMin staking token b min amount(slippage)
    /// @param _deadline transaction timeout
    function investPair(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired, 
        uint256 _amountAMin, 
        uint256 _amountBMin,
        uint _deadline
    )external ensure(_deadline){        
        (uint amountA, uint amountB) = _addLiquidity(
            _tokenA, 
            _tokenB, 
            _amountADesired, 
            _amountBDesired, 
            _amountAMin, 
            _amountBMin
        );

        address pair = YsLibrary.pairFor(factory, _tokenA, _tokenB);
        TransferHelper.safeTransferFrom(_tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(_tokenB, msg.sender, pair, amountB);

        uint256 pending = IYsPair(pair).deposit(msg.sender);
        if( pending > 0 ) TransferHelper.safeTransfer(IYsPair(pair).rewardToken(), msg.sender, pending);

        emit investPairEvent(msg.sender, pair, _amountADesired, _amountBDesired);
    }

    /// @dev Token+ETH LP+Staking 
    /// @param _token  staking token address
    /// @param _amountTokenDesired staking token amount
    /// @param _amountTokenMin staking token min amount(slippage)
    /// @param _amountETHMin staking ETH min amount(slippage)
    /// @param _deadline transaction timeout
    function investPairETH(
        address _token,
        uint _amountTokenDesired,
        uint _amountTokenMin,
        uint _amountETHMin,
        uint _deadline
    )external payable ensure(_deadline){
        (uint amountToken, uint amountETH) = _addLiquidity(
            _token,
            WETH,
            _amountTokenDesired,
            msg.value,
            _amountTokenMin,
            _amountETHMin
        );

        address pair = YsLibrary.pairFor(factory, _token, WETH);
        TransferHelper.safeTransferFrom(_token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));

        uint256 pending = IYsPair(pair).deposit(msg.sender);
        if( pending > 0 ) TransferHelper.safeTransfer(IYsPair(pair).rewardToken(), msg.sender, pending);

        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);


        emit investPairETHEvent(msg.sender, pair, _amountTokenDesired);
    }

    /// @dev Token+Token UnStaking
    /// @param _tokenA  unstaking token A address
    /// @param _tokenB  unstaking token B address
    /// @param _liquidity unstaking liquidity amount
    /// @param _amountAMin unstaking token a min amount(slippage)
    /// @param _amountBMin unstaking token b min amount(slippage)
    /// @param _deadline transaction timeout
    function withdrawPair( 
        address _tokenA,
        address _tokenB,
        uint256 _liquidity, 
        uint256 _amountAMin, 
        uint256 _amountBMin,
        uint _deadline
    ) external ensure(_deadline) returns (uint amountA, uint amountB){
        require(_liquidity > 0, "YsPairRouter: E07");

        address pair = YsLibrary.pairFor(factory, _tokenA, _tokenB);
        
        _isStaking(pair, _liquidity);

        collect(_tokenA, _tokenB, _deadline);

        (uint amount0, uint amount1, uint pending ) = IYsPair(pair).withdraw(_liquidity, msg.sender, msg.sender);

        if( pending > 0 ) TransferHelper.safeTransfer(IYsPair(pair).rewardToken(), msg.sender, pending);
        

        (address token0, ) = YsLibrary.sortTokens(_tokenA, _tokenB);
        (amountA, amountB) = _tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= _amountAMin, 'YsPairRouter: E03');
        require(amountB >= _amountBMin, 'YsPairRouter: E04');

        emit withdrawPairEvent(msg.sender, pair, _liquidity);
    }

    /// @dev Token+ETH UnStaking
    /// @param _token  unstaking token address
    /// @param _liquidity unstaking liquidity amount
    /// @param _amountTokenMin unstaking token min amount(slippage)
    /// @param _amountETHMin unstaking token eth min amount(slippage)
    /// @param _deadline transaction timeout
    function withdrawPairETH( 
        address _token,
        uint _liquidity,
        uint _amountTokenMin,
        uint _amountETHMin,
        uint _deadline
    ) external ensure(_deadline){
        require(_liquidity > 0, "YsPairRouter: E07");

        address pair = YsLibrary.pairFor(factory, _token, WETH);

        _isStaking(pair, _liquidity);

        collect(_token, WETH, _deadline);

        (uint amount0, uint amount1, uint pending) = IYsPair(pair).withdraw(_liquidity, address(this), msg.sender);
        if( pending > 0 ) TransferHelper.safeTransfer(IYsPair(pair).rewardToken(), msg.sender, pending);
        

        (address token0, ) = YsLibrary.sortTokens(_token, WETH);
        (uint amountToken, uint amountETH) = _token == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountToken >= _amountTokenMin, 'YsPairRouter: E03');
        require(amountETH >= _amountETHMin, 'YsPairRouter: E04');

        TransferHelper.safeTransfer(_token, msg.sender, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(msg.sender, amountETH);

        emit withdrawPairETHEvent(msg.sender, pair, _liquidity);
    }


    /// @dev receive reward token
    /// @param _tokenA staking token A address
    /// @param _tokenB staking token B address
    /// @param _deadline transaction timeout
    function harvest( 
        address _tokenA,
        address _tokenB,
        uint _deadline
    ) external ensure(_deadline){
        address pair = YsLibrary.pairFor(factory, _tokenA, _tokenB);

        (uint256 amount, uint256 reward,,,) = IYsPair(pair).userState(msg.sender);
        require( amount > 0, "YsPairRouter: E05");
        require( reward > 0, "YsPairRouter: E08");

        (,,uint pending) = IYsPair(pair).withdraw(0, msg.sender, msg.sender);

        if( pending > 0 ){
            TransferHelper.safeTransfer(IYsPair(pair).rewardToken(), msg.sender, pending);
        }

        emit harvestEvent(msg.sender, pair, pending);
    }

    /// @dev staking after only receive swapfee reward
    /// @param _tokenA staking token A address
    /// @param _tokenB staking token B address
    /// @param _deadline transaction timeout
    /// @return collect0 token A swapfee
    /// @return collect1 token B swapfee
    function collect(
        address _tokenA,
        address _tokenB,
        uint _deadline
    ) public ensure(_deadline) returns(uint256 collect0, uint256 collect1){
        address pair = YsLibrary.pairFor(factory, _tokenA, _tokenB);
        (collect0, collect1) = IYsPair(pair).collect(msg.sender);

        (address token0, address token1) = YsLibrary.sortTokens(_tokenA, _tokenB);
        if( collect0 > 0 ) TransferHelper.safeTransfer(token0, msg.sender, collect0);
        if( collect1 > 0 ) TransferHelper.safeTransfer(token1, msg.sender, collect1);

        emit collectEvent(msg.sender, pair, collect0, collect1);
    }

    /// @dev get ShareOfPool
    /// @param _tokenA tokenA address
    /// @param _tokenB tokenB address
    /// @param _amountADesired tokenA amount
    /// @param _amountBDesired tokenB amount
    /// @param _owned checking is owned
    function getShareOfPool( 
        address _tokenA, 
        address _tokenB, 
        uint _amountADesired, 
        uint _amountBDesired, 
        bool _owned
    )external view returns (uint poolRatio){
        address pair = YsLibrary.pairFor(factory, _tokenA, _tokenB);
        uint totalLiquidity = IYsPair(pair).totalSupply();
        require( totalLiquidity > 0, 'YsPairRouter: E09');

        uint liquidity;

        if( _owned ){
            (liquidity,,,, ) = IYsPair(pair).userState(msg.sender);
        }else{
            (uint amountA, uint amountB) = _addLiquidity(_tokenA, _tokenB, _amountADesired, _amountBDesired, 0, 0);
            (uint amount0, uint amount1) = _tokenA < _tokenB ? (amountA, amountB) : (amountB, amountA);
            (uint112 _reserve0, uint112 _reserve1,) = IYsPair(pair).getReserves();
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
