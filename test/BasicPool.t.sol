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
        vm.prank(lps[0]);
        pool.addLiquidity(100 ether, 100 ether);

        assertEq(pool.reservoirA(), 100 ether, "Incorrect Token A reserve");
        assertEq(pool.reservoirB(), 100 ether, "Incorrect Token B reserve");
        assertEq(
            pool.liquidityProvided(lps[0]),
            sqrt(100 ether * 100 ether),
            "Incorrect liquidity tracking"
        );
    }

    function test_MultipleLiquidityProviders() public {
        // First LP
        vm.prank(lps[0]);
        pool.addLiquidity(100 ether, 100 ether);
        uint256 initialAmountOfLP = pool.liquidityProvided(lps[0]);

        // Second LP
        vm.prank(lps[1]);
        pool.addLiquidity(50 ether, 50 ether);

        assertApproxEqRel(
            pool.liquidityProvided(lps[1]),
            initialAmountOfLP / 2,
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

        // Initial balances
        uint256 initialBalance = pool.balanceOf(lps[0]);

        // Perform swaps
        uint256 swapAmount = 100 ether;
        for (uint i = 0; i < swappers.length; i++) {
            vm.prank(swappers[i]);
            pool.swapAForB(swapAmount, 1);
        }

        // Claim rewards
        vm.prank(lps[0]);
        pool.claimRewards();

        // Verify reward distribution
        uint256 expectedReward = ((swapAmount * 100) / 10000) * swappers.length; // 1% per swap
        assertGt(pool.balanceOf(lps[0]), initialBalance, "No rewards received");
        assertApproxEqRel(
            pool.balanceOf(lps[0]) - initialBalance,
            expectedReward,
            1e16, // 1% tolerance
            "Incorrect reward amount"
        );
    }

    function test_RemoveLiquidity() public {
        vm.prank(lps[0]);
        pool.addLiquidity(1000 ether, 1000 ether);

        uint256 initialBalanceA = tokenA.balanceOf(lps[0]);
        uint256 initialBalanceB = tokenB.balanceOf(lps[0]);

        vm.prank(lps[0]);
        pool.removeLiquidity();

        assertGt(
            tokenA.balanceOf(lps[0]),
            initialBalanceA,
            "Should receive Token A back"
        );
        assertGt(
            tokenB.balanceOf(lps[0]),
            initialBalanceB,
            "Should receive Token B back"
        );
        assertEq(pool.liquidityProvided(lps[0]), 0, "Liquidity not cleared");
    }

    function test_EdgeCases() public {
        vm.prank(lps[0]);
        vm.expectRevert("Amounts must be > 0");
        pool.addLiquidity(0, 100 ether);

        vm.prank(swappers[0]);
        vm.expectRevert("Amount must be > 0");
        pool.swapAForB(0, 0);

        vm.prank(lps[0]);
        vm.expectRevert("No liquidity to remove");
        pool.removeLiquidity();
    }

    function test_ComplexScenario() public {
        // Setup initial liquidity
        vm.startPrank(lps[0]);
        pool.addLiquidity(100 ether, 100 ether);
        vm.stopPrank();

        vm.startPrank(lps[1]);
        pool.addLiquidity(100 ether, 100 ether);
        vm.stopPrank();

        vm.startPrank(lps[2]);
        pool.addLiquidity(100 ether, 100 ether);
        vm.stopPrank();

        // Record initial states
        uint256 initialReservoirA = pool.reservoirA();
        uint256 initialReservoirB = pool.reservoirB();

        // Execute alternating swaps
        for (uint i = 0; i < 6; i++) {
            vm.startPrank(swappers[i]);
            if (i % 2 == 0) {
                pool.swapAForB(10 ether, 1);
            } else {
                pool.swapBForA(10 ether, 1);
            }
            vm.stopPrank();
        }

        // Verify reserves changed
        assertNotEq(
            pool.reservoirA(),
            initialReservoirA,
            "Reserves A should change"
        );
        assertNotEq(
            pool.reservoirB(),
            initialReservoirB,
            "Reserves B should change"
        );

        // Check and claim rewards for all LPs
        for (uint i = 0; i < 3; i++) {
            uint256 initialBalance = pool.balanceOf(lps[i]);
            vm.prank(lps[i]);
            pool.claimRewards();
            assertGt(
                pool.balanceOf(lps[i]),
                initialBalance,
                "LP should receive rewards"
            );
        }

        // Remove liquidity for first LP
        uint256 initialTokenABalance = tokenA.balanceOf(lps[0]);
        uint256 initialTokenBBalance = tokenB.balanceOf(lps[0]);

        vm.prank(lps[0]);
        pool.removeLiquidity();

        assertGt(
            tokenA.balanceOf(lps[0]),
            initialTokenABalance,
            "Should receive Token A back"
        );
        assertGt(
            tokenB.balanceOf(lps[0]),
            initialTokenBBalance,
            "Should receive Token B back"
        );
    }

    // Owner functionality tests
    function test_OwnerFunctions() public {
        // Test token setting
        address newTokenA = address(0x123);
        address newTokenB = address(0x456);

        pool.setTokenA(newTokenA);
        pool.setTokenB(newTokenB);

        assertEq(address(pool.tokenA()), newTokenA);
        assertEq(address(pool.tokenB()), newTokenB);

        // Test reward rate setting
        pool.setRewardRate(200); // Set to 2%
        assertEq(pool.rewardRate(), 200);

        // Test invalid reward rate
        vm.expectRevert("Reward rate too high");
        pool.setRewardRate(20000);

        // Test emergency withdraw
        tokenA.mint(address(pool), 100 ether);
        uint256 initialBalance = tokenA.balanceOf(pool.owner());
        pool.emergencyWithdraw(address(tokenA), 100 ether);
        assertEq(tokenA.balanceOf(pool.owner()), initialBalance + 100 ether);
    }

    // Price impact and slippage tests
    function test_PriceImpact() public {
        // Setup initial liquidity
        vm.prank(lps[0]);
        pool.addLiquidity(1000 ether, 1000 ether);

        // Small swap (10 ETH)
        vm.startPrank(swappers[0]);
        uint256 smallSwapOut = getSwapAmount(10 ether, true);
        pool.swapAForB(10 ether, smallSwapOut);
        vm.stopPrank();

        // Medium swap (100 ETH)
        vm.startPrank(swappers[1]);
        uint256 mediumSwapOut = getSwapAmount(100 ether, true);
        pool.swapAForB(100 ether, mediumSwapOut);
        vm.stopPrank();

        // Large swap (500 ETH)
        vm.startPrank(swappers[2]);
        uint256 largeSwapOut = getSwapAmount(500 ether, true);
        pool.swapAForB(500 ether, largeSwapOut);
        vm.stopPrank();

        console.log(
            "Small swap rate (output per input unit):",
            (smallSwapOut * 1e18) / 10 ether
        );
        console.log(
            "Medium swap rate (output per input unit):",
            (mediumSwapOut * 1e18) / 100 ether
        );
        console.log(
            "Large swap rate (output per input unit):",
            (largeSwapOut * 1e18) / 500 ether
        );

        // Verify price impact increases (rate decreases) with swap size
        assertGt(
            (smallSwapOut * 1e18) / 10 ether, // Rate for small swap
            (mediumSwapOut * 1e18) / 100 ether, // Rate for medium swap
            "Medium swap should have higher price impact (lower rate)"
        );
        assertGt(
            (mediumSwapOut * 1e18) / 100 ether, // Rate for medium swap
            (largeSwapOut * 1e18) / 500 ether, // Rate for large swap
            "Large swap should have higher price impact (lower rate)"
        );
    }

    // Test extreme scenarios
    function test_RapidSwaps() public {
        // Test with very small amounts
        vm.prank(lps[0]);
        pool.addLiquidity(1, 1);

        vm.prank(swappers[0]);
        pool.swapAForB(1, 0);

        // Test with very large amounts
        vm.prank(lps[1]);
        pool.addLiquidity(1000 ether, 1000 ether);

        vm.prank(swappers[1]);
        pool.swapAForB(900 ether, 1);

        // Test rapid swaps
        vm.startPrank(swappers[2]);
        for (uint i = 0; i < 10; i++) {
            pool.swapAForB(1 ether, 0);
            pool.swapBForA(1 ether, 0);
        }
        vm.stopPrank();
    }

    // Test concurrent operations
    function test_ConcurrentOperations() public {
        // Setup initial state
        vm.prank(lps[0]);
        pool.addLiquidity(1000 ether, 1000 ether);

        // Simultaneous operations
        for (uint i = 1; i < 3; i++) {
            // Add liquidity
            vm.prank(lps[i]);
            pool.addLiquidity(100 ether, 100 ether);

            // Perform swap
            vm.prank(swappers[i]);
            pool.swapAForB(50 ether, 1);

            // Claim rewards
            vm.prank(lps[i]);
            pool.claimRewards();
        }

        // Remove liquidity while others are active
        vm.prank(lps[0]);
        pool.removeLiquidity();
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

    // Helper function to calculate expected swap amount
    function getSwapAmount(
        uint256 amountIn,
        bool isAtoB
    ) internal view returns (uint256) {
        if (isAtoB) {
            return
                (pool.reservoirB() * amountIn) / (pool.reservoirA() + amountIn);
        } else {
            return
                (pool.reservoirA() * amountIn) / (pool.reservoirB() + amountIn);
        }
    }
}
