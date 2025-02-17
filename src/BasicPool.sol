// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BasicPool is Ownable, ERC20 {
    constructor() ERC20("Pool Reward Token", "PRT") Ownable(msg.sender) {}
}
