# SimpleCPMM

A basic Automated Market Maker (AMM) smart contract implementation with a single pool of two paired ERC20 tokens. The AMM uses the Constant Product Market Maker (CPMM) formula `x * y = k`, which is the foundation of protocols like Uniswap.

## Overview

SimpleCPMM is a minimal implementation of an AMM that demonstrates core DeFi concepts including:
- Liquidity provision and removal
- Token swapping with slippage protection
- Reward distribution for liquidity providers
- Constant Product Market Maker mechanics

### Key Features

- Single pool for two ERC20 tokens
- CPMM-based price determination
- Liquidity provider reward system
- Slippage protection for trades
- Comprehensive test coverage
- Emergency withdrawal capabilities

## Prerequisites

- [Git](https://git-scm.com/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

## Installation

1. Clone the repository
```bash
git clone https://github.com/Signor1/simpleCPMM.git
cd simpleCPMM
```

2. Install dependencies
```bash
forge install
```

## Testing

Run the test suite:
```bash
forge test
```

Run tests with gas reporting:
```bash
forge test --gas-report
```

Run a specific test:
```bash
forge test --match-test testFunctionName
```

Run tests with verbosity:
```bash
forge test -vv
```

## Contract Overview

### BasicPool.sol

The main contract implementing the AMM functionality:

- **Token Management**
  - Paired ERC20 tokens (TokenA and TokenB)
  - Reservoir tracking for both tokens
  - Owner-controlled token address setting

- **Liquidity Functions**
  - `addLiquidity(uint256 amountA, uint256 amountB)`
  - `removeLiquidity()`
  - Proportional liquidity share calculation

- **Swap Functions**
  - `swapAForB(uint256 amountAIn, uint256 minAmountBOut)`
  - `swapBForA(uint256 amountBIn, uint256 minAmountAOut)`
  - Slippage protection
  - Price impact consideration

- **Reward System**
  - Reward distribution for liquidity providers
  - Reward claiming mechanism
  - Configurable reward rate

### Test Coverage

The test suite (`BasicPoolTest.sol`) includes comprehensive testing of:
- Liquidity provision and removal
- Swap functionality
- Price impact scenarios
- Reward distribution
- Edge cases and extreme scenarios
- Concurrent operations
- Owner functions

## Technical Details

### CPMM Formula

The pool uses the constant product formula:
```
x * y = k
```
where:
- `x` is the reserve of TokenA
- `y` is the reserve of TokenB
- `k` is the constant product

### Price Impact

Swap amounts are calculated using:
```
amountOut = (reserveOut * amountIn) / (reserveIn + amountIn)
```

This formula ensures:
- Larger trades have higher price impact
- Pool maintains constant product after swaps
- Automatic price adjustment based on supply/demand

### Liquidity Provider Rewards

- Rewards are distributed proportionally to liquidity share
- Reward rate is configurable (default 1%)
- Rewards are tracked per LP and can be claimed as Pool Reward Tokens

## Development

### Smart Contract Tools

- Framework: [Foundry](https://book.getfoundry.sh/)
- Solidity Version: ^0.8.20
- OpenZeppelin Contracts:
  - ERC20
  - SafeERC20
  - Ownable
  - ReentrancyGuard

### Local Development

1. Install Foundry components:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Compile contracts:
```bash
forge build
```

3. Run tests:
```bash
forge test
```

## Security Considerations

- The contract includes reentrancy protection
- Slippage protection for swaps
- Owner-only functions for critical operations
- Emergency withdrawal capability
- Basic input validation

Note: This is a basic implementation for educational purposes. Additional security measures would be needed for production use.

## License

MIT License

## Contributing

1. Fork the repository
2. Create a new branch
3. Make your changes
4. Submit a pull request

## Author

[Signor1](https://github.com/Signor1)