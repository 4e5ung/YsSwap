// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IYsFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
