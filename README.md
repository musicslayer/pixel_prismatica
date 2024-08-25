# Pixel Prismatica NFT Smart Contracts
The smart contracts for the Pixel Prismatica NFT.<br/><br/>
To purchase/interact with the NFTs, visit the dapp here:<br/>
https://musicslayer.github.io/pixel_prismatica_dapp/

## Summary
Pixel Prismatica is a collection of configurable NFT tokens featuring animated pixel art, capped at 100 per network.<br/>
The animation pattern of each NFT is pseudorandomly calculated based on the EVM Chain ID and the NFT ID, so no two NFTs are exactly the same.

## Features
- Unlike other NFTs that merely link to an image, this NFT generates the image data within its smart contract. This means that it is not reliant on any third-party file hosting service. As long as the blockchain persists, no one can take your NFT image away from you.
- Every NFT image is an animated pixel art PNG that can be configured as follows:
  - 12 different color modes
  - 4 animation settings
  - 3 different image sizes

  You choose an initial configuration upon minting, and then you can reconfigure it at will for the cost of blockchain transactions only.

## Contracts
The NFT contract is currently deployed on the following networks:<br/>
Ethereum: [0x35A90f051B482958b5C8d98679adC9871Ed31551](https://etherscan.io/address/0x35A90f051B482958b5C8d98679adC9871Ed31551)<br/>
Binance Smart Chain: [0x35A90f051B482958b5C8d98679adC9871Ed31551](https://bscscan.com/address/0x35A90f051B482958b5C8d98679adC9871Ed31551)

## Minting & Configuration
When minting an NFT, the initial color mode, animation duration, and image size can be chosen. These can all be reconfigured later in the dapp.<br/>
Note that some NFT wallets/marketplaces require you to manually refresh the metadata before any changes are reflected.

## Costs & Royalties
The first NFT of each network's collection will have an initial minting fee. That fee will increase with each minting.<br/>
Each NFT provides the creator with a 3% royalty whenever it is sold on a marketplace supporting ERC-2981.
