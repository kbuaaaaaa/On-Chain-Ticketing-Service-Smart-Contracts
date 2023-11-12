pragma solidity ^0.8.10;

import "../interfaces/ITicketNFT.sol";

contract TicketNFT is ITicketNFT{
    struct Ticket{
        address holder;
        string holderName;
        bool used;
        uint expiryDate;
        address approved;
    }
    string private _eventName;
    address private _primaryMarket;
    address private _creator;
    uint256 private _maxNumberOfTickets;
    uint256 private _id;
    mapping(uint256 => Ticket) private _tickets;
    mapping(address => uint256) private _balanceOf;

    constructor(string memory createEventName, uint256 createMaxNumberOfTickets, address eventCreator){
        _eventName = createEventName;
        _creator = eventCreator;
        _primaryMarket = msg.sender;
        _maxNumberOfTickets = createMaxNumberOfTickets;
        _id = 0;
    }

        /**
     * @dev Returns the address of the user who created the NFT collection
     * This is the address of the user who called `createNewEvent` in the primary market
     */
    function creator() external view returns (address){
        return _creator;
    }

    /**
     * @dev Returns the maximum number of tickets that can be minted for this event.
     */
    function maxNumberOfTickets() external view returns (uint256){
        return _maxNumberOfTickets;
    }

	/**
     * @dev Returns the name of the event for this TicketNFT
     */
    function eventName() external view returns (string memory){
        return _eventName;
    }

    /**
     * Mints a new ticket for `holder` with `holderName`.
     * The ticket must be assigned the following metadata:
     * - A unique ticket ID. Once a ticket has been used or expired, its ID should not be reallocated
     * - An expiry time of 10 days from the time of minting
     * - A boolean `used` flag set to false
     * On minting, a `Transfer` event should be emitted with `from` set to the zero address.
     *
     * Requirements:
     *
     * - The caller must be the primary market
     */
    function mint(address holder, string memory holderName) external returns (uint256 id){
        require(msg.sender == _primaryMarket, "The caller must be the primary market");
        require(id < _maxNumberOfTickets, "Maximum ticket number reached");
        uint256 curr_id = _id++;
        _tickets[curr_id] = Ticket(holder, holderName, false, block.timestamp + (10 * 86400), holder);
        _balanceOf[holder]++;
        emit Transfer(address(0), holder, curr_id);
        return curr_id;
    }

    /**
     * @dev Returns the number of tickets a `holder` has.
     */
    function balanceOf(address holder) external view returns (uint256 balance){
        return _balanceOf[holder];
    }

    /**
     * @dev Returns the address of the holder of the `ticketID` ticket.
     *
     * Requirements:
     *
     * - `ticketID` must exist.
     */
    function holderOf(uint256 ticketID) external view returns (address holder){
        require(ticketID < _id, "TicketID does not exist");
        return _tickets[ticketID].holder;
    }

    /**
     * @dev Transfers `ticketID` ticket from `from` to `to`.
     * This should also set the approved address for this ticket to the zero address
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - the caller must either:
     *   - own `ticketID`
     *   - be approved to move this ticket using `approve`
     *
     * Emits a `Transfer` and an `Approval` event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 ticketID
    ) external{
        require(from != address(0), "`from` cannot be the zero address");
        require(to != address(0), "`to` cannot be the zero address");
        require(msg.sender == _tickets[ticketID].holder || msg.sender == _tickets[ticketID].approved,
        "the caller must either: own `ticketID` or be approved to move this ticket using `approve`");
        _tickets[ticketID].holder = to;
        _tickets[ticketID].approved = address(0);
        _balanceOf[from]--;
        _balanceOf[to]++;
        emit Transfer(from, to, ticketID);
        emit Approval(to, address(0), ticketID);
    }

    /**
     * @dev Gives permission to `to` to transfer `ticketID` ticket to another account.
     * The approval is cleared when the ticket is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the ticket
     * - `ticketID` must exist.
     *
     * Emits an `Approval` event.
     */
    function approve(address to, uint256 ticketID) external{
        require(msg.sender == _tickets[ticketID].holder, "The caller must own the ticket");
        require(ticketID < _id, "`ticketID` must exist");
        _tickets[ticketID].approved = to;
        emit Approval(msg.sender, to, ticketID);

    }

    /**
     * @dev Returns the account approved for `ticketID` ticket.
     *
     * Requirements:
     *
     * - `ticketID` must exist.
     */
    function getApproved(uint256 ticketID) external view returns (address operator){
        require(ticketID < _id, "`ticketID` must exist");
        return _tickets[ticketID].approved;
    }

    /**
     * @dev Returns the current `holderName` associated with a `ticketID`.
     * Requirements:
     *
     * - `ticketID` must exist.
     */
    function holderNameOf(uint256 ticketID)
        external
        view
        returns (string memory holderName){
            require(ticketID < _id, "`ticketID` must exist");
            return _tickets[ticketID].holderName;
        }

    /**
     * @dev Updates the `holderName` associated with a `ticketID`.
     * Note that this does not update the actual holder of the ticket.
     *
     * Requirements:
     *
     * - `ticketID` must exists
     * - Only the current holder can call this function
     */
    function updateHolderName(uint256 ticketID, string calldata newName) external{
        require(ticketID < _id, "`ticketID` must exist");
        require(msg.sender == _tickets[ticketID].holder, "Only the current holder can call this function");
        _tickets[ticketID].holderName = newName;      
    }

    /**
     * @dev Sets the `used` flag associated with a `ticketID` to `true`
     *
     * Requirements:
     *
     * - `ticketID` must exist
     * - the ticket must not already be used
     * - the ticket must not be expired
     * - Only the creator of the collection can call this function
     */
    function setUsed(uint256 ticketID) external{
        require(ticketID < _id, "`ticketID` must exist");
        require(_tickets[ticketID].used == false, "the ticket must not already be used");
        require(_tickets[ticketID].expiryDate >= block.timestamp, "the ticket must not be expired");
        require(msg.sender == _creator, "Only the creator of the collection can call this function");
        _tickets[ticketID].used = true;
    }

    /**
     * @dev Returns `true` if the `used` flag associated with a `ticketID` if `true`
     * or if the ticket has expired, i.e., the current time is greater than the ticket's
     * `expiryDate`.
     * Requirements:
     *
     * - `ticketID` must exist
     */
    function isExpiredOrUsed(uint256 ticketID) external view returns (bool){
        require(ticketID < _id, "`ticketID` must exist");
        return _tickets[ticketID].used || block.timestamp > _tickets[ticketID].expiryDate;
    }
}