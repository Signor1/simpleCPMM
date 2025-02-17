// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BasicPool is Ownable, ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Token addresses
    IERC20 public tokenA;
    IERC20 public tokenB;

    // Pool reserves
    uint256 public reservoirA;
    uint256 public reservoirB;

    // Reward tracking
    uint256 public totalRewardPerShare; // 1e18 precision
    mapping(address => uint256) public lastRewardPerShare;
    mapping(address => uint256) public pendingRewards;
    uint256 private constant rewardRate = 100; // 1% (1e4 = 100%)

    // Constructor
    // ERC20 - Pool Reward Token for rewarding liquidity providers on each swap
    // Ownable - Pool is owned by the deployer, access to some functions controlled by Ownable
    constructor() ERC20("Pool LP Token", "PLP") Ownable(msg.sender) {}

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
    event RewardsClaimed(address indexed user, uint256 amount);

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

        _updateReward(msg.sender);

        // Transfer tokens
        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);

        // Calculate LP tokens
        uint256 liquidity;
        if (totalSupply() == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min(
                (amountA * totalSupply()) / reservoirA,
                (amountB * totalSupply()) / reservoirB
            );
        }

        // Update reserves and mint LP tokens
        reservoirA += amountA;
        reservoirB += amountB;
        _mint(msg.sender, liquidity);

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
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

        reservoirA += amountAIn;
        reservoirB -= amountBOut;

        _mintRewards(amountAIn);
        tokenB.safeTransfer(msg.sender, amountBOut);

        emit Swapped(msg.sender, amountAIn, amountBOut, rewardRate);
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

        reservoirB += amountBIn;
        reservoirA -= amountAOut;

        _mintRewards(amountBIn);
        tokenA.safeTransfer(msg.sender, amountAOut);

        emit Swapped(msg.sender, amountBIn, amountAOut, rewardRate);
    }

    // Remove liquidity from the pool
    function removeLiquidity(uint256 liquidity) external nonReentrant {
        require(liquidity > 0, "Liquidity must be > 0");
        _updateReward(msg.sender);

        uint256 amountA = (reservoirA * liquidity) / totalSupply();
        uint256 amountB = (reservoirB * liquidity) / totalSupply();

        _burn(msg.sender, liquidity);
        reservoirA -= amountA;
        reservoirB -= amountB;

        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    // Claim accumulated rewards
    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        uint256 rewards = pendingRewards[msg.sender];
        require(rewards > 0, "No rewards");

        pendingRewards[msg.sender] = 0;
        _mint(msg.sender, rewards);
        emit RewardsClaimed(msg.sender, rewards);
    }

    // Reward distribution internal logic
    function _mintRewards(uint256 swapVolume) internal {
        uint256 totalReward = (swapVolume * rewardRate) / 10000;
        if (totalSupply() > 0 && totalReward > 0) {
            totalRewardPerShare += (totalReward * 1e18) / totalSupply();
            _mint(address(this), totalReward);
        }
    }

    // Update user's reward tracking
    function _updateReward(address user) internal {
        uint256 unclaimed = ((totalRewardPerShare - lastRewardPerShare[user]) *
            balanceOf(user)) / 1e18;
        pendingRewards[user] += unclaimed;
        lastRewardPerShare[user] = totalRewardPerShare;
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

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
