// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract IKUSA is Ownable, ERC721A {
  struct SaleConfig {
    uint32 auctionSaleStartTime;
    bool privateSaleState;
    uint256 privateSalePrice;
    uint256 maxPerAddressDuringMint;
  }

  mapping(address => uint256) public numberOfMinted;

  SaleConfig public saleConfig;

  mapping(address => bool) public allowedList;

  constructor() ERC721A("IKUSA", "IKS", 100, 10000) {}

  modifier callerIsUser() {
    require(tx.origin == msg.sender, "The caller is another contract");
    _;
  }

  function whiteList(address[] memory accounts) public {
    for (uint256 index = 0; index < accounts.length; index++) {
      allowedList[accounts[index]] = true;
    }
  }

  function privateMint(uint256 quantity) external payable {
    // whitelisting
    require(allowedList[msg.sender], "Your Address is not WhiteListed");

    require(
      (totalSupply() + quantity) <= collectionSize,
      "Purchase would exceed max supply"
    );

    require(
      quantity + numberOfMinted[msg.sender] <=
        saleConfig.maxPerAddressDuringMint,
      "Cannot Mint More"
    );
    uint256 totalCost = saleConfig.privateSalePrice * quantity;

    require(msg.value >= totalCost, "Wrong Amount Sent");
    require(saleConfig.privateSaleState, "Sale Not Started");

    _safeMint(msg.sender, quantity);
    numberOfMinted[msg.sender] += quantity;
  }

  function auctionMint(uint256 quantity) external payable callerIsUser {
    require(
      (totalSupply() + quantity) <= collectionSize,
      "Purchase would exceed max supply"
    );
    uint256 _saleStartTime = uint256(saleConfig.auctionSaleStartTime);
    require(
      _saleStartTime != 0 && block.timestamp >= _saleStartTime,
      "sale has not started yet"
    );
    uint256 totalCost = getAuctionPrice(_saleStartTime) * quantity;
    _safeMint(msg.sender, quantity);
    refundIfOver(totalCost);
  }

  function refundIfOver(uint256 price) private {
    require(msg.value >= price, "Need to send more ETH.");
    if (msg.value > price) {
      payable(msg.sender).transfer(msg.value - price);
    }
  }

  uint256 public constant AUCTION_START_PRICE = 0.01 ether;
  uint256 public constant AUCTION_END_PRICE = 0.002 ether;
  uint256 public constant AUCTION_PRICE_CURVE_LENGTH = 5 minutes;
  uint256 public constant AUCTION_DROP_INTERVAL = 2 minutes;
  uint256 public constant AUCTION_DROP_PER_STEP =
    (AUCTION_START_PRICE - AUCTION_END_PRICE) /
      (AUCTION_PRICE_CURVE_LENGTH / AUCTION_DROP_INTERVAL);

  function getAuctionPrice(uint256 _saleStartTime)
    public
    view
    returns (uint256)
  {
    if (block.timestamp < _saleStartTime) {
      return AUCTION_START_PRICE;
    }
    if (block.timestamp - _saleStartTime >= AUCTION_PRICE_CURVE_LENGTH) {
      return AUCTION_END_PRICE;
    } else {
      uint256 steps = (block.timestamp - _saleStartTime) /
        AUCTION_DROP_INTERVAL;
      return AUCTION_START_PRICE - (steps * AUCTION_DROP_PER_STEP);
    }
  }

  function setAuctionSaleStartTime(uint32 timestamp) external onlyOwner {
    saleConfig.auctionSaleStartTime = timestamp;
  }

  function setPrivateDetails(
    bool _privateSaleState,
    uint256 _privateSalePrice,
    uint256 _maxPerAddressDuringMint
  ) external onlyOwner {
    saleConfig.privateSaleState = _privateSaleState;
    saleConfig.privateSalePrice = _privateSalePrice;
    saleConfig.maxPerAddressDuringMint = _maxPerAddressDuringMint;
  }

  // // metadata URI
  string private _baseTokenURI;

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function setBaseURI(string calldata baseURI) external onlyOwner {
    _baseTokenURI = baseURI;
  }

  function withdrawMoney() external onlyOwner {
    (bool success, ) = msg.sender.call{ value: address(this).balance }("");
    require(success, "Transfer failed.");
  }

  function setOwnersExplicit(uint256 quantity) external onlyOwner {
    _setOwnersExplicit(quantity);
  }

  function numberMinted(address owner) public view returns (uint256) {
    return _numberMinted(owner);
  }

  function getOwnershipData(uint256 tokenId)
    external
    view
    returns (TokenOwnership memory)
  {
    return ownershipOf(tokenId);
  }
}
