pragma solidity ^0.8.10;

import "../interfaces/IPrimaryMarket.sol";

contract PrimaryMarket is IPrimaryMarket{
    /**
    * The primary market is the first point of sale for tickets.
    * It is responsible for minting tickets and transferring them to the purchaser.
    * The NFT to be minted is an implementation of the ITicketNFT interface and should be created (i.e. deployed)
    * when a new event NFT collection is created
    * In this implementation, the purchase price and the maximum number of tickets
    * is set when an event NFT collection is created
    * The purchase token is an ERC20 token that is specified when the contract is deployed.
    */
    function createNewEvent(
        string memory eventName,
        uint256 price,
        uint256 maxNumberOfTickets
    ) external returns (ITicketNFT ticketCollection){

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

    }
}