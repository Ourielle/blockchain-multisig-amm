// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import './interfaces/IERC20.sol';
import './interfaces/IExchange.sol';

contract RUExchange is IExchange {
    function grade_exchange() pure public returns (bool) {
        return false;
    }

    // The account that deployed the exchange; only it may call initialize.
    address private deployer;

    // Set once initialize succeeds, so the exchange can be initialized only once.
    bool private initialized;

    // The underlying ERC20 token traded against ETH.
    IERC20 private token;

    // Trading fee as a whole-number percentage of each trade (0..99).
    uint8 private feePercent;

    // Liquidity-token (LQT) ledger. The exchange is itself an ERC20 whose balances
    // represent each provider's share of the pool.
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    uint256 private _totalSupply;

    constructor() {
        deployer = msg.sender;
    }

    /**
     * Returns the underlying token contract traded by the exchange.
     */
    function getToken() override external view returns(IERC20) {
        return token;
    }


    /**
     * @dev Initialize the exchange and seed the liquidity pool. Callable only once, only by
     * the deployer. Pulls `initialTOK` tokens (must be approved first) and takes `initialETH`
     * from the ETH sent, refunding any excess. The deployer receives `initialTOK` liquidity
     * tokens (the initial LQT supply is defined as the initial token reserve).
     */
    function initialize(IERC20 _RUXtoken, uint8 _feePercent, uint initialTOK, uint initialETH) override public payable returns(uint) {
        require(msg.sender == deployer, "RUExchange: only deployer can initialize");
        require(!initialized, "RUExchange: already initialized");
        require(_feePercent < 100, "RUExchange: fee must be below 100");
        require(msg.value >= initialETH, "RUExchange: insufficient ETH sent");

        // Effects: record configuration and mint the initial liquidity tokens to the deployer.
        initialized = true;
        token = _RUXtoken;
        feePercent = _feePercent;
        _totalSupply = initialTOK;
        balances[msg.sender] = initialTOK;
        emit Transfer(address(0), msg.sender, initialTOK);

        // Interactions: pull the initial tokens into the pool, then refund any excess ETH.
        require(_RUXtoken.transferFrom(msg.sender, address(this), initialTOK), "RUExchange: token transfer failed");
        uint refund = msg.value - initialETH;
        if (refund > 0) {
            (bool ok, ) = msg.sender.call{value: refund}("");
            require(ok, "RUExchange: refund failed");
        }

        return initialTOK;
    }


    /**
     * @dev Swap ETH for tokens.
     * Buy `amount` tokens as long as the total price is at most `maxPrice`. revert if this is impossible.
     * Note that the fee is taken in *both* tokens and ETH. The fee percentage is taken from `amount` tokens 
     * (rounded up) *after* they are bought, and taken from the ETH sent (rounded up) *before* the purchase.
     * @return Returns the actual total cost in ETH including fee.
     */
    function buyTokens(uint amount, uint maxPrice) override public payable returns (uint,uint,uint) {
        uint poolTOK = token.balanceOf(address(this));
        uint poolETH = address(this).balance - msg.value;   // exclude the ETH just sent

        // ETH that must enter the pool to release `amount` tokens, keeping the product
        // constant: (poolTOK - amount) * (poolETH + tradedEth) >= poolTOK * poolETH.
        // Round up so the invariant never drops in the pool's favor.
        uint tradedEth = ceilDiv(poolETH * amount, poolTOK - amount);

        // The ETH fee is taken from the payment *before* the trade: gross up the traded
        // amount so that, after removing the fee, `tradedEth` remains for the pool.
        uint actualPayment = ceilDiv(tradedEth * 100, 100 - feePercent);
        uint ethFee = actualPayment - tradedEth;

        // The token fee is taken from `amount` *after* the trade; the buyer keeps the rest.
        uint tokenFee = ceilDiv(amount * feePercent, 100);

        require(actualPayment <= maxPrice, "RUExchange: price exceeds maxPrice");
        require(msg.value >= actualPayment, "RUExchange: insufficient ETH sent");

        // Interactions: send the bought tokens (net of fee) and refund the excess ETH.
        // The pool keeps `actualPayment` ETH and the token fee; the constant-product
        // reserves are what remain once both fees are set aside.
        require(token.transfer(msg.sender, amount - tokenFee), "RUExchange: token transfer failed");
        uint refund = msg.value - actualPayment;
        if (refund > 0) {
            (bool ok, ) = msg.sender.call{value: refund}("");
            require(ok, "RUExchange: refund failed");
        }

        emit FeeDetails(actualPayment, ethFee, tokenFee);
        return (actualPayment, ethFee, tokenFee);
    }

    /**
     * @dev Swap tokens for ETH
     * Sell `amount` tokens as long as the total price is at least `minPrice`. revert if this is impossible.
     * Note that the fee is taken in *both* tokens and ETH. The fee percentage is taken from `amount` tokens 
     * (rounded up) *before* selling, and taken from the ETH returned (rounded up) *after* selling.
     * @return Returns a tuple with the actual total value in ETH minus the fee, the eth fee and the token fee.
     */
    function sellTokens(uint amount, uint minPrice) override public returns (uint, uint, uint) {
        uint poolTOK = token.balanceOf(address(this));
        uint poolETH = address(this).balance;

        // The token fee is taken from `amount` *before* the trade; only the rest is sold.
        uint tokenFee = ceilDiv(amount * feePercent, 100);
        uint tradedTokens = amount - tokenFee;

        // ETH the pool releases for the sold tokens, keeping the product constant:
        // (poolTOK + tradedTokens) * (poolETH - grossEth) >= poolTOK * poolETH.
        // Round down so the invariant never drops in the pool's favor.
        uint grossEth = (poolETH * tradedTokens) / (poolTOK + tradedTokens);

        // The ETH fee is taken from the ETH returned *after* the trade.
        uint ethFee = ceilDiv(grossEth * feePercent, 100);
        uint actualPayment = grossEth - ethFee;

        require(actualPayment >= minPrice, "RUExchange: price below minPrice");

        // Interactions: pull all `amount` tokens (trade + fee), then pay the seller.
        require(token.transferFrom(msg.sender, address(this), amount), "RUExchange: token transfer failed");
        (bool ok, ) = msg.sender.call{value: actualPayment}("");
        require(ok, "RUExchange: ETH payout failed");

        emit FeeDetails(actualPayment, ethFee, tokenFee);
        return (actualPayment, ethFee, tokenFee);
    }

    /**
     * Returns the current number of tokens in the liquidity pool.
     * Read live from the token contract, so it always includes accumulated fees.
     */
    function tokenBalance() external view returns(uint) {
        return token.balanceOf(address(this));
    }

    
    /**
     * @dev mint `amount` liquidity tokens, as long as the total number of tokens spent is at most `maxTOK`
     * and the total amount of ETH spent is `maxETH`. The token allowance for the exchange address must be at least `maxTOK`,
     * and the msg value at least `maxETH`.
     * Unused funds will be returned to the sender.
     * @return returns a tuple consisting of (token_spent, eth_spent). 
     */
    function mintLiquidityTokens(uint amount, uint maxTOK, uint maxETH) public payable returns (uint,uint) {
        require(msg.value >= maxETH, "RUExchange: insufficient ETH sent");

        // Deposit tokens and ETH in the current pool ratio. Round up so the pool never
        // loses value: numTOK = ceil(pool_tokens * amount / totalLQT), likewise for ETH.
        uint poolTOK = token.balanceOf(address(this));
        uint poolETH = address(this).balance - msg.value;   // exclude the ETH just sent
        uint numTOK = ceilDiv(poolTOK * amount, _totalSupply);
        uint numETH = ceilDiv(poolETH * amount, _totalSupply);

        require(numTOK <= maxTOK, "RUExchange: needs more tokens than maxTOK");
        require(numETH <= maxETH, "RUExchange: needs more ETH than maxETH");

        // Effects: mint the new liquidity tokens to the caller.
        _totalSupply += amount;
        balances[msg.sender] += amount;
        emit Transfer(address(0), msg.sender, amount);

        // Interactions: pull the deposited tokens, refund the unused ETH.
        require(token.transferFrom(msg.sender, address(this), numTOK), "RUExchange: token transfer failed");
        uint refund = msg.value - numETH;
        if (refund > 0) {
            (bool ok, ) = msg.sender.call{value: refund}("");
            require(ok, "RUExchange: refund failed");
        }

        emit MintBurnDetails(numTOK, numETH);
        return (numTOK, numETH);
    }

    /**
     * @dev burn `amount` liquidity tokens, as long as this will result in at least minTOK tokens and at least minETH eth being generated.
     * The resulting tokens and ETH will be credited to the sender.
     * @return Returns a tuple consisting of (token_credited, eth_credited). 
     */
    function burnLiquidityTokens(uint amount, uint minTOK, uint minETH) override public payable returns (uint,uint) {
        require(balances[msg.sender] >= amount, "RUExchange: burn exceeds balance");

        // Return the caller's pool share. Round down so the pool never loses value:
        // numTOK = floor(pool_tokens * amount / totalLQT), likewise for ETH.
        uint numTOK = (token.balanceOf(address(this)) * amount) / _totalSupply;
        uint numETH = (address(this).balance * amount) / _totalSupply;

        require(numTOK >= minTOK, "RUExchange: fewer tokens than minTOK");
        require(numETH >= minETH, "RUExchange: less ETH than minETH");

        // Effects: burn the liquidity tokens before sending anything out.
        _totalSupply -= amount;
        balances[msg.sender] -= amount;
        emit Transfer(msg.sender, address(0), amount);

        // Interactions: send the tokens and ETH to the caller.
        require(token.transfer(msg.sender, numTOK), "RUExchange: token transfer failed");
        (bool ok, ) = msg.sender.call{value: numETH}("");
        require(ok, "RUExchange: ETH payout failed");

        emit MintBurnDetails(numTOK, numETH);
        return (numTOK, numETH);
    }
    
     /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return balances[account];
    }


    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        require(recipient != address(0), "RUExchange: transfer to zero address");
        require(balances[msg.sender] >= amount, "RUExchange: transfer exceeds balance");

        balances[msg.sender] -= amount;
        balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view override returns (uint256) {
        return allowances[owner][spender];
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
        require(spender != address(0), "RUExchange: approve to zero address");

        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
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
        require(recipient != address(0), "RUExchange: transfer to zero address");
        require(allowances[sender][msg.sender] >= amount, "RUExchange: insufficient allowance");
        require(balances[sender] >= amount, "RUExchange: transfer exceeds balance");

        // Spend the caller's allowance, then move the tokens.
        allowances[sender][msg.sender] -= amount;
        balances[sender] -= amount;
        balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    /**
     * @dev Integer division rounded up: ceil(a / b). Used so fees and pool deposits
     * round in the exchange's favor. Assumes b > 0.
     */
    function ceilDiv(uint a, uint b) private pure returns (uint) {
        return (a + b - 1) / b;
    }

}
