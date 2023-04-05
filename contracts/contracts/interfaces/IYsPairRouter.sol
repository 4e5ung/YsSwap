// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IYsPairRouter{
    function factory() external view returns (address);
    function WETH() external view returns (address);

    function investPair(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        uint deadline
    )external;

    function investPairETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    )external;

    function withdrawPair( 
        address tokenA,
        address tokenB,
        uint256 liquidity, 
        uint256 amountAMin, 
        uint256 amountBMin,
        uint deadline
    ) external;

    function withdrawPairETH( 
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    ) external;

    function harvest( 
        address tokenA,
        address tokenB,
        uint deadline
    ) external;

    function userInfo( 
        address tokenA, 
        address tokenB,
        address to
    ) external view returns(uint256, uint256, uint256, uint256, uint256);

    
    function collect(
        address tokenA,
        address tokenB,
        uint deadline
    ) external returns(uint256 collect0, uint256 collect1);


    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);

    function getShareOfPool(
        address tokenA, 
        address tokenB, 
        uint amountADesired, 
        uint amountBDesired, 
        bool owned
    )external view returns (uint poolRatio);
}
