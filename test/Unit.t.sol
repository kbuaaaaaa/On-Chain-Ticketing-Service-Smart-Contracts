// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/interfaces/ITicketNFT.sol";
import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/SecondaryMarket.sol";
import "../src/contracts/TicketNFT.sol";

contract Unit is Test {
    PrimaryMarket public primaryMarket;
    PurchaseToken public purchaseToken;
    SecondaryMarket public secondaryMarket;
    ITicketNFT public ticketNFT;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        purchaseToken = new PurchaseToken();
        primaryMarket = new PrimaryMarket(purchaseToken);
        secondaryMarket = new SecondaryMarket(purchaseToken);
        vm.prank(charlie);
        ticketNFT = primaryMarket.createNewEvent(
            "Charlie's concert",
            20e18,
            1
        );

        payable(alice).transfer(3e18);
        payable(bob).transfer(2e18);
    }

    function testCreateNewEvent() external {
        assertEq(ticketNFT.creator(), charlie);
        assertEq(ticketNFT.maxNumberOfTickets(), 1);
        assertEq(ticketNFT.eventName(), "Charlie's concert");
        assertEq(primaryMarket.getPrice(address(ticketNFT)), 20e18);
    }

    function testMintTicketAsPrimaryMarket() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        assertEq(purchaseToken.balanceOf(alice), 100e18);
        purchaseToken.approve(address(primaryMarket), 100e18);
        uint256 ticketPrice = primaryMarket.getPrice(address(ticketNFT));
        uint256 id = primaryMarket.purchase(address(ticketNFT), "Alice");
        assertEq(ticketNFT.balanceOf(alice), 1);
        assertEq(ticketNFT.holderOf(id), alice);
        assertEq(ticketNFT.holderNameOf(id), "Alice");
        assertEq(purchaseToken.balanceOf(alice), 100e18 - ticketPrice);
        assertEq(purchaseToken.balanceOf(charlie), ticketPrice);
        vm.stopPrank();
    }


    function testMintTicketAsNonPrimaryMarket() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.getPrice(address(ticketNFT));
        vm.expectRevert("The caller must be the primary market");
        ticketNFT.mint(alice, "Alice");
        assertEq(ticketNFT.balanceOf(alice), 0);
        vm.stopPrank();
    }

    function testMintAtMaximumTicket() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        assertEq(ticketNFT.balanceOf(alice), 1);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        vm.expectRevert("Maximum ticket number reached");
        primaryMarket.purchase(address(ticketNFT), "Alice");
        vm.expectRevert("TicketID does not exist");
        ticketNFT.holderOf(2);
        vm.stopPrank();
    }


    function testListTicket() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        ticketNFT.approve(address(secondaryMarket), 0);
        secondaryMarket.listTicket(address(ticketNFT), 0, 150e18);

        assertEq(secondaryMarket.getHighestBid(address(ticketNFT), 0), 150e18);
        assertEq(
            secondaryMarket.getHighestBidder(address(ticketNFT), 0),
            address(0)
        );
        assertEq(ticketNFT.balanceOf(alice), 0);
        assertEq(ticketNFT.balanceOf(address(secondaryMarket)), 1);
        assertEq(ticketNFT.holderOf(0), address(secondaryMarket));
        assertEq(ticketNFT.holderNameOf(0), "Alice");
        vm.stopPrank();
    }

    function testListTicketNoApproval() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        vm.expectRevert("the caller must either: own `ticketID` or be approved to move this ticket using `approve`");
        secondaryMarket.listTicket(address(ticketNFT), 0, 150e18);
        vm.stopPrank();
    }


    function testListTicketAsNonOwner() external{
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        vm.stopPrank();  
        vm.startPrank(bob);
        vm.expectRevert("Only the holder of the ticket can list ticket"); 
        secondaryMarket.listTicket(address(ticketNFT), 0, 150e18);
        vm.stopPrank();
    }

    function testListUsedTicket() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        vm.stopPrank();

        vm.startPrank(charlie);
        ticketNFT.setUsed(0);
        assertEq(ticketNFT.isExpiredOrUsed(0), true);
        vm.stopPrank();

        vm.startPrank(alice);
        ticketNFT.approve(address(secondaryMarket), 0);
        vm.expectRevert("Only non-expired and unused tickets can be listed");
        secondaryMarket.listTicket(address(ticketNFT), 0, 150e18);
        vm.stopPrank();
    }

    function testSubmitBidLowerBid() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        ticketNFT.approve(address(secondaryMarket), 0);
        secondaryMarket.listTicket(address(ticketNFT), 0, 150e18);
        vm.stopPrank();
        vm.startPrank(bob);
        purchaseToken.mint{value: 2e18}();
        purchaseToken.approve(address(secondaryMarket), 140e18);
        secondaryMarket.submitBid(address(ticketNFT), 0, 140e18, "Bob");
        assertEq(
            secondaryMarket.getHighestBid(address(ticketNFT), 0),
            150e18
        );
        assertEq(secondaryMarket.getHighestBidder(address(ticketNFT), 0), address(0));    
        vm.stopPrank();  
    }

    function testSubmitBidHigherBid() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        ticketNFT.approve(address(secondaryMarket), 0);
        secondaryMarket.listTicket(address(ticketNFT), 0, 150e18);
        vm.stopPrank();
        vm.startPrank(bob);
        purchaseToken.mint{value: 2e18}();
        purchaseToken.approve(address(secondaryMarket), 155e18);
        secondaryMarket.submitBid(address(ticketNFT), 0, 155e18, "Bob");

        assertEq(
            secondaryMarket.getHighestBid(address(ticketNFT), 0),
            155e18
        );
        assertEq(secondaryMarket.getHighestBidder(address(ticketNFT), 0), bob);
        assertEq(purchaseToken.balanceOf(address(secondaryMarket)), 155e18);
        vm.stopPrank();
    }

    function testSubmitBidUsedTicket() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        ticketNFT.approve(address(secondaryMarket), 0);
        secondaryMarket.listTicket(address(ticketNFT), 0, 150e18);
        vm.stopPrank();

        vm.startPrank(charlie);
        ticketNFT.setUsed(0);
        assertEq(ticketNFT.isExpiredOrUsed(0), true);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("Bid can only be made on non-expired and unused tickets");
        secondaryMarket.submitBid(address(ticketNFT), 0, 155e18, "Bob");
        vm.stopPrank();
    }

    function testAcceptBidAsNonOwner() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        ticketNFT.approve(address(secondaryMarket), 0);
        secondaryMarket.listTicket(address(ticketNFT), 0, 150e18);
        vm.stopPrank();
        vm.startPrank(bob);
        purchaseToken.mint{value: 2e18}();
        purchaseToken.approve(address(secondaryMarket), 155e18);
        secondaryMarket.submitBid(address(ticketNFT), 0, 155e18, "Bob");
        vm.expectRevert("Only the ticket lister can accept bid");
        secondaryMarket.acceptBid(address(ticketNFT), 0);
        vm.stopPrank();
    }

    function testAcceptBidNoBids() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        ticketNFT.approve(address(secondaryMarket), 0);
        secondaryMarket.listTicket(address(ticketNFT), 0, 150e18);
        vm.expectRevert("There is currently no bid");
        secondaryMarket.acceptBid(address(ticketNFT), 0);
        vm.stopPrank();
    }

    function testAcceptBid() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        ticketNFT.approve(address(secondaryMarket), 0);
        secondaryMarket.listTicket(address(ticketNFT), 0, 150e18);
        vm.stopPrank();
        vm.startPrank(bob);
        purchaseToken.mint{value: 2e18}();
        purchaseToken.approve(address(secondaryMarket), 155e18);
        secondaryMarket.submitBid(address(ticketNFT), 0, 155e18, "Bob");
        vm.stopPrank();
        vm.startPrank(alice);
        uint256 aliceBalanceBefore = purchaseToken.balanceOf(alice);
        secondaryMarket.acceptBid(address(ticketNFT), 0);
        assertEq(purchaseToken.balanceOf(address(secondaryMarket)), 0);
        uint256 fee = (155e18 * 0.05e18) / 1e18;
        assertEq(purchaseToken.balanceOf(charlie), 20e18 + fee);
        assertEq(
            purchaseToken.balanceOf(alice),
            aliceBalanceBefore + 155e18 - fee
        );
        assertEq(ticketNFT.holderOf(0), bob);
        assertEq(ticketNFT.holderNameOf(0), "Bob");
        vm.stopPrank();
    }

    function testSetUsedTicketsAsNonOwner() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        vm.expectRevert("Only the creator of the collection can call this function");
        ticketNFT.setUsed(0);
        vm.stopPrank();
    }

    function testSetUsedTicketsNonExistence() external {
        vm.startPrank(charlie);
        vm.expectRevert("`ticketID` must exist");
        ticketNFT.setUsed(0);
        vm.stopPrank();
    }

    function testSetUsedTickets() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        vm.stopPrank();
        vm.startPrank(charlie);
        ticketNFT.setUsed(0);
        assertEq(ticketNFT.isExpiredOrUsed(0), true);
        vm.stopPrank();
    }

    function testSetUsedTicketsAlreadyUsed() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        vm.stopPrank();
        vm.startPrank(charlie);
        ticketNFT.setUsed(0);
        assertEq(ticketNFT.isExpiredOrUsed(0), true);
        vm.expectRevert("the ticket must not already be used");
        ticketNFT.setUsed(0);
        vm.stopPrank();
    }

    function testDelistTicketAsNonOwner() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        ticketNFT.approve(address(secondaryMarket), 0);
        secondaryMarket.listTicket(address(ticketNFT), 0, 150e18);
        vm.stopPrank();
        vm.startPrank(bob);
        vm.expectRevert("Only the account that listed the ticket may delist the ticket");
        secondaryMarket.delistTicket(address(ticketNFT), 0);
        vm.stopPrank();
    }

    function testDelistTicket() external {
        vm.startPrank(alice);
        purchaseToken.mint{value: 1e18}();
        purchaseToken.approve(address(primaryMarket), 100e18);
        primaryMarket.purchase(address(ticketNFT), "Alice");
        ticketNFT.approve(address(secondaryMarket), 0);
        secondaryMarket.listTicket(address(ticketNFT), 0, 150e18);
        vm.stopPrank();
        vm.startPrank(bob);
        purchaseToken.mint{value: 2e18}();
        purchaseToken.approve(address(secondaryMarket), 155e18);
        secondaryMarket.submitBid(address(ticketNFT), 0, 155e18, "Bob");
        vm.stopPrank();
        vm.startPrank(alice);
        uint256 bobBalanceBefore = purchaseToken.balanceOf(bob);
        secondaryMarket.delistTicket(address(ticketNFT), 0);
        assertEq(ticketNFT.balanceOf(alice), 1);
        assertEq(ticketNFT.balanceOf(address(secondaryMarket)), 0);
        assertEq(ticketNFT.holderOf(0), alice);
        assertEq(ticketNFT.holderNameOf(0), "Alice");
        assertEq(purchaseToken.balanceOf(bob), bobBalanceBefore + 155e18);
        assertEq(purchaseToken.balanceOf(address(secondaryMarket)), 0);
        vm.stopPrank();
    }

}