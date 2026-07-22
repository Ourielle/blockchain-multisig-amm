from typing import Tuple
from eth_keys import KeyAPI
from eth_keys.backends import NativeECCBackend
from eth_utils import keccak
from ape import project

RUToken = project.RUToken

#return the raw 20 bytes of an address, accepting either an account/contracr
#object (which exposes '.address') or a plain hex-string address
def _address_bytes(a) -> bytes:
    s = a.address if hasattr(a, "address") else str(a)
    return bytes.fromhex(s[2:] if s.startswith("0x") else s)


grade_multisig = True # Change this to true if you implemented the multisig token.

keys =  KeyAPI(NativeECCBackend)

class Signature:
    def __init__(self, r: bytes, s: bytes, v: int) -> None:
        self.r = r
        self.s = s
        self.v = v

    # Encode as a tuple suitable for passing as solidity calldata.
    def encoded(self) -> Tuple[bytes, bytes, int]:
        return (self.r, self.s, self.v + 27) # Add 27 to v just because Bitcoin developers decided to use an arbitrary number, and the Ethereum developers copied them.


# This function should return a nonce and a signature 
# that can be passed to transfer2of3.
# Note: The function should *not* change state in any way (e.g., if you call contract methods, call only `view` and `pure` methods`)).
def generate_nonce_and_second_signature_transfer2of3(tok: RUToken, sk, multisigAddr, spender, amount) -> Tuple[int,Signature]:
    key = keys.PrivateKey(bytes.fromhex(sk[2:])) # Can be used with `keys.ecdsa_sign``

    #read the multisig's current nonce (a view call, so no state is changed)
    nonce = tok.getNonce(multisigAddr)

    #rebuild byte for byte, the msg the contract hashes in transfer2of3:
    #keccak256(abi.encodePacked(address(this), multisigOwner, recipient, amount, nonce))
    # EncodePacked lays out each address as 20 bytes and each uinit256 as 32 big endian bytes.
    message = ( #address(this) - 20 bytes
        _address_bytes(tok) + 
        _address_bytes(multisigAddr) #multisigOwner - 20 bytes
        + _address_bytes(spender) #recipient - 20 bytes
        + int(amount).to_bytes(32, "big") #amount - 32 bytes
        + int(nonce).to_bytes(32, "big") #nonce - 32 bytes
        )
    messageHash = keccak(message)

    #sign the raw hash (ecdsa_sign signs the 32 byte digest directly, matching ecrecover)
    sig = keys.ecdsa_sign(messageHash, key)
    return (nonce, Signature(sig.r.to_bytes(32, "big"), sig.s.to_bytes(32, "big"), sig.v))
    


