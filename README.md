Ethers Wallet - iOS
===================

Ethers Wallet makes it simple to send, receive and manage your ether and interact with Ethereum Dapps (distributed applications) from standard Ethereum accounts.

**Features:**

- Import and export standard 12 word mnemonic phrases to and from other wallets
- Manage multiple accounts
- Accounts are encrypted and automatically synchronized across all devices via iCloud Keychain
- Scan QR codes with the camera or open saved pictures from the photo library
- Supports Ethers-enabled Ethereum Dapps

**Developer Features:**

- Full testnet (Ropsten) support
- Supports custom JSON-RPC nodes, for additional privacy or to use with private, consortium or alternate public blockchains
- Open Source (MIT licensed)
- To enable the developer features, after installing, click [https://ethers.io/app-link/#!debug](https://ethers.io/app-link/#!debug)

Build Instructions
==================

The Ethers Wallet iOS app is broken up into the Ethereum Library and the UI app repositories. You will need to download the code from both repositories to build the wallet. 


1. Download the code from both repositories:

   ```
   mkdir ethersWallet && cd ethersWallet
   git clone git@github.com:ethers-io/EthersWallet-ios.git
   git clone git@github.com:ethers-io/ethers.objc.git
   ```

2. The directory layout:

   ```
   ethersWallet
    ├── EthersWallet-ios        # The Wallet UI
    ├── ethers.objc             # The Ethereum Library

   ``` 

4. Build EthersWallet-ios using Xcode

To Do
=====

- Allow (and suggest based on EOA vs Contract) selecting gas limit
- Full Ethereum Dapp support
- Add injected Web3 API calls
- Import non-standard (and broken implementation) wallets (eg. Wrong BIP44 path, missing SHA512 padding bytes)
- Import Geth wallet (through ethers.io)
- Get Internal transactions working in the Transaction History
- Documentation, documentation, documentation

License
=======

MIT License.

Donations
=========

Everything is released under the MIT license, so these is **absolutely no need** to donate anything. If you would like to buy me a coffee though, I certainly won't complain. =)

- **Ethereum:** `0x00fC64443799AFB803FA209903f21671D85a6ABd`
- **Bitcoin:** `1FeT1mWc94jyfEimSdjhKkvYbF47J2K8Wf`
