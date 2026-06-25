// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import './interfaces/IERC20.sol';
import './interfaces/IExchange.sol';

contract RUExchange is IExchange {
    function grade_exchange() pure public returns (bool) {
        return false;
    }

    constructor() {
        // TODO: implement
    }

    function getToken() override external view returns(IERC20) {
        // TODO: implement
    }


    function initialize(IERC20 _RUXtoken, uint8 _feePercent, uint initialTOK, uint initialETH) override public payable returns(uint) {
        // TODO: implement
    }


    /**
     * @dev Swap ETH for tokens.
     * Buy `amount` tokens as long as the total price is at most `maxPrice`. revert if this is impossible.
     * Note that the fee is taken in *both* tokens and ETH. The fee percentage is taken from `amount` tokens 
     * (rounded up) *after* they are bought, and taken from the ETH sent (rounded up) *before* the purchase.
     * @return Returns the actual total cost in ETH including fee.
     */
    function buyTokens(uint amount, uint maxPrice) override public payable returns (uint,uint,uint) {
        // TODO: implement
    }

    /**
     * @dev Swap tokens for ETH
     * Sell `amount` tokens as long as the total price is at least `minPrice`. revert if this is impossible.
     * Note that the fee is taken in *both* tokens and ETH. The fee percentage is taken from `amount` tokens 
     * (rounded up) *before* selling, and taken from the ETH returned (rounded up) *after* selling.
     * @return Returns a tuple with the actual total value in ETH minus the fee, the eth fee and the token fee.
     */
    function sellTokens(uint amount, uint minPrice) override public returns (uint, uint, uint) {
        // TODO: implement
    }

    /**
     * Returns the current number of tokens in the liquidity pool.
     */
    function tokenBalance() external view returns(uint) {
        // TODO: implement
    }

    
    /**
     * @dev mint `amount` liquidity tokens, as long as the total number of tokens spent is at most `maxTOK`
     * and the total amount of ETH spent is `maxETH`. The token allowance for the exchange address must be at least `maxTOK`,
     * and the msg value at least `maxETH`.
     * Unused funds will be returned to the sender.
     * @return returns a tuple consisting of (token_spent, eth_spent). 
     */
    function mintLiquidityTokens(uint amount, uint maxTOK, uint maxETH) public payable returns (uint,uint) {
        // TODO: implement
    }

    /**
     * @dev burn `amount` liquidity tokens, as long as this will result in at least minTOK tokens and at least minETH eth being generated.
     * The resulting tokens and ETH will be credited to the sender.
     * @return Returns a tuple consisting of (token_credited, eth_credited). 
     */
    function burnLiquidityTokens(uint amount, uint minTOK, uint minETH) override public payable returns (uint,uint) {
        // TODO: implement
    }
    
     /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256) {
        // TODO: Implement
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) public view override returns (uint256) {
        // TODO: Implement
    }


    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        // TODO: Implement
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view override returns (uint256) {
        // TODO: Implement
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external override returns (bool) {
        // TODO: Implement
    }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        // TODO: Implement
    }
   
}
