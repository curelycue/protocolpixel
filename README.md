# Pixel Protocol

Pixel Protocol aims to facilitate PartyBid-style collective ownership of Nouns.


### Architecture

```
// Main treasury and governance controller. Funds and Nouns go here.
PixelTreasury

// Generic governance. Controlled by PixelTreasury.
PixelGovernor

// ERC20 governance token with added voting capabilities.
Pixel

// Party-buy Nouns
NounsAsks.sol
```

# NounAsks Mechanics

There are two main ways that NounAsks enables Pixel DAO to acquire a Noun: 
- A Noun owner owner can call `swapNoun` to immediately transfer their Noun to the DAO and receive 1000 PIXEL. 
- A Noun owner can call `createAsk` to list their Noun for sale. The owner asks for a certain ETH:PIXEL rate as well as some amount of PIXEL. If it is approved by governance, then anybody can contribute to filling the ask, and ultimately the DAO acquires the Noun and distributes a total of 1000 PIXEL to the owner and contributors.

# Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```
