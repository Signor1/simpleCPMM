// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {BasicPool} from "../src/BasicPool.sol";
import {TokenA} from "../src/TokenA.sol";
import {TokenB} from "../src/TokenB.sol";

contract BasicPoolTest is Test {
    BasicPool pool;
    TokenA tokenA;
    TokenB tokenB;

    // LPs address
    address[] public lps = [address(0x1), address(0x2), address(0x3)];
    // swappers address
    address[] public swappers = [
        address(0x4),
        address(0x5),
        address(0x6),
        address(0x7),
        address(0x8),
        address(0x9)
    ];

    function setUp() public {
        tokenA = new TokenA(address(this));
        tokenB = new TokenB(address(this));
        pool = new BasicPool();

        // Set up tokens in pool
        pool.setTokenA(address(tokenA));
        pool.setTokenB(address(tokenB));

        // Fund users
        uint256 mintAmount = 1000 ether;
        for (uint i = 0; i < lps.length; i++) {
            tokenA.mint(lps[i], mintAmount);
            tokenB.mint(lps[i], mintAmount);
            vm.prank(lps[i]);
            tokenA.approve(address(pool), type(uint256).max);
            vm.prank(lps[i]);
            tokenB.approve(address(pool), type(uint256).max);
        }

        for (uint i = 0; i < swappers.length; i++) {
            tokenA.mint(swappers[i], mintAmount);
            tokenB.mint(swappers[i], mintAmount);
            vm.prank(swappers[i]);
            tokenA.approve(address(pool), type(uint256).max);
            vm.prank(swappers[i]);
            tokenB.approve(address(pool), type(uint256).max);
        }
    }

    function test_AddLiquidity() public {
        // Test initial liquidity addition
        uint256 amountA = 100 ether;
        uint256 amountB = 100 ether;

        vm.prank(lps[0]);
        pool.addLiquidity(amountA, amountB);

        assertEq(
            pool.totalSupply(),
            sqrt(amountA * amountB),
            "Incorrect initial LP tokens"
        );
        assertEq(pool.reservoirA(), amountA, "Incorrect Token A reserve");
        assertEq(pool.reservoirB(), amountB, "Incorrect Token B reserve");
    }

    function test_MultipleLiquidityProviders() public {
        // First LP
        vm.prank(lps[0]);
        pool.addLiquidity(100 ether, 100 ether);
        uint256 initialLp = pool.totalSupply();

        // Second LP
        vm.prank(lps[1]);
        pool.addLiquidity(50 ether, 50 ether);

        assertApproxEqRel(
            pool.balanceOf(lps[1]),
            initialLp / 2,
            1e16, // 1% tolerance
            "Second LP should get half of initial LP tokens"
        );
    }

    function test_SwapWithSlippageProtection() public {
        /*
        Slippage is basically the difference between the price 
        you expect to pay/receive for a trade and the actual price 
        you get when the trade executes.

        What Causes Slippage?
        1. Large Orders: Big trades drain liquidity from pools, changing the price.
        2. Low Liquidity: Small pools = prices move more with each trade.
        3. Time Delays: Prices can change between when you submit a trade and when it executes.
        */

        // Setup liquidity
        vm.prank(lps[0]);
        pool.addLiquidity(1000 ether, 1000 ether);

        // Valid swap
        vm.prank(swappers[0]);
        pool.swapAForB(100 ether, 90 ether); // Expect at least 90% of ideal output

        // Test slippage failure
        vm.prank(swappers[1]);
        vm.expectRevert("Slippage too high");
        pool.swapAForB(100 ether, 95 ether); // Unrealistic slippage
    }

    function test_RewardDistribution() public {
        // Add liquidity
        vm.prank(lps[0]);
        pool.addLiquidity(1000 ether, 1000 ether);

        // Perform swaps
        uint256 swapAmount = 100 ether;
        for (uint i = 0; i < swappers.length; i++) {
            vm.prank(swappers[i]);
            pool.swapAForB(swapAmount, 1);
        }

        // Check rewards
        vm.prank(lps[0]);
        pool.claimRewards();

        uint256 expectedReward = ((swapAmount * pool.rewardRate()) / 10000) *
            swappers.length;
        assertApproxEqRel(
            pool.balanceOf(lps[0]),
            expectedReward,
            1e16, // 1% tolerance
            "Incorrect reward distribution"
        );
    }

    // Helper function for approximate square root
    function sqrt(uint256 x) private pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
