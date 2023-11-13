pragma solidity ^0.8.10;

import "../interfaces/ISecondaryMarket.sol";
import "../contracts/PurchaseToken.sol";
import "../contracts/TicketNFT.sol";

contract SecondaryMarket is ISecondaryMarket{
    struct ListingInformation{
        address lister;
        address highestBidder;
        string listerName;
        string highestBidderName;
        uint256 highestBid;
    }
    PurchaseToken private _purchasetoken;
    mapping(address => mapping(uint256 => ListingInformation)) private _listings;

    constructor(PurchaseToken purchaseToken){
        _purchasetoken = purchaseToken;
    }

   /**
     * @dev This method lists a ticket with `ticketID` for sale by transferring the ticket
     * such that it is held by this contract. Only the current owner of a specific
     * ticket is able to list that ticket on the secondary market. The purchase
     * `price` is specified in an amount of `PurchaseToken`.
     * Note: Only non-expired and unused tickets can be listed
     */
    function listTicket(
        address ticketCollection,
        uint256 ticketID,
        uint256 price
    ) external{
        TicketNFT ticketNFT = TicketNFT(ticketCollection);
        require(msg.sender == ticketNFT.holderOf(ticketID), "Only the holder of the ticket can list ticket");
        require(!ticketNFT.isExpiredOrUsed(ticketID), "Only non-expired and unused tickets can be listed");
        ticketNFT.transferFrom(msg.sender, address(this), ticketID);
        _listings[ticketCollection][ticketID] = ListingInformation(msg.sender, address(0), ticketNFT.holderNameOf(ticketID), "", price);
        emit Listing(msg.sender, ticketCollection, ticketID, price);
    }

    /** @notice This method allows the msg.sender to submit a bid for the ticket from `ticketCollection` with `ticketID`
     * The `bidAmount` should be kept in escrow by the contract until the bid is accepted, a higher bid is made,
     * or the ticket is delisted.
     * If this is not the first bid for this ticket, `bidAmount` must be strictly higher that the previous bid.
     * `name` gives the new name that should be stated on the ticket when it is purchased.
     * Note: Bid can only be made on non-expired and unused tickets
     */
    function submitBid(
        address ticketCollection,
        uint256 ticketID,
        uint256 bidAmount,
        string calldata name
    ) external{
        TicketNFT ticketNFT = TicketNFT(ticketCollection);
        require(!ticketNFT.isExpiredOrUsed(ticketID), "Bid can only be made on non-expired and unused tickets");
        if (bidAmount > _listings[ticketCollection][ticketID].highestBid){
            if (_listings[ticketCollection][ticketID].highestBidder != address(0)){
                address highestBidder = _listings[ticketCollection][ticketID].highestBidder;
                uint256 highestBid = _listings[ticketCollection][ticketID].highestBid;
                _purchasetoken.approve(highestBidder, highestBid);
                _purchasetoken.transfer(highestBidder, highestBid);
            }
            _listings[ticketCollection][ticketID].highestBidder = msg.sender;
            _listings[ticketCollection][ticketID].highestBid = bidAmount;
            _listings[ticketCollection][ticketID].highestBidderName = name;
            _purchasetoken.transferFrom(msg.sender, address(this), bidAmount);
        }
        emit BidSubmitted(msg.sender, ticketCollection, ticketID, bidAmount, name);
    }

    /**
     * Returns the current highest bid for the ticket from `ticketCollection` with `ticketID`
     */
    function getHighestBid(
        address ticketCollection,
        uint256 ticketId
    ) external view returns (uint256){
        return _listings[ticketCollection][ticketId].highestBid;
    }

    /**
     * Returns the current highest bidder for the ticket from `ticketCollection` with `ticketID`
     */
    function getHighestBidder(
        address ticketCollection,
        uint256 ticketId
    ) external view returns (address){
        return _listings[ticketCollection][ticketId].highestBidder;
    }

    /*
     * @notice Allow the lister of the ticket from `ticketCollection` with `ticketID` to accept the current highest bid.
     * This function reverts if there is currently no bid.
     * Otherwise, it should accept the highest bid, transfer the money to the lister of the ticket,
     * and transfer the ticket to the highest bidder after having set the ticket holder name appropriately.
     * A fee charged when the bid is accepted. The fee is charged on the bid amount.
     * The final amount that the lister of the ticket receives is the price
     * minus the fee. The fee should go to the creator of the `ticketCollection`.
     */
    function acceptBid(address ticketCollection, uint256 ticketID) external{
        require(msg.sender == _listings[ticketCollection][ticketID].lister, "Only the ticket lister can accept bid");
        require(_listings[ticketCollection][ticketID].highestBidder != address(0), "There is currently no bid");
        TicketNFT ticketNFT = TicketNFT(ticketCollection);
        address creator = ticketNFT.creator();
        address lister = _listings[ticketCollection][ticketID].lister;
        address highestBidder = _listings[ticketCollection][ticketID].highestBidder;
        string memory highestBidderName = _listings[ticketCollection][ticketID].highestBidderName;
        uint256 highestBid = _listings[ticketCollection][ticketID].highestBid;
        uint256 fee = highestBid * 5/100 ;
        uint256 finalPrice = highestBid - fee;
        _purchasetoken.approve(lister, finalPrice);
        _purchasetoken.transfer(lister, finalPrice);
        _purchasetoken.approve(creator, fee);
        _purchasetoken.transfer(creator, fee);
        ticketNFT.updateHolderName(ticketID, highestBidderName);
        ticketNFT.transferFrom(address(this), highestBidder, ticketID);
        delete _listings[ticketCollection][ticketID];
        emit BidAccepted(highestBidder, ticketCollection, ticketID, highestBid, highestBidderName);

    }

    /** @notice This method delists a previously listed ticket of `ticketCollection` with `ticketID`. Only the account that
     * listed the ticket may delist the ticket. The ticket should be transferred back
     * to msg.sender, i.e., the lister, and escrowed bid funds should be return to the bidder, if any.
     */
    function delistTicket(address ticketCollection, uint256 ticketID) external{
        require(msg.sender == _listings[ticketCollection][ticketID].lister, "Only the account that listed the ticket may delist the ticket");
        if (_listings[ticketCollection][ticketID].highestBidder != address(0)){
            address highestBidder = _listings[ticketCollection][ticketID].highestBidder;
            uint256 highestBid = _listings[ticketCollection][ticketID].highestBid;
            _purchasetoken.approve(highestBidder, highestBid);
            _purchasetoken.transfer(highestBidder, highestBid);
        }
        TicketNFT ticketNFT = TicketNFT(ticketCollection);
        ticketNFT.updateHolderName(ticketID, _listings[ticketCollection][ticketID].listerName);
        ticketNFT.transferFrom(address(this), _listings[ticketCollection][ticketID].lister, ticketID);
        delete _listings[ticketCollection][ticketID];
        emit Delisting(ticketCollection, ticketID);
    }
}