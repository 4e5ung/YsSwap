// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../interfaces/IYsPair.sol';
import "../interfaces/IYsFactory.sol";
import "../interfaces/IYsStakingFactory.sol";

library YsLibrary {
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'YsLibrary: E01');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'YsLibrary: E02');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        // pair = address(uint160(uint(keccak256(abi.encodePacked(
        //         hex'ff',
        //         factory,
        //         keccak256(abi.encodePacked(token0, token1)),
        //         // hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
        //         hex'90423d8ed6c8950f3f64102dd49c8667899e3504be30b19f405454d018f37cfd'
        //     )))));

        pair = IYsFactory(factory).getPair(token0, token1);
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IYsPair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'YsLibrary: E03');
        require(reserveA > 0 && reserveB > 0, 'YsLibrary: E04');
        amountB = (amountA*reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint8 swapFee) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'YsLibrary: E05');
        require(reserveIn > 0 && reserveOut > 0, 'YsLibrary: E04');
        uint amountInWithFee = amountIn*(10000-swapFee);
        uint numerator = amountInWithFee*(reserveOut);
        uint denominator = (reserveIn*10000)+amountInWithFee;        
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, uint8 swapFee) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'YsLibrary: E06');
        require(reserveIn > 0 && reserveOut > 0, 'YsLibrary: E04');
        uint numerator = (reserveIn*amountOut)*10000;
        uint denominator = (reserveOut-amountOut)*(10000-swapFee);
        amountIn = (numerator / denominator)+1;
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'YsLibrary: E07');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            uint8 swapFee = IYsPair(pairFor(factory, path[i], path[i + 1])).swapFee();
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, swapFee);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'YsLibrary: E07');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            uint8 swapFee = IYsPair(pairFor(factory, path[i], path[i - 1])).swapFee();
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, swapFee);
        }
    }

    function getInvestAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'YsLibrary: E07');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, 0);
        }
    }

    function getInvestAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'YsLibrary: E07');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, 0);
        }
    }
}
