// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimpleSwap
 * @dev A simplified DEX implementation with liquidity pools and token swapping
 * @notice This contract allows users to add/remove liquidity and swap tokens
 */
contract SimpleSwap is Ownable, ERC20 {

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

    // Token addresses for the pair
    address public tokenA;
    address public tokenB;
    
    // Reserves for each token
    uint256 public reserveA;
    uint256 public reserveB;
    
    // Total supply of LP tokens
    uint256 public totalSupplyLP;

    /**
     * @dev Constructor sets the LP token name and symbol
     */
    constructor() ERC20("SimpleSwap LP Token", "SLP") Ownable(msg.sender) {}

    /**
     * @notice Add liquidity to the pool
     * @param _tokenA Address of token A
     * @param _tokenB Address of token B
     * @param amountADesired Desired amount of token A
     * @param amountBDesired Desired amount of token B
     * @param amountAMin Minimum amount of token A
     * @param amountBMin Minimum amount of token B
     * @param to Address to receive LP tokens
     * @param deadline Transaction deadline
     * @return amountA Actual amount of token A added
     * @return amountB Actual amount of token B added
     * @return liquidity Amount of LP tokens minted
     */
    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity) {
        require(block.timestamp <= deadline, "EXPIRED");
        require(_tokenA != _tokenB, "IDENTICAL_ADDRESSES");
        require(to != address(0), "ZERO_ADDRESS");

        if (reserveA == 0 && reserveB == 0) {
            tokenA = _tokenA;
            tokenB = _tokenB;
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            uint amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "INSUFFICIENT_B_AMOUNT");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal >= amountAMin, "INSUFFICIENT_A_AMOUNT");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }

        require(IERC20(_tokenA).transferFrom(msg.sender, address(this), amountA), "TRANSFER_A_FAILED");
        require(IERC20(_tokenB).transferFrom(msg.sender, address(this), amountB), "TRANSFER_B_FAILED");

        if (totalSupply() == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min((amountA * totalSupply()) / reserveA, (amountB * totalSupply()) / reserveB);
        }
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        reserveA += amountA;
        reserveB += amountB;

        emit AddLiquidity(msg.sender, _tokenA, _tokenB, amountA, amountB, liquidity);

        return (amountA, amountB, liquidity);
    }

    /**
     * @notice Remove liquidity from the pool
     * @param _tokenA Address of token A
     * @param _tokenB Address of token B
     * @param liquidity Amount of LP tokens to burn
     * @param amountAMin Minimum amount of token A
     * @param amountBMin Minimum amount of token B
     * @param to Address to receive tokens
     * @param deadline Transaction deadline
     * @return amountA Amount of token A withdrawn
     * @return amountB Amount of token B withdrawn
     */
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB) {
        require(block.timestamp <= deadline, "EXPIRED");
        require(_tokenA != _tokenB, "IDENTICAL_ADDRESSES");
        require(to != address(0), "ZERO_ADDRESS");

        uint _totalSupply = totalSupply();
        amountA = (liquidity * reserveA) / _totalSupply;
        amountB = (liquidity * reserveB) / _totalSupply;

        require(amountA >= amountAMin, "INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "INSUFFICIENT_B_AMOUNT");

        _burn(msg.sender, liquidity);

        reserveA -= amountA;
        reserveB -= amountB;

        require(IERC20(_tokenA).transfer(to, amountA), "TRANSFER_A_FAILED");
        require(IERC20(_tokenB).transfer(to, amountB), "TRANSFER_B_FAILED");

        emit RemoveLiquidity(msg.sender, _tokenA, _tokenB, amountA, amountB, liquidity);
    }

    /**
     * @notice Swap exact amount of input tokens for output tokens
     * @param amountIn Amount of input tokens
     * @param amountOutMin Minimum amount of output tokens
     * @param path Array of token addresses [input, output]
     * @param to Address to receive output tokens
     * @param deadline Transaction deadline
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external {
        require(block.timestamp <= deadline, "EXPIRED");
        require(path.length == 2, "INVALID_PATH");
        address fromToken = path[0];
        address toToken = path[1];

        require(IERC20(fromToken).transferFrom(msg.sender, address(this), amountIn), "TRANSFER_IN_FAILED");

        uint amountOut = getAmountOut(fromToken, toToken, amountIn);
        require(amountOut >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");

        if (fromToken == tokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        require(IERC20(toToken).transfer(to, amountOut), "TRANSFER_OUT_FAILED");
        emit Swap(msg.sender, fromToken, toToken, amountIn, amountOut);
    }

    /**
     * @notice Get the price of tokenA in terms of tokenB
     * @param _tokenA Address of token A
     * @param _tokenB Address of token B
     * @return price Price of tokenA in tokenB
     */
    function getPrice(address _tokenA, address _tokenB) external view returns (uint price) {
        if (_tokenA == tokenA && _tokenB == tokenB) {
            require(reserveA > 0, "NO_LIQ_A");
            price = (reserveB * 1e18) / reserveA;
        } else if (_tokenA == tokenB && _tokenB == tokenA) {
            require(reserveB > 0, "NO_LIQ_B");
            price = (reserveA * 1e18) / reserveB;
        } else {
            revert("INVALID_TOKENS");
        }
    }

    /**
    * @notice Get the amount of tokens that can be received by swapping inputAmount for tokenB in terms of tokenA
    * @param tokenIn Address of input tokens
    * @param tokenOut Address of output tokens
    * @param amountIn Amount of input tokens in terms of reserveB
    * @return amountOut Amount of tokens that can be received in terms of reserveA
     */
    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256 amountOut) {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        uint reserveIn;
        uint reserveOut;
        if (tokenIn == tokenA && tokenOut == tokenB) {
            reserveIn = reserveA;
            reserveOut = reserveB;
        } else if (tokenIn == tokenB && tokenOut == tokenA) {
            reserveIn = reserveB;
            reserveOut = reserveA;
        } else {
            revert("INVALID_TOKENS");
        }
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }
    /**
     * @dev Returns the smaller of two numbers
     */
    function min(uint x, uint y) private pure returns (uint) {
        return x < y ? x : y;
    }

    /**
     * @dev Babylonian method for square root
     */
    function sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    receive() external payable {
        revert("This contract does not accept Ether");
    }
}