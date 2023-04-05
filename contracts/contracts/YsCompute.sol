// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './libraries/Babylonian.sol';
import './libraries/FullMath.sol';
import './libraries/YsLibrary.sol';
import './interfaces/IYsPair.sol';
import './interfaces/IYsFactory.sol';

contract YsCompute {
    address public immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }

    /// @dev computes liquidity value
    /// @param _reservesA token A reserves
    /// @param _reservesB token B reserves
    /// @param _totalSupply pair token total
    /// @param _liquidityAmount chking liquidity amount
    /// @param _protocolFee protocol fee
    /// @param _feeOn receive fee?
    /// @param _kLast last reserve0 * reserve1 
    /// @return tokenAAmount receive token A amount
    /// @return tokenBAmount receive token B amount
    function computeLiquidityValue(
        uint256 _reservesA,
        uint256 _reservesB,
        uint256 _totalSupply,
        uint256 _liquidityAmount,
        uint256 _protocolFee,
        bool _feeOn,
        uint _kLast
    ) internal pure returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        if (_feeOn && _kLast > 0) {
            uint rootK = Babylonian.sqrt(_reservesA * _reservesB);
            uint rootKLast = Babylonian.sqrt(_kLast);
            if (rootK > rootKLast) {
                uint numerator1 = _totalSupply;
                uint numerator2 = rootK-rootKLast;
                uint denominator = (rootK*_protocolFee) + rootKLast;
                uint feeLiquidity = FullMath.mulDiv(numerator1, numerator2, denominator);
                _totalSupply = _totalSupply+feeLiquidity;
            }
        }
        return ((_reservesA*_liquidityAmount) / _totalSupply, (_reservesB*_liquidityAmount) / _totalSupply);
    }

    /// @dev get tokenA, tokenB in liquidity
    /// @param _tokenA token A address
    /// @param _tokenB token B address
    /// @param _liquidityAmount pair liquidity amount
    /// @return tokenAAmount receive token A amount
    /// @return tokenBAmount receive token B amount
    function getLiquidityValue(
        address _tokenA,
        address _tokenB,
        uint256 _liquidityAmount
    ) external view returns (
        uint256 tokenAAmount,
        uint256 tokenBAmount
    ){
        (uint256 reservesA, uint256 reservesB) = YsLibrary.getReserves(factory, _tokenA, _tokenB);
        IYsPair pair = IYsPair(YsLibrary.pairFor(factory, _tokenA, _tokenB));
        bool feeOn = pair.feeTo() != address(0);
        uint kLast = feeOn ? pair.kLast() : 0;
        uint totalSupply = pair.totalSupply();
        return computeLiquidityValue(reservesA, reservesB, totalSupply, _liquidityAmount, pair.protocolFee(), feeOn, kLast);
    }

    /// @dev get tokenA, tokenB in ratio
    /// @param _tokenA  token a
    /// @param _tokenB  token b
    /// @param _amountIn checking amount balance
    /// @return amountA ratio tokenA amount
    /// @return amountB ratio tokenB amount
    function getLiquidityPair(
        address _tokenA,
        address _tokenB,
        uint256 _amountIn
    ) external view virtual returns (uint256 amountA, uint256 amountB){
        (uint reserveA, uint reserveB) = YsLibrary.getReserves(factory, _tokenA, _tokenB);
        uint amountBOptimal = YsLibrary.quote(_amountIn, reserveA, reserveB);
        (amountA, amountB) = (_amountIn, amountBOptimal);
    }
}