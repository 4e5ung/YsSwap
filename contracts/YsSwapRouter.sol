// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './libraries/YsLibrary.sol';
import './libraries/TransferHelper.sol';

import './interfaces/IWETH.sol';

contract YsSwapRouter {
    address public factory;
    address public WETH;

    uint256 maxPriceImpact = 500;   //  5.00%

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


    function _checkPriceImpact(
        uint amount,
        address[] calldata path
    )internal view{
        uint256 priceImpact = getPriceImpact(amount, path);
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
    
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        amounts = YsLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'YsSwapRouter: E03');

        _checkPriceImpact(amountIn, path);

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, YsLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        amounts = YsLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'YsSwapRouter: E04');

        _checkPriceImpact(amounts[0], path);

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, YsLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'YsSwapRouter: E05');
        amounts = YsLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'YsSwapRouter: E03');

        _checkPriceImpact(msg.value, path);

        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(YsLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'YsSwapRouter: E05');
        amounts = YsLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'YsSwapRouter: E04');

        _checkPriceImpact(amounts[0], path);

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, YsLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'YsSwapRouter: E05');
        amounts = YsLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'YsSwapRouter: E03');

        _checkPriceImpact(amountIn, path);

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, YsLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'YsSwapRouter: E05');
        amounts = YsLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'YsSwapRouter: E04');

        _checkPriceImpact(amounts[0], path);

        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(YsLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    function getPriceImpact(
        uint256 srcAmount,
        address[] memory path
    ) public view returns (uint256 priceImpact) {
        uint256 amountInFee = srcAmount;
        uint[] memory amounts = YsLibrary.getAmountsOut(factory, srcAmount, path);
        uint256 destAmount = amounts[amounts.length - 1];

        (uint256 reserveIn, uint256 reserveOut) = YsLibrary.getReserves(
            factory,
            path[0],
            path[1]
        );    
    
        amountInFee = YsLibrary.quote((amountInFee*(10000-(IYsPair(YsLibrary.pairFor(factory, path[0], path[1])).swapFee())))/(10000), reserveIn, reserveOut);

        if (amountInFee <= destAmount) {
            priceImpact = 0;
        } else {
            priceImpact = (((amountInFee - destAmount) * 10000) / amountInFee);
        }
    }
}
