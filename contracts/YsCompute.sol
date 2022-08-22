// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './libraries/Babylonian.sol';
import './libraries/FullMath.sol';
import './libraries/YsLibrary.sol';
import './interfaces/IYsPair.sol';
import './interfaces/IYsFactory.sol';

contract YsCompute {
    address public factory;

    constructor(address factory_) {
        factory = factory_;
    }

    // computes liquidity value given all the parameters of the pair
    function computeLiquidityValue(
        uint256 reservesA,
        uint256 reservesB,
        uint256 totalSupply,
        uint256 liquidityAmount,
        uint256 protocolFee,
        bool feeOn,
        uint kLast
    ) internal pure returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        if (feeOn && kLast > 0) {
            uint rootK = Babylonian.sqrt(reservesA * reservesB);
            uint rootKLast = Babylonian.sqrt(kLast);
            if (rootK > rootKLast) {
                uint numerator1 = totalSupply;
                uint numerator2 = rootK-rootKLast;
                uint denominator = (rootK*protocolFee) + rootKLast;
                uint feeLiquidity = FullMath.mulDiv(numerator1, numerator2, denominator);
                totalSupply = totalSupply+feeLiquidity;
            }
        }
        return ((reservesA*liquidityAmount) / totalSupply, (reservesB*liquidityAmount) / totalSupply);
    }

    function getLiquidityValue(
        address tokenA,
        address tokenB,
        uint256 liquidityAmount
    ) external view returns (
        uint256 tokenAAmount,
        uint256 tokenBAmount
    ) {
        (uint256 reservesA, uint256 reservesB) = YsLibrary.getReserves(factory, tokenA, tokenB);
        IYsPair pair = IYsPair(YsLibrary.pairFor(factory, tokenA, tokenB));
        bool feeOn = IYsFactory(factory).feeTo() != address(0);
        uint kLast = feeOn ? pair.kLast() : 0;
        uint totalSupply = pair.totalSupply();
        return computeLiquidityValue(reservesA, reservesB, totalSupply, liquidityAmount, pair.protocolFee(), feeOn, kLast);
    }
}