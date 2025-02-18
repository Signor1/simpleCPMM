// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BasicPool is Ownable, ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Token addresses
    IERC20 public tokenA;
    IERC20 public tokenB;

    // Pool reserves
    uint256 public reservoirA;
    uint256 public reservoirB;

    // Liquidity tracking
    mapping(address => uint256) public liquidityProvided;
    uint256 public totalLiquidity;

    // Reward tracking
    uint256 public accumulatedRewards;
    uint256 public rewardRate = 100; // 1% (1e4 = 100%)
    mapping(address => uint256) public pendingRewards;
    mapping(address => uint256) public rewardDebt;

    // Events
    event LiquidityAdded(
        address indexed user,
        uint256 amountA,
        uint256 amountB
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
        uint256 amountB
    );
    event RewardsClaimed(address indexed user, uint256 amount);

    constructor() Ownable(msg.sender) ERC20("Pool Reward Token", "PRT") {}

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

    // Add liquidity to the pool
    function addLiquidity(
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant {
        require(amountA > 0 && amountB > 0, "Amounts must be > 0");

        // Transfer tokens
        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);

        // Calculate liquidity share
        uint256 liquidity = sqrt(amountA * amountB);

        // Update tracking
        liquidityProvided[msg.sender] += liquidity;
        totalLiquidity += liquidity;

        // Update reserves
        reservoirA += amountA;
        reservoirB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    // Swap Token A for Token B with slippage protection
    function swapAForB(
        uint256 amountAIn,
        uint256 minAmountBOut
    ) external nonReentrant {
        require(amountAIn > 0, "Amount must be > 0");

        tokenA.safeTransferFrom(msg.sender, address(this), amountAIn);

        uint256 amountBOut = (reservoirB * amountAIn) /
            (reservoirA + amountAIn);
        require(amountBOut >= minAmountBOut, "Slippage too high");

        // Update reserves
        reservoirA += amountAIn;
        reservoirB -= amountBOut;

        // Calculate and distribute rewards
        uint256 reward = (amountAIn * rewardRate) / 10000;
        _updateRewards(reward);

        tokenB.safeTransfer(msg.sender, amountBOut);
        emit Swapped(msg.sender, amountAIn, amountBOut, reward);
    }

    // Swap Token B for Token A with slippage protection
    function swapBForA(
        uint256 amountBIn,
        uint256 minAmountAOut
    ) external nonReentrant {
        require(amountBIn > 0, "Amount must be > 0");

        tokenB.safeTransferFrom(msg.sender, address(this), amountBIn);

        uint256 amountAOut = (reservoirA * amountBIn) /
            (reservoirB + amountBIn);
        require(amountAOut >= minAmountAOut, "Slippage too high");

        // Update reserves
        reservoirB += amountBIn;
        reservoirA -= amountAOut;

        // Calculate and distribute rewards
        uint256 reward = (amountBIn * rewardRate) / 10000;
        _updateRewards(reward);

        tokenA.safeTransfer(msg.sender, amountAOut);
        emit Swapped(msg.sender, amountBIn, amountAOut, reward);
    }

    // Remove liquidity from the pool
    function removeLiquidity() external nonReentrant {
        uint256 liquidity = liquidityProvided[msg.sender];
        require(liquidity > 0, "No liquidity to remove");

        // Calculate proportional share
        uint256 amountA = (reservoirA * liquidity) / totalLiquidity;
        uint256 amountB = (reservoirB * liquidity) / totalLiquidity;

        // Update tracking
        liquidityProvided[msg.sender] = 0;
        totalLiquidity -= liquidity;

        // Update reserves
        reservoirA -= amountA;
        reservoirB -= amountB;

        // Transfer tokens
        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB);
    }

    // Claim accumulated rewards
    function claimRewards() external nonReentrant {
        uint256 rewards = pendingRewards[msg.sender];
        require(rewards > 0, "No rewards to claim");

        pendingRewards[msg.sender] = 0;
        _mint(msg.sender, rewards);
        emit RewardsClaimed(msg.sender, rewards);
    }

    // Update reward distribution
    function _updateRewards(uint256 newReward) internal {
        if (totalLiquidity > 0) {
            uint256 rewardPerLiquidity = (newReward * 1e18) / totalLiquidity;
            accumulatedRewards += rewardPerLiquidity;
        }

        uint256 pending = (liquidityProvided[msg.sender] *
            (accumulatedRewards - rewardDebt[msg.sender])) / 1e18;
        if (pending > 0) {
            pendingRewards[msg.sender] += pending;
        }
        rewardDebt[msg.sender] = accumulatedRewards;
    }

    // Math utilities
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
