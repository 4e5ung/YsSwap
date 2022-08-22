// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IYsPairRouter{
    function factory() external view returns (address);
    function WETH() external view returns (address);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin, 
        address[] calldata path, 
        address to, 
        uint deadline
    )external payable returns (uint[] memory amounts);

    function swapTokensForExactETH(
        uint amountOut, 
        uint amountInMax, 
        address[] calldata path, 
        address to, 
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn, 
        uint amountOutMin, 
        address[] calldata path, 
        address to, 
        uint deadline
    )external returns (uint[] memory amounts);

    function swapETHForExactTokens(
        uint amountOut, 
        address[] calldata path, 
        address to, 
        uint deadline
    )external payable returns (uint[] memory amounts);

    function getPriceImpact(
        uint256 srcAmount,
        address[] memory path
    ) external view returns (uint256 priceImpact);

}
