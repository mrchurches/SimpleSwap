// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimpleSwap
 * @dev A simplified DEX implementation with liquidity pools and token swapping
 * @notice This contract allows users to add/remove liquidity and swap tokens
 */
contract SimpleSwap is Ownable, ERC20 {
    using SafeMath for uint256;

    // Events for specific operations
    event AddLiquidity(
        address indexed user,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    event RemoveLiquidity(
        address indexed user,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    event Swap(
        address indexed user,
        address indexed fromToken,
        address indexed toToken,
        uint256 amountIn,
        uint256 amountOut
    );

    // Mapping to track reserves for each token pair
    mapping(address => mapping(address => uint256)) public reserves;

    /**
     * @dev Constructor sets the LP token name and symbol
     */
    constructor() ERC20("SimpleSwap LP Token", "SLP") Ownable(msg.sender) {}

    /**
     * @dev Add liquidity to a token pair
     * @param tokenA Address of first token
     * @param tokenB Address of second token
     * @param amountADesired Desired amount of token A
     * @param amountBDesired Desired amount of token B
     * @param amountAMin Minimum acceptable amount of token A
     * @param amountBMin Minimum acceptable amount of token B
     * @param to Address to receive LP tokens
     * @param deadline Transaction deadline
     * @return amountA Actual amount of token A added
     * @return amountB Actual amount of token B added
     * @return liquidity Amount of LP tokens minted
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(block.timestamp <= deadline, "Transaction expired");
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        require(to != address(0), "ZERO_ADDRESS");

        // Get current reserves
        uint256 reserveA = reserves[tokenA][tokenB];
        uint256 reserveB = reserves[tokenB][tokenA];

        if (totalSupply() == 0) {
            // First liquidity provision - use geometric mean
            liquidity = sqrt(amountADesired.mul(amountBDesired));
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            // Calculate optimal amounts based on current reserves
            uint256 liquidityA = amountADesired.mul(totalSupply()).div(reserveA);
            uint256 liquidityB = amountBDesired.mul(totalSupply()).div(reserveB);
            liquidity = min(liquidityA, liquidityB);

            // Calculate actual amounts to add
            amountA = liquidity.mul(reserveA).div(totalSupply());
            amountB = liquidity.mul(reserveB).div(totalSupply());
        }

        // Validate minimum amounts
        require(amountA >= amountAMin, "INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "INSUFFICIENT_B_AMOUNT");

        // Transfer tokens from user to contract
        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "TRANSFER_A_FAILED");
        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountB), "TRANSFER_B_FAILED");

        // Update reserves
        reserves[tokenA][tokenB] = reserveA.add(amountA);
        reserves[tokenB][tokenA] = reserveB.add(amountB);

        // Mint LP tokens to user
        _mint(to, liquidity);

        emit AddLiquidity(msg.sender, tokenA, tokenB, amountA, amountB, liquidity);
    }

    /**
     * @dev Remove liquidity from a token pair
     * @param tokenA Address of first token
     * @param tokenB Address of second token
     * @param liquidity Amount of LP tokens to burn
     * @param amountAMin Minimum acceptable amount of token A
     * @param amountBMin Minimum acceptable amount of token B
     * @param to Address to receive tokens
     * @param deadline Transaction deadline
     * @return amountA Amount of token A received
     * @return amountB Amount of token B received
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        require(block.timestamp <= deadline, "Transaction expired");
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        require(to != address(0), "ZERO_ADDRESS");

        // Burn LP tokens from user
        _burn(msg.sender, liquidity);

        // Get current reserves
        uint256 reserveA = reserves[tokenA][tokenB];
        uint256 reserveB = reserves[tokenB][tokenA];

        // Calculate amounts to return based on LP token proportion
        amountA = liquidity.mul(reserveA).div(totalSupply());
        amountB = liquidity.mul(reserveB).div(totalSupply());

        // Validate minimum amounts
        require(amountA >= amountAMin, "INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "INSUFFICIENT_B_AMOUNT");

        // Update reserves
        reserves[tokenA][tokenB] = reserveA.sub(amountA);
        reserves[tokenB][tokenA] = reserveB.sub(amountB);

        // Transfer tokens to user
        require(IERC20(tokenA).transfer(to, amountA), "TRANSFER_A_FAILED");
        require(IERC20(tokenB).transfer(to, amountB), "TRANSFER_B_FAILED");

        emit RemoveLiquidity(msg.sender, tokenA, tokenB, amountA, amountB, liquidity);
    }

    /**
     * @dev Swap exact tokens for tokens
     * @param amountIn Amount of input tokens
     * @param amountOutMin Minimum acceptable amount of output tokens
     * @param path Array of token addresses (input -> output)
     * @param to Address to receive output tokens
     * @param deadline Transaction deadline
     * @return amounts Array with input and output amounts
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(block.timestamp <= deadline, "Transaction expired");
        require(path.length >= 2, "Invalid path");
        require(to != address(0), "ZERO_ADDRESS");

        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        // Transfer input tokens from user
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "TRANSFER_IN_FAILED");

        // Calculate output amount using constant product formula
        uint256 amountOut = getAmountOut(amountIn, reserves[tokenIn][tokenOut], reserves[tokenOut][tokenIn]);
        require(amountOut >= amountOutMin, "Insufficient output amount");

        // Update reserves
        reserves[tokenIn][tokenOut] = reserves[tokenIn][tokenOut].add(amountIn);
        reserves[tokenOut][tokenIn] = reserves[tokenOut][tokenIn].sub(amountOut);

        // Transfer output tokens to user
        require(IERC20(tokenOut).transfer(to, amountOut), "TRANSFER_OUT_FAILED");

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;

        return amounts;
    }

    /**
     * @dev Get the price of tokenA in terms of tokenB
     * @param tokenA Address of token A
     * @param tokenB Address of token B
     * @return price Price of tokenA in terms of tokenB (scaled by 1e18)
     */
    function getPrice(address tokenA, address tokenB) external view returns (uint256 price) {
        uint256 reserveA = reserves[tokenA][tokenB];
        uint256 reserveB = reserves[tokenB][tokenA];

        require(reserveB > 0, "Insufficient reserve for token B");

        // Price = reserveA / reserveB, scaled by 1e18
        price = reserveA.mul(1e18).div(reserveB);
        return price;
    }

    /**
     * @dev Calculate output amount for a given input using constant product formula
     * @param amountIn Amount of input tokens
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     * @return amountOut Amount of output tokens
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(reserveIn > 0 && reserveOut > 0, "Insufficient reserves");
        require(amountIn > 0, "Insufficient input amount");

        // Constant product formula: (x + dx) * (y - dy) = x * y
        // dy = (dx * y) / (x + dx)
        uint256 amountInWithFee = amountIn.mul(997); // 0.3% fee
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator.div(denominator);
    }

    /**
     * @dev Calculate square root using Babylonian method by UniswapV2
     * @param x Number to calculate square root of
     * @return y Square root of x
     */
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /**
     * @dev Return the minimum of two numbers
     * @param a First number
     * @param b Second number
     * @return Minimum of a and b
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Get reserves for a token pair
     * @param tokenA Address of first token
     * @param tokenB Address of second token
     * @return reserveA Reserve of token A
     * @return reserveB Reserve of token B
     */
    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB) {
        reserveA = reserves[tokenA][tokenB];
        reserveB = reserves[tokenB][tokenA];
    }
}