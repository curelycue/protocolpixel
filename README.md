# pixelDAO

Pixel DAO aims to facilitate PartyBid-style collective ownership of Nouns.
This repo contains v1 of the protocol.

### Architecture

```
// Main treasury and governance controller. Funds and Nouns go here.
PixelTreasury

// Generic governance. Controlled by PixelTreasury.
PixelGovernor

// ERC20 governance token with added voting capabilities.
Pixel

// Party-buy Nouns
NounAsks.sol
```

# nounAsks Mechanics

There are two main ways that NounAsks enables Pixel DAO to acquire a Noun: 
- A Noun owner owner can call `swapNoun` to immediately transfer their Noun to the DAO and receive 1000 PIXEL. 
- A Noun owner can call `createAsk` to list their Noun for sale. The owner asks for a certain ETH:PIXEL rate as well as some amount of PIXEL. If it is approved by governance, then anybody can contribute to filling the ask, and ultimately the DAO acquires the Noun and distributes a total of 1000 PIXEL to the owner and contributors.


 
Note that a Noun owner that transfers their Noun to Pixel DAO via NounAsks *can not* automatically get their Noun back. Once Pixel DAO owns it, it's up to the DAO what they do with the Noun. The motivation for the project was for the DAO to vote on NounsDAO proposals with their Nouns in perpetuity.

For example: @4156 owns Noun #3 and values it at 1000 ETH. He wants to sell it, but he also wants to retain some NounsDAO voting power. He can call `createAsk(0, 1*10**18, 100*10**18)` meaning he would like to sell Noun #3 at 1 ETH per PIXEL, and he wants 100 PIXEL for himself. If governance approves this ask, then there will be a "PartyBuy" with 900 unallocated ETH remaining. Anybody can contribute until 900 ETH is hit. When the asking price is hit, Alice receives 900 ETH and 100 PIXEL, the DAO receives the Noun, and the contributors can claim their fair share of the remaining 900 PIXEL.


# Governance and NounsDAO Proposals
The governance system uses standard general-purpose openzeppelin governance contracts, so it is battle-tested and compatible with tools like Tally. In the interest of minimizing transaction fees, the DAO should do snapshot votes for each Nouns proposal to get a yes/no answer, and then a proposer can propose an onchain transaction which would submit that winning answer to NounsDAO contract on behalf of each Noun owned by the treasury.


# Token
There is a fixed supply of 110,000 PIXEL (enough to accommodate 100 Nouns) - 1000 PIXEL for each Noun and 10% intended for team, incentives, airdrops and grants. Only NounAsks will be able to distribute any of the PIXEL, so the vast majority of it will be locked for the foreseeable future. The DAO will likely lock the remaining 10% in a long-term vesting contract to ensure proper incentives.


*But much more still TBD *
