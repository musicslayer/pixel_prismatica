# Pixel Prismatica NFT Smart Contract
The smart contract for the Pixel Prismatica NFT.<br/><br/>
To purchase or interact with the NFTs, visit the dapp here:<br/>
https://musicslayer.github.io/pixel_prismatica_dapp/

## Summary
Pixel Prismatica is a collection of configurable NFT tokens featuring on-chain animated pixel art.

## Sample Image
![](sample.svg)

## Features
### Capped
Only 100 NFTs can be minted per network.

### Uniqueness
No two NFTs are exactly the same. The animation pattern of each NFT is pseudorandomly calculated based on the EVM Chain ID and the NFT ID.

### On-chain
Unlike other NFTs that merely link to an image, this NFT generates the image data within its smart contract. This means that it is not reliant on any third-party file hosting service. As long as the blockchain persists, no one can take your NFT image away from you.

### Configurable
Every NFT image is an animated pixel art SVG that can be configured from the following options:
- 12 color modes
- 4 animation settings
- 3 image sizes

You choose an initial configuration upon minting, and then you can reconfigure it at will for the cost of blockchain transactions only.<br/><br/>
(Some NFT wallets/marketplaces require you to manually refresh the metadata before any changes are reflected.)

## Minting Costs
The first NFT of each network's collection will have an initial minting fee. That fee will increase with each minting.

## Royalties
Each NFT provides the creator with a 3% royalty whenever it is sold on a marketplace supporting ERC-2981.

## Contract
The NFT contract is currently deployed on the following networks:<br/>
Ethereum: [0x35A90f051B482958b5C8d98679adC9871Ed31551](https://etherscan.io/address/0x35A90f051B482958b5C8d98679adC9871Ed31551)<br/>
Binance Smart Chain: [0x35A90f051B482958b5C8d98679adC9871Ed31551](https://bscscan.com/address/0x35A90f051B482958b5C8d98679adC9871Ed31551)

Some properties of the contract:
- The contract has an owner address.
- The contract is an ERC1155 non-fungible token.
- The contract has certain fail-safes built into it:
  - ERC20, ERC721, ERC777, and ERC1155 tokens, as well as native coins, can be withdrawn from the contract by the owner.
  - The owner can disable the reentrancy lock if the contract is in an unanticipated state.
  - A new owner must claim ownership before the transfer of ownership is complete (i.e. you cannot accidentally give ownership to an invalid address).
