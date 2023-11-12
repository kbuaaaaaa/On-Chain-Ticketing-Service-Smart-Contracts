pragma solidity ^0.8.10;

import "../interfaces/IPrimaryMarket.sol";
import "../contracts/TicketNFT.sol";
import "../contracts/PurchaseToken.sol";

contract PrimaryMarket is IPrimaryMarket{
    PurchaseToken private _purchaseToken;
    mapping(address => uint256) private _eventTicketPrice;

    constructor(PurchaseToken purchaseToken){
        _purchaseToken = purchaseToken;
    }

    /**
     *
     * @param eventName is the name of the event to create
     * @param price is the price of a single ticket for this event
     * @param maxNumberOfTickets is the maximum number of tickets that can be created for this event
     */
    function createNewEvent(
        string memory eventName,
        uint256 price,
        uint256 maxNumberOfTickets
    ) external returns (ITicketNFT ticketCollection){
        ITicketNFT currentTicketCollection = new TicketNFT(eventName, maxNumberOfTickets, msg.sender);
        _eventTicketPrice[address(currentTicketCollection)] = price;
        return currentTicketCollection;
    }

    /**
     * @notice Allows a user to purchase a ticket from `ticketCollectionNFT`
     * @dev Takes the initial NFT token holder's name as a string input
     * and transfers ERC20 tokens from the purchaser to the creator of the NFT collection
     * @param ticketCollection the collection from which to buy the ticket
     * @param holderName the name of the buyer
     * @return id of the purchased ticket
     */
    function purchase(
        address ticketCollection,
        string memory holderName
    ) external returns (uint256 id){
        TicketNFT ticketNFT = TicketNFT(ticketCollection);
        uint256 price = _eventTicketPrice[address(ticketCollection)];
        address creator = ticketNFT.creator();
        _purchaseToken.transferFrom(msg.sender, creator, price);
        return ticketNFT.mint(msg.sender, holderName);
    }

    /**
     * @param ticketCollection the collection from which to get the price
     * @return price of a ticket for the event associated with `ticketCollection`
     */
    function getPrice(
        address ticketCollection
    ) external view returns (uint256 price){
        return _eventTicketPrice[ticketCollection];
    }
}