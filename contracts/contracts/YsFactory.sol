// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IYsPair.sol";

/// @dev This is YsFactory contract
contract YsFactory  {

    address private factoryAdmin;
    address private feeAdmin;
    
    uint8 private constant MIN_SWAP_FEE = 1;
    uint8 private constant MAX_SWAP_FEE = 100;
    uint8 private constant MIN_PROTOCOL_FEE = 1;
    uint8 private constant MAX_PROTOCOL_FEE = 10;

    mapping(address => mapping(address => address)) public getPair;

    constructor(address _factoryAdmin, address _feeAdmin) {
        feeAdmin = _feeAdmin;
        factoryAdmin = _factoryAdmin;
    }

    modifier onlyAdmin(){
        require(msg.sender == factoryAdmin, "YsFactory: E01");
        _;
    }

    modifier onlyFeeAdmin(){
        require(msg.sender == feeAdmin, "YsFactory: E02");
        _;
    }

    /// @dev set paircontract setting
    /// @param _pairContract pair contract address
    /// @param _tokenA  tokenA address
    /// @param _tokenB  tokenB address
    function setPair(
        address _pairContract,
        address _tokenA,
        address _tokenB
    ) external onlyAdmin {
        require(_tokenA != _tokenB, 'YsFactory: E04');
        (address token0, address token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        require(token0 != address(0), 'YsFactory: E05');

        getPair[token0][token1] = _pairContract;
        getPair[token1][token0] = _pairContract;
    }

    /// @dev set feeadmin address
    /// @param _feeAdmin feeadmin eoa
    function setFeeAdmin(address _feeAdmin) external onlyAdmin{
        feeAdmin = _feeAdmin;
    }

    /// @dev set admin address
    /// @param _factoryAdmin admin eoa
    function setAdmin(address _factoryAdmin) external onlyAdmin{
        factoryAdmin = _factoryAdmin;
    }

    /// @dev set receive address(defalut zero)
    /// @param _tokenA  tokenA address
    /// @param _tokenB  tokenB address
    /// @param _newFeeTo receive eoa
    function setFeeTo(
        address _tokenA,
        address _tokenB, 
        address _newFeeTo
    ) external onlyFeeAdmin{
        IYsPair(getPair[_tokenA][_tokenB]).updateFeeTo(_newFeeTo);
    }

    /// @dev set swap fee setting
    /// @param _tokenA  tokenA address
    /// @param _tokenB  tokenB address
    /// @param _newFee  new swap fee (percent 30 = 0.3)
    function setSwapFee(
        address _tokenA, 
        address _tokenB, 
        uint8 _newFee 
    ) external onlyFeeAdmin {
        require(_newFee >= MIN_SWAP_FEE && _newFee <= MAX_SWAP_FEE, "YsFactory: E03");
        IYsPair(getPair[_tokenA][_tokenB]).updateSwapFee(_newFee);
    }

    /// @dev set protocol fee setting
    /// @param _tokenA  tokenA address
    /// @param _tokenB  tokenB address
    /// @param _newFee  new swap fee (percent 30 = 0.3)
    function setProtocolFee(
        address _tokenA, 
        address _tokenB, 
        uint8 _newFee 
    ) external onlyFeeAdmin {
        require(_newFee >= MIN_PROTOCOL_FEE && _newFee <= MAX_PROTOCOL_FEE, "YsFactory: E03");
        IYsPair(getPair[_tokenA][_tokenB]).updateProtocolFee(_newFee);
    }
}