# SimpleSwap: A Simplified Decentralized Exchange

## Overview

This project is a simplified implementation of a decentralized exchange (DEX), inspired by the core mechanics of Uniswap V2. It is built as a final project to demonstrate the fundamental principles of automated market makers (AMMs), liquidity pools, and token swapping on the Ethereum blockchain.

The contract allows users to:

- Provide liquidity to a token pair.
- Receive LP (Liquidity Provider) tokens representing their share in the pool.
- Swap one ERC20 token for another.
- Remove their liquidity to reclaim their underlying tokens.

## Key Features

- **Automated Market Maker (AMM)**: Uses the constant product formula (`x * y = k`) to determine token prices.
- **Liquidity Pools**: Users can deposit pairs of ERC20 tokens to create a market and earn fees (in this simplified version, fees are implicitly handled in the swap formula).
- **ERC20-based LP Tokens**: The contract itself is an ERC20 token, where each token represents a share of the liquidity pool. When a user adds liquidity, LP tokens are minted to their address.
- **Permissionless Swapping**: Anyone can swap tokens as long as there is liquidity in the pool.
- **On-Chain Price Oracle**: Provides functions like `getPrice` to get the current price based on the reserves of the token pair.

## Core Functions

### `addLiquidity`

Allows users to deposit an amount of two different ERC20 tokens (`tokenA` and `tokenB`). In return, the contract mints and sends them LP tokens. The amount of LP tokens is calculated based on their share of the total reserves.

### `removeLiquidity`

Allows users to burn their LP tokens to withdraw their proportional share of `tokenA` and `tokenB` from the pool.

### `swapExactTokensForTokens`

Enables swapping a precise amount of an input token for an output token. The output amount is calculated by the `getAmountOut` function, which implements the constant product formula.

### `getPrice` and `getAmountOut`

- `getPrice`: Returns the spot price of one token in terms of the other, based on the current pool reserves.
- `getAmountOut`: Calculates how many output tokens will be received for a given amount of input tokens.

## Tech Stack

- **Solidity `^0.8.0`**: The smart contract is written in Solidity.
- **OpenZeppelin Contracts**: Utilizes industry-standard and secure base contracts for `ERC20`, `Ownable`, and `SafeMath`.
- **Remix IDE**: Used for development, testing, and initial deployment.
- **Sepolia Testnet**: The contract is designed to be deployed and tested on the Sepolia test network.
