// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./YsPair.sol";

contract YsFactory  {
    address public feeTo;
    address public feeToSetter;
    
    uint8 private constant MIN_SWAP_FEE = 1;
    uint8 private constant MAX_SWAP_FEE = 100;
    uint8 private constant MIN_PROTOCOL_FEE = 1;
    uint8 private constant MAX_PROTOCOL_FEE = 10;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    // function pairCodeHash() external pure returns (bytes32) {
    //     return keccak256(type(YsPair).creationCode);
    // }

    function createPair(address router,
        address tokenA, 
        address tokenB, 
        uint8 swapFee, 
        uint8 protocolFee,
        address rewardToken,
        uint256 rewardPerSecond,
        uint256 startTimestamp,
        uint256 bonusEndTimestamp
        // uint256 poolLimitPerUser
    ) external returns (YsPair pair) {
        require(tokenA != tokenB, 'YsFactory: E01');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'YsFactory: E02');
        require(getPair[token0][token1] == address(0), 'YsFactory: E03'); // single check is sufficient

        pair = new YsPair(router);

        pair.initialize(token0, 
            token1,
            swapFee, 
            protocolFee,
            rewardToken,
            rewardPerSecond,
            startTimestamp,
            bonusEndTimestamp
        );

        getPair[token0][token1] = address(pair);
        getPair[token1][token0] = address(pair); // populate mapping in the reverse direction
        allPairs.push(address(pair));
        emit PairCreated(token0, token1, address(pair), allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'YsFactory: E04');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'YsFactory: E04');
        feeToSetter = _feeToSetter;
    }

    // function setSwapFee(address tokenA, address tokenB, uint8 newFee ) external {
    //     require(msg.sender == feeToSetter, 'YsFactory: FORBIDDEN');
    //     require(newFee >= MIN_SWAP_FEE && newFee <= MAX_SWAP_FEE, "YsFactory: INVALID_SWAP_FEE");
    //     IYsPair(getPair[tokenA][tokenB]).updateSwapFee(newFee);
    // }

    // function setProtocolFee(address tokenA, address tokenB, uint8 newFee ) external {
    //     require(msg.sender == feeToSetter, 'YsFactory: FORBIDDEN');
    //     require(newFee >= MIN_PROTOCOL_FEE && newFee <= MAX_PROTOCOL_FEE, "YsFactory: INVALID_SWAP_FEE");
    //     IYsPair(getPair[tokenA][tokenB]).updateProtocolFee(newFee);
    // }
}