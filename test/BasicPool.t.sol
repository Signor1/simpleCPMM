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
}
