// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IYsPair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    // function MINIMUM_LIQUIDITY() external pure returns (uint);
    // function factory() external view returns (address);
    // function token0() external view returns (address);
    // function token1() external view returns (address);
    function rewardToken() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    // function price0CumulativeLast() external view returns (uint);
    // function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);
    function swapFee() external view returns (uint8);
    function protocolFee() external view returns (uint8);

    function swap(uint amount0Out, uint amount1Out, address to) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address, uint8, uint8, address, uint256, uint256, uint256, uint256) external;

    function updateSwapFee(uint8) external;
    function updateProtocolFee(uint8) external;

    function deposit(address from) external;
    function withdraw(uint256 liquidity, address burnFrom, address from) external returns (uint amount0, uint amount1, uint pending);
    function userState(address to) external view returns (uint256 amount, uint256 rewardDebt, uint256 cumulativeRewardDebt, uint256 feeCollect0, uint256 feeCollect1);
    function collect(address _from) external returns(uint256 feeCollect0, uint256 feeCollect1);
}
