// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "./interfaces/IERC20.sol";
import "./interfaces/IMultisigToken.sol";


/**
 * @dev An implementation of the ERC20 standard for a "Reichman University" Token.
 */
contract RUToken is IERC20, IERC20Metadata, IMultisigToken {


    //a registered 2 out of 3 multisig account: the three controlling public
    //keys and a per account nonce that makes each transfer2of3 single use
    struct Multisig {
        address pk1;
        address pk2;
        address pk3;
        uint nonce;
    }
    // registered multisig accounts, keyed by their derived address.
    // an unregistered adress has all 0 keys (pk ==address(0))
    mapping(address => Multisig) private multisigs;
    /**
     * Maximum number of mintable tokens.
     */
    uint public maxTokens;

    /**
     * Price required to mint a token in ETH
     */
    uint public tokenPrice;

    // Core ERC20 ledger: how many tokens each account holds.
    mapping(address => uint256) private balances;

    // Delegated spending limits: allowances[owner][spender] is how much `spender` may move on `owner`'s behalf via transferFrom.
    mapping(address => mapping(address => uint256)) private allowances;

    // Total number of tokens currently in existence.
    uint256 private _totalSupply;


    constructor(uint _tokenPrice, uint _maxTokens) {
        tokenPrice = _tokenPrice;
        maxTokens = _maxTokens;
    }

    /**
    * @dev Returns the decimals places of the token.
    */
    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function name() public pure override returns (string memory) {
        return "Reichman U Token";
    }

    function symbol() public pure override returns (string memory) {
        return "RUX";
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
        require(recipient != address(0), "RUToken: transfer to zero address");
        require(balances[msg.sender] >= amount, "RUToken: transfer exceeds balance");

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
        require(spender != address(0), "RUToken: approve to zero address");

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
        require(recipient != address(0), "RUToken: transfer to zero address");
        require(allowances[sender][msg.sender] >= amount, "RUToken: insufficient allowance");
        require(balances[sender] >= amount, "RUToken: transfer exceeds balance");

        // Spend the caller's allowance, then move the tokens.
        allowances[sender][msg.sender] -= amount;
        balances[sender] -= amount;
        balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    /**
     * @dev Mint new tokens by paying ETH.
     * The number of tokens minted is `msg.value / tokenPrice` (integer division).
     * Any remainder that does not buy a whole token is refunded to the caller,
     * so the contract keeps exactly `minted * tokenPrice` and never traps value.
     * Reverts if minting would push the total supply above `maxTokens`.
     */
    function mint() public payable returns (uint) {
        uint minted = msg.value / tokenPrice;
        require(_totalSupply + minted <= maxTokens, "RUToken: max supply exceeded");

        // Effects: create the tokens before any external call (checks-effects-interactions).
        _totalSupply += minted;
        balances[msg.sender] += minted;
        emit Transfer(address(0), msg.sender, minted);

        // Interaction: refund the leftover wei that didn't buy a whole token.
        uint refund = msg.value - minted * tokenPrice;
        if (refund > 0) {
            (bool ok, ) = msg.sender.call{value: refund}("");
            require(ok, "RUToken: refund failed");
        }

        return minted;
    }

    /**
     * Burn `amount` tokens. The corresponding value (`tokenPrice` for each token) is sent to the caller.
     */
    function burn(uint amount) public {
        require(balances[msg.sender] >= amount, "RUToken: burn exceeds balance");

        // Effects: destroy the tokens before sending ETH (checks-effects-interactions).
        balances[msg.sender] -= amount;
        _totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);

        // Interaction: pay back the ETH that backed the burned tokens.
        (bool ok, ) = msg.sender.call{value: amount * tokenPrice}("");
        require(ok, "RUToken: ETH payout failed");
    }

    //2 out of 3 multisig extension
    /**
    *@dev returns adress controlled by public keys 'pk1', 'pk2', 'pk3'.
    *the address is the low 20 bytes of the keccak256 hash of the 3 keys. 
    *keccak256 is collision resistant so no other set of keys yield this address. 
    */
    function getMultisigAddress(address pk1, address pk2, address pk3) public pure override returns (address){
        return address(uint160(uint256(keccak256(abi.encodePacked(pk1, pk2, pk3)))));
    }
    /**
    *@dev registers a multisig account controlled by 'pk1', 'pk2', 'pk3' and returns its address. 
    *registration is required because the address alone (a hash) doesn't reveal the keys the contract later needs to verify signatures. 
    *each account can be registered only once. 
    */
    function registerMultisigAddress(address pk1, address pk2, address pk3) external override returns (address){
        //validate the keys: non zero and pairwise distinct so a genuine 2 of 3
        //always requires 2 different people
        require(pk1 != address(0) && pk2 != address(0) && pk3 != address(0), "RUToken:zero multisig key");
        require(pk1 != pk2 && pk1 != pk3 && pk2 != pk3, "RUToken: duplicate multisig key");
        
        address multisigAddr = getMultisigAddress(pk1, pk2, pk3); 
        require(multisigs[multisigAddr].pk1 == address(0), "RUToken: multisig already registered");

        multisigs[multisigAddr] = Multisig(pk1, pk2, pk3, 0);
        return multisigAddr;
    }
    /**
    *@dev returns the current transfer2of3 nonce for a registered multisig account. 
    *used by the off chain client to build the msg the second singer approves. 
    */
    function getNonce(address multisigOwner) external view returns (uint) {
        return multisigs[multisigOwner].nonce;
    }

    /**
    *@dev moves 'amount' tokens from the multisig account 'multisigOwner' to 'recipient'
    * authorized by 2 of its three controlling keys.
    *the first singer is 'msg.sender' (authenticated by ethereum itself). 
    * the second singer approves off chain nu singing the msg below 'secondSig' is that signature
    *The signed msg binds this contract, the source, the destination, the amount and the none so a signature cannot be replayed accross contracts, transfers, or transaction fields
    *the per account nonce makes each approval single use. 
    */
    function transfer2of3(address multisigOwner, address recipient, uint256 amount, uint nonce, Signature calldata secondSig) external override returns (bool) {
        require(recipient != address(0), "RUToken:transfer to zero address");
        Multisig storage ms = multisigs[multisigOwner];
        require(ms.pk1 != address(0), "RUToken: multisig not registered");

        //first singer: the transaction sender must be one of the three controllers.
        require(isController(ms, msg.sender), "RUToken:sender not a controller");

        //the nonce must match account's curr nonce (blocks replayed transfers). 
        require(nonce == ms.nonce, "RUToken: bad nonce");

        //reconver the second singer from their signature over the bound message. 
        //address(this) + multisigOwner + recipient + amount + nonce are all bound in -
        // so the signature is useless on another contract/transfer/set of fields
        bytes32 messageHash = keccak256(abi.encodePacked(address(this), multisigOwner, recipient, amount, nonce));
        address secondSigner = ecrecover(messageHash, secondSig.v, secondSig.r, secondSig.s);

        //second signer : a controller, and a different one than the sender that is the 2 of 3
        require(isController(ms, secondSigner), "RUToken: second signer not a controller"); 
        require(secondSigner != msg.sender, "RUToken: need two distinct signers"); 
        require(balances[multisigOwner] >= amount, "RUToken: transfer exceeds balance");

        //effects: consume the none and move the tokens before returning
        ms.nonce += 1;
        balances[multisigOwner] -= amount;
        balances[recipient] += amount;
        emit Transfer(multisigOwner, recipient, amount);
        return true;

    }

    /**
    *@dev returns true if account is one of the three jeys controlling multisig ms
    */
    function isController(Multisig storage ms, address account) private view returns (bool) {
        return account == ms.pk1 || account == ms.pk2 || account ==ms.pk3;
    }


}
