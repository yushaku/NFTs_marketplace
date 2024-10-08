# Politcate NFT and fungible token

![polite cat](https://m.media-amazon.com/images/I/41Ig3RzfNiL._SR600%2C315_PIWhiteStrip%2CBottomLeft%2C0%2C35_SCLZZZZZZZ_FMpng_BG255%2C255%2C255.jpg)

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

## 🚀 Features of NFTs Marketplace

- 🔨 Create a new ERC721 collection.
- ⛽ Support setting royalty fees.
- ⭐ Sell (list item) NFT on the marketplace.
- 🌟 Offer listed items on the marketplace.
- ✨ Accept an offer on the marketplace.
- 💥 Create an auction on the marketplace.
- 🔥 Bid place to auction.
- 🏰 (Marketplace owner) Support set and update payable token, platform fee.

- user 1 **list** nft --> user 2 buy nft

- user 1 **list** nft

  ------------------> user 2 offer

  ------------------> user 3 offer

  ------------------> user 4 offer

  ======================================> user 1 accept offer

- user 1 create **auction**

  ----------------------> user 2 bid

  ----------------------> user 3 bid

  ----------------------> user 4 bid

  ===================================> user 1 pick a highest bid
