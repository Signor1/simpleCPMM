// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BasicPool is Ownable, ERC20 {
    // Token addresses
    IERC20 public tokenA;
    IERC20 public tokenB;

    // Reservoirs of Token A and Token B
    uint256 public reservoirA;
    uint256 public reservoirB;

    // Total supply of liquidity tokens (LP tokens)
    uint256 public pooltotalSupply;

    // Track user's LP share
    mapping(address => uint256) public lpbalanceOf;

    // Reward rate: 1% of swap volume goes to LPs as rewards
    uint256 public rewardRate = 100; // 100 = 1% (1e4 = 100%)

    // Constructor
    // ERC20 - Pool Reward Token for rewarding liquidity providers on each swap
    // Ownable - Pool is owned by the deployer, access to some functions controlled by Ownable
    constructor() ERC20("Pool Reward Token", "PRT") Ownable(msg.sender) {}

    // Events
    event LiquidityAdded(
        address indexed user,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    event Swapped(
        address indexed user,
        uint256 amountIn,
        uint256 amountOut,
        uint256 reward
    );
    event LiquidityRemoved(
        address indexed user,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    // Set Token A address (onlyOwner)
    function setTokenA(address _tokenA) external onlyOwner {
        require(_tokenA != address(0), "Invalid address");
        tokenA = IERC20(_tokenA);
    }

    // Set Token B address (onlyOwner)
    function setTokenB(address _tokenB) external onlyOwner {
        require(_tokenB != address(0), "Invalid address");
        tokenB = IERC20(_tokenB);
    }
}
