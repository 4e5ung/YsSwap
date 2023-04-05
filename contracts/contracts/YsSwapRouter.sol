// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './libraries/YsLibrary.sol';
import './libraries/TransferHelper.sol';

import './interfaces/IWETH.sol';

contract YsSwapRouter {
    address public immutable factory;
    address public immutable WETH;

    uint256 maxPriceImpact = 1000;   //  10.00%

    event swapExactTokensForTokensEvent(address indexed sender, address pair, uint256 amountIn, uint256 amountOut);
    event swapTokensForExactTokensEvent(address indexed sender, address pair, uint256 amountIn, uint256 amountOut);
    event swapExactETHForTokensEvent(address indexed sender, address pair, uint256 amountIn, uint256 amountOut);
    event swapTokensForExactETHEvent(address indexed sender, address pair, uint256 amountIn, uint256 amountOut);
    event swapExactTokensForETHEvent(address indexed sender, address pair, uint256 amountIn, uint256 amountOut);
    event swapETHForExactTokensEvent(address indexed sender, address pair, uint256 amountIn, uint256 amountOut);

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'YsSwapRouter: E01');
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    /// @dev cheking price impact (almost modifier)
    /// @param _amount token amount
    /// @param _path token pair address
    function _checkPriceImpact(
        uint256 _amount,
        address[] calldata _path
    )internal view{
        uint256 priceImpact = getPriceImpact(_amount, _path);
        require(priceImpact <= maxPriceImpact, 'YsSwapRouter: E02');
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = YsLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? YsLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IYsPair(YsLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to
            );
        }
    }
    
    /// @dev from(token) to to(token) swap
    /// @param _amountIn from token amount
    /// @param _amountOutMin to token min amount(slippage)
    /// @param _path token pair address
    /// @param _to receive eoa address
    /// @param _deadline transaction timeout
    /// @return amounts receive amount tokens
    function swapExactTokensForTokens(
        uint _amountIn,
        uint _amountOutMin,
        address[] calldata _path,
        address _to,
        uint _deadline
    ) external virtual ensure(_deadline) returns (uint[] memory amounts) {
        amounts = YsLibrary.getAmountsOut(factory, _amountIn, _path);
        require(amounts[amounts.length - 1] >= _amountOutMin, 'YsSwapRouter: E03');

        _checkPriceImpact(_amountIn, _path);

        address pair = YsLibrary.pairFor(factory, _path[0], _path[1]);
        TransferHelper.safeTransferFrom(_path[0], msg.sender, pair, amounts[0]);
        _swap(amounts, _path, _to);

        emit swapExactTokensForTokensEvent(msg.sender, pair, amounts[0], amounts[1]);
    }

    /// @dev to(token) to from(token) swap
    /// @param _amountOut to token amount
    /// @param _amountInMax from token max amount(slippage)
    /// @param _path token pair address
    /// @param _to receive eoa address
    /// @param _deadline transaction timeout
    /// @return amounts receive amount tokens
    function swapTokensForExactTokens(
        uint _amountOut,
        uint _amountInMax,
        address[] calldata _path,
        address _to,
        uint _deadline
    ) external virtual ensure(_deadline) returns (uint[] memory amounts) {
        amounts = YsLibrary.getAmountsIn(factory, _amountOut, _path);
        require(amounts[0] <= _amountInMax, 'YsSwapRouter: E04');

        _checkPriceImpact(amounts[0], _path);

        address pair = YsLibrary.pairFor(factory, _path[0], _path[1]);
        TransferHelper.safeTransferFrom(_path[0], msg.sender, pair, amounts[0]);
        _swap(amounts, _path, _to);

        emit swapTokensForExactTokensEvent(msg.sender, pair, amounts[0], amounts[1]);
    }


    /// @dev from(coin) to to(token) swap
    /// @param _amountOutMin to token min amount(slippage)
    /// @param _path token pair address
    /// @param _to receive eoa address
    /// @param _deadline transaction timeout
    /// @return amounts receive amount tokens
    function swapExactETHForTokens(
        uint _amountOutMin, 
        address[] calldata _path,
        address _to, 
        uint _deadline
    ) external virtual payable ensure(_deadline) returns (uint[] memory amounts){
        require(_path[0] == WETH, 'YsSwapRouter: E05');
        amounts = YsLibrary.getAmountsOut(factory, msg.value, _path);
        require(amounts[amounts.length - 1] >= _amountOutMin, 'YsSwapRouter: E03');

        _checkPriceImpact(msg.value, _path);

        address pair = YsLibrary.pairFor(factory, _path[0], _path[1]);
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(pair, amounts[0]));
        _swap(amounts, _path, _to);

        emit swapExactETHForTokensEvent(msg.sender, pair, amounts[0], amounts[1]);
    }

    /// @dev to(token) to from(coin) swap
    /// @param _amountOut to token amount
    /// @param _amountInMax from coin max amount(slippage)
    /// @param _path token pair address
    /// @param _to receive eoa address
    /// @param _deadline transaction timeout
    /// @return amounts receive amount tokens
    function swapTokensForExactETH(
        uint _amountOut, 
        uint _amountInMax, 
        address[] calldata _path, 
        address _to, 
        uint _deadline
    ) external virtual ensure(_deadline) returns (uint[] memory amounts){
        require(_path[_path.length - 1] == WETH, 'YsSwapRouter: E05');
        amounts = YsLibrary.getAmountsIn(factory, _amountOut, _path);
        require(amounts[0] <= _amountInMax, 'YsSwapRouter: E04');

        _checkPriceImpact(amounts[0], _path);

        address pair = YsLibrary.pairFor(factory, _path[0], _path[1]);
        TransferHelper.safeTransferFrom(_path[0], msg.sender, pair, amounts[0]);

        _swap(amounts, _path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(_to, amounts[amounts.length - 1]);

        emit swapTokensForExactETHEvent(msg.sender, pair, amounts[0], amounts[1]);
    }

    /// @dev from(token) to to(coin) swap
    /// @param _amountIn from token amount
    /// @param _amountOutMin to coin min amount(slippage)
    /// @param _path token pair address
    /// @param _to receive eoa address
    /// @param _deadline transaction timeout
    /// @return amounts receive amount tokens
    function swapExactTokensForETH(
        uint _amountIn, 
        uint _amountOutMin, 
        address[] calldata _path, 
        address _to, 
        uint _deadline
    ) external virtual ensure(_deadline) returns (uint[] memory amounts){
        require(_path[_path.length - 1] == WETH, 'YsSwapRouter: E05');
        amounts = YsLibrary.getAmountsOut(factory, _amountIn, _path);
        require(amounts[amounts.length - 1] >= _amountOutMin, 'YsSwapRouter: E03');

        _checkPriceImpact(_amountIn, _path);

        address pair = YsLibrary.pairFor(factory, _path[0], _path[1]);
        TransferHelper.safeTransferFrom(_path[0], msg.sender, pair, amounts[0]);
        _swap(amounts, _path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(_to, amounts[amounts.length - 1]);

        emit swapExactTokensForETHEvent(msg.sender, pair, amounts[0], amounts[1]);
    }

    /// @dev to(coin) to from(token) swap
    /// @param _amountOut to token amount
    /// @param _path token pair address
    /// @param _to receive eoa address
    /// @param _deadline transaction timeout
    /// @return amounts receive amount tokens
    function swapETHForExactTokens(
        uint _amountOut, 
        address[] calldata _path, 
        address _to, 
        uint _deadline
    ) external virtual payable ensure(_deadline) returns (uint[] memory amounts){
        require(_path[0] == WETH, 'YsSwapRouter: E05');
        amounts = YsLibrary.getAmountsIn(factory, _amountOut, _path);
        require(amounts[0] <= msg.value, 'YsSwapRouter: E04');

        _checkPriceImpact(amounts[0], _path);

        address pair = YsLibrary.pairFor(factory, _path[0], _path[1]);
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(pair, amounts[0]));
        _swap(amounts, _path, _to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);

        emit swapETHForExactTokensEvent(msg.sender, pair, amounts[0], amounts[1]);
    }

    /// @dev get swap Price Impact
    /// @param _tokenAmount change token amount
    /// @param _path token pair address
    /// @return priceImpact price impact
    function getPriceImpact(
        uint256 _tokenAmount,
        address[] memory _path
    ) public view returns (uint256 priceImpact) {
        uint256 amountInFee = _tokenAmount;
        uint[] memory amounts = YsLibrary.getAmountsOut(factory, _tokenAmount, _path);
        uint256 destAmount = amounts[amounts.length - 1];

        (uint256 reserveIn, uint256 reserveOut) = YsLibrary.getReserves(
            factory,
            _path[0],
            _path[1]
        );    
    
       amountInFee = YsLibrary.quote((amountInFee*(10000-(IYsPair(YsLibrary.pairFor(factory, _path[0], _path[1])).swapFee())))/(10000), reserveIn, reserveOut);

        if (amountInFee <= destAmount) {
            priceImpact = 0;
        } else {
            priceImpact = (((amountInFee - destAmount) * 10000) / amountInFee);
        }
    }

    /// @dev get receive token amount
    /// @param _amountIn receive token amount
    /// @param _path tokens address(2)
    function getSwapAmountsOut(
        uint _amountIn, 
        address[] memory _path
    ) public view virtual returns (uint[] memory amounts){
        return YsLibrary.getAmountsOut(factory, _amountIn, _path);
    }

    /// @dev get need token amount
    /// @param _amountOut need token amount
    /// @param _path tokens address(2)
    function getSwapAmountsIn(
        uint _amountOut, 
        address[] memory _path
    ) public view virtual returns (uint[] memory amounts){
        return YsLibrary.getAmountsIn(factory, _amountOut, _path);
    }
}
