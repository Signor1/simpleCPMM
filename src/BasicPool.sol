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

    // Mapping to store accrued rewards per LP
    mapping(address => uint256) public pendingRewards;

    // Reward rate: 1% of swap volume goes to LPs as rewards
    uint256 private constant rewardRate = 100; // 100 = 1% (1e4 = 100%)

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

    // Add liquidity to the pool
    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 && amountB > 0, "Amounts must be > 0");

        // Transfer tokens from user to contract
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        // Calculate LP tokens to mint (proportional to liquidity added)
        uint256 liquidity;
        if (pooltotalSupply == 0) {
            liquidity = sqrt(amountA * amountB); // Initial liquidity
        } else {
            liquidity = min(
                (amountA * pooltotalSupply) / reservoirA,
                (amountB * pooltotalSupply) / reservoirB
            );
        }

        // Update reserves and LP tokens
        reservoirA += amountA;
        reservoirB += amountB;
        lpbalanceOf[msg.sender] += liquidity;
        pooltotalSupply += liquidity;

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    // Swap Token A for Token B (with LP rewards)
    function swapAForB(uint256 amountAIn) external {
        require(amountAIn > 0, "Amount must be > 0");

        // Transfer Token A from user to contract
        tokenA.transferFrom(msg.sender, address(this), amountAIn);

        // Calculate Token B output using x * y = k
        uint256 amountBOut = (reservoirB * amountAIn) /
            (reservoirA + amountAIn);

        // Update reserves
        reservoirA += amountAIn;
        reservoirB -= amountBOut;

        // Transfer Token B to user
        tokenB.transfer(msg.sender, amountBOut);

        // Mint rewardToken to LPs based on swap volume and LP share
        _mintRewards(amountAIn);

        emit Swapped(msg.sender, amountAIn, amountBOut, rewardRate);
    }

    // Swap Token B for Token A (with LP rewards)
    function swapBForA(uint256 amountBIn) external {
        require(amountBIn > 0, "Amount must be > 0");

        // Transfer Token B from user to contract
        tokenB.transferFrom(msg.sender, address(this), amountBIn);

        // Calculate Token A output using x * y = k
        uint256 amountAOut = (reservoirA * amountBIn) /
            (reservoirB + amountBIn);

        // Update reserves
        reservoirB += amountBIn;
        reservoirA -= amountAOut;

        // Transfer Token A to user
        tokenA.transfer(msg.sender, amountAOut);

        // Mint rewardToken to LPs based on swap volume and LP share
        _mintRewards(amountBIn);

        emit Swapped(msg.sender, amountBIn, amountAOut, rewardRate);
    }

    // Remove liquidity from the pool
    function removeLiquidity(uint256 liquidity) external {
        require(liquidity > 0, "Liquidity must be > 0");

        // Calculate user's share of reserves
        uint256 amountA = (reservoirA * liquidity) / pooltotalSupply;
        uint256 amountB = (reservoirB * liquidity) / pooltotalSupply;

        // Burn LP tokens and update reserves
        lpbalanceOf[msg.sender] -= liquidity;
        pooltotalSupply -= liquidity;
        reservoirA -= amountA;
        reservoirB -= amountB;

        // Transfer tokens back to user
        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    // Mint rewards to LPs based on their share and swap volume
    function _mintRewards(uint256 swapVolume) internal {
        // Total reward = swapVolume * rewardRate / 1e4 (e.g., 1% of swap volume)
        uint256 totalReward = (swapVolume * rewardRate) / 10000;

        // Distribute rewards proportionally to all LPs
        if (pooltotalSupply > 0 && totalReward > 0) {
            // Calculate reward per liquidity unit
            uint256 rewardPerUnit = totalReward / pooltotalSupply;

            // Distribute rewards only to active LPs
            if (lpbalanceOf[msg.sender] > 0) {
                pendingRewards[msg.sender] +=
                    rewardPerUnit *
                    lpbalanceOf[msg.sender];
            }
        }
    }

    // Function to claim rewards
    function claimRewards() external {
        uint256 rewards = pendingRewards[msg.sender];
        require(rewards > 0, "No rewards to claim");

        pendingRewards[msg.sender] = 0;
        _mint(msg.sender, rewards);
    }

    // Helper functions
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
