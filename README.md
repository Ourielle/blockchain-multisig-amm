# Final project for Blockchains and Cryptocurrencies Course - Reichman University 

## Overview

Contributors & Collaboration

This project was jointly developed by Ourielle Aviram and Nadav Meroz as part of the Blockchains & Cryptocurrencies course at Reichman University.

We worked closely throughout the project, collaborating on system design, implementation, debugging, and testing. Much of the development was carried out through pair programming and joint problem-solving sessions.

In this project we implemented an ERC20 Token, and a multisig extension to the token API. 
The project is written in Solidity, with a little bit of python for the client side of the multisig extension. 

## ERC20 Token

The interface implemented -  `interfaces/IERC20.sol` (taken from the OpenZeppelin project). 

## Multisig Extension

"multisig" extension to the ERC20 token. The idea of this extension is to define a new type of "2-out-of-3" multisig address, which are defined by *three* public keys. In order to transfer tokens from a multisig address, *two* of the three public-key owners must sign the transfer transaction. 

The Multisig API captures this by adding three functions to the token API. The first two are used to define a multisig address based on the three public keys. The multisig address should be defined completely by the three public keys. Given three standard public-key-based addresses `pk1`,`pk2`,`pk3`, the function `getMultisigAddress` should return the corresponding multisig address.  Since the multisig address doesn't contain enough information to recover the actual public keys, it must be registered before using it by calling `registerMultisigAddress`. 

`transfer2of3` function -  which is used to transfer tokens from a multisig address (tokens can to transferred *to* a multisig addresss using the standard token functions). This function accepts, in addition to the multisig source address, the destination and the amount to transfer, two "special" arguments:

* `uint nonce` --- this is a nonce value used to prevent "replay" attacks (see below).
* `Signature calldata secondSig` --- This is a second signature on the transfer transaction (in addition to the transaction sender's signature that's verified implicitly by ethereum). 

The `Signature` type is defined in `IMultisigToken.sol`, as a struct containing three elements: `r`, `s` and `v` (see [here](https://en.bitcoin.it/wiki/Elliptic_Curve_Digital_Signature_Algorithm) for information about ECDSA signatures; the `v` element is used to recover the public key from the signature and message).

### Client code

The implementation of the multisig extension also includes implementing client-side code in python that is used to generate the 2-out-of-3 transactions (this can't be done on the blockchain, because it must involve the secret signing keys).  `generate_nonce_and_second_signature_transfer2of3` function  - in `scripts/multisig_token.py`. This function accepts a  reference to a "live" contract instance `tok`, the secret signing key `sk`, encoded as a hex string with a `0x` prefix.

This function should return a tuple containing the *nonce* and the *signature* to be used when constructing the `transfer2of3` transaction. 

### Replay attacks

multisig token should be resistant to *replay* attacks, in which an honestly-generated transaction is used by an attacker to transfer money that would not be authorized. 
* Simple replay: sending the same transaction data (i.e., source, destination, amount, and secondSig).
* Repurposing signature replay: sending modified data, but reusing a previous secondSig.
* Cross-contract replay: using a signature from one token contract instance to transfer tokens in a different contract instance. In all of these cases, the transaction should fail.


## AMM Token Exchange

Uniswap-like token exchange. The exchange contract only handles trading ERC20 tokens for ETH and back (not tokens for tokens), and uses the AMM rule: in each swap, the product of the exchange's token blance and ETH balance should remain constant. 

The exchange supports the following operations:

* Initialization: this can only be done by the sender that deployed the contract. It sets the contract's underlying ERC20 Token, the fee (in percentage of each trade)   and the initial supply of tokens and ETH. The initial supply tokens is transferred to the exchange using `transferFrom`, so should be approved by the sender before calling `initialize`.
* Buying tokens: In this case, the maximum payment amount is given as a parameter --- if more payment is required to buy the given amount of tokens, the transaction should fail.
* Selling tokens: In this case, the minimum sale price is given as a parameter --- if total sale would result in less than this price, the transaction should fail.
* Minting liquidity tokens: In this case, the caller should deposit both tokens and ETH in the liquidity pool in return for liquidity tokens. The caller defines the maxmimum amount of tokens/ETH that they are willing to pay for the requested number of liquidity tokens. The amount of tokens/ETH actually paid should maintain the existing ratio, and the minted liquidity tokens should reflect the fraction of the total liquidity pool that the newly added tokens/ETH provide.
* Burning liquidity tokens: In this case, the caller's liquidity tokens are burned (the total supply of liquidity tokens contracts), and the corresponding fraction of the liquidity pool (in both tokens and ETH) is returned to the caller. The caller specifies the minimum amount of tokens/ETH for this exchange; below this amount the transaction should fail.

In addition to the "exchange-specific" operations, the exchange should support all the standard ERC20 operations when acting as the liquidity token. Thus, it must also implement the `IERC20` interface.

### Fees

When buying an selling tokens, the exchange can charge a fee (if the `feePercent` parameter given to `initialize` is non-zero). In this case, the fee is always taken from both the tokens and the ETH involved. When buying, the fee is taken from the ETH paid *before it is traded*, and from the tokens *after the trade occurs*. When selling, the fee is taken from the tokens before the trade occurs, and from the ETH after the trade. The AMM maintains the constant token/eth product for a trade *before the fees are deposited*. 

For example, if a transaction is selling 2 tokens, and the exchange liquidity consists of 10 tokens and 99 ETH before the transaction is processed, with a fee of 50 percent, the exchange first takes 1 token as fee, then "sells" one token for 9 ETH (this, the product before the transaction is 10x99=990, and after is 11x90 = 990, maintaining the constant). Finally, it takes 5 ETH as a fee (50% of 9, rounded up), and deposits the 5 ETH and 1 token in the liquidity pool. So the exchange ends up with 12 tokens and 95 ETH, and the seller receives 4 ETH. 

The amounts should be as close as possible up to rounding (since the amounts all have to be integers, we allow the constant product invariant to be violated due to rounding errors).




## Running Tests and Debugging

If you have python 3 installed and the `python3` binary is in your path, running `setup.sh` should install a python venv with ape. To use it, run (on a bash prompt)

    . venv/bin/activate
    ape test

You can also install a python virtual environment in an IDE and use the `requirements.txt` file to install ape. Once ape is installed, you can compile and test your code by running `ape test` in the project root directly. 


### Installing Ape Using Docker

Instead of installing ape locally, you can use the docker compose environment to run tests. To do this:

* Run `docker compose build` in the project root directory
* Run `docker compose up -d` to start the foundry container (this container runs a test ethereum node that listens on port 8545).
* Run `docker compose run ape-console` to get a bash prompt. You can run `ape compile` at the prompt compile your solidity code, `ape test` to run tests, or `ape console` to open a python console.

Running `docker compose run test` will do the same thing as running the `ape-console` service and then `ape test` on the command line.

**Note**: Inside the docker container, ape uses a different configuration file: `ape/ape-config-foundry.yaml`. 

