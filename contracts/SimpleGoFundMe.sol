pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract SimpleCharity {

  struct Donor {

      address next;

      address prev;

      uint amount;
  }

  // first node of the linked list, we only store top 10 donors
  address highestDonor;

  mapping(address=>Donor) donations;
  address payable receiver;

  constructor(address payable receiver_) {
    receiver = receiver_;
  }

  modifier receiverOnly() {
    require(receiver == msg.sender, "Not Receiver!!!");
    _;
  }

  function getReceiver() public view returns(address)
  {
    return receiver;
  }

  function getDonation() public view returns(uint)
  {
    return donations[msg.sender].amount;
  }

  function deposit() public payable {
    Donor storage donor = donations[msg.sender];
    donor.amount += msg.value;

    if ( highestDonor == address( 0x0 ) )
    {
        highestDonor = msg.sender;
        return;
    }

    // update the link list
    uint16 i = 0;
    address curr_i = highestDonor;
    for ( ; i < 10; ++i )
    {
        Donor storage currDonor = donations[curr_i];

        if ( currDonor.amount > donor.amount )
        {
            curr_i = currDonor.next;
            continue;
        }

        // some visualization is helpful here
        // prev curr: prev.next -> curr, curr.prev -> next
        // prev me curr: prev.next -> me, me.prev -> prev, me.next -> curr, curr.prev -> me

        // me.next -> curr
        donor.next = curr_i;

        if ( currDonor.prev != address( 0x0 ) )
        {
            Donor storage prevDonor = donations[currDonor.prev];

            // prev.next -> me
            prevDonor.next = msg.sender;

            // me.prev -> prev
            donor.prev = currDonor.prev;
        }
        
        // curr.prev -> me
        currDonor.prev = msg.sender;

        break;
    }

    // if i breaks at 0, it means the the donor.amount is >= highest donor
    if ( i == 0 )
    {
        highestDonor = msg.sender;
    }
  }

  function withdraw() public receiverOnly {
    receiver.transfer( address(this).balance );
  }

  function getTopDonator() public view returns(address[10] memory, uint[10] memory) {
    address[10] memory topAddresses;
    uint[10] memory topAmounts;

    address curr_i = highestDonor;
    for ( uint16 i = 0; i < 10; ++i )
    {
        if ( curr_i == address( 0x0) )
          break;

        Donor memory currDonor = donations[curr_i];
        topAddresses[i] = curr_i;
        topAmounts[i] = currDonor.amount;

        curr_i = currDonor.next;
    }

    return (topAddresses, topAmounts);
  }
}