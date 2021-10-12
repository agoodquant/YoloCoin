pragma solidity ^0.8.0;

import "./YoloLot.sol";
import "./YoloRandom.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/* \contract YoloDealer
 * \Ingroup  contracts
 * \brief    A smart contract for lottery dealing
 * 
 * This class deals the lottery contracts and set consumers to rng.
 * RNG is consumed internally which only the dealer can control
 * who the consumer is for security and safty.
 *
 * Once game is created, it will broadcast to blockchain.
 *
 */
contract YoloDealer is Ownable {

    address yoloCoin;

    YoloRandomProvider rngProvider;

    address[] rngs;

    uint256 capacity;

    event YoloLotCreated(address, address);

    constructor() {
    }

    /// set the rng provider
    function setRandomProvider(YoloRandomProvider rngProvider_) onlyOwner public {
        rngProvider = rngProvider_;
    }

    /// set address of yoloCoin
    function setYoloCoin(address yoloCoin_) onlyOwner public {
        yoloCoin = yoloCoin_;
    }

    /// set the capcity of rngs, which is also number of games allowed
    function setRNGCapacity(uint256 capacity_, bool preserve) onlyOwner public {
        if ( preserve ) {
            for ( uint256 i = rngs.length-1; i >= capacity_; --i ) {
                delete rngs[i];
            }
        }
        else {
            rngs = new address[](capacity_);
        }

        capacity = capacity_;
    }

    /// clear the RNG for operational purpose
    function clearRNG() onlyOwner public {
        delete rngs;
    }

    /// create the lottery contract and broadcast
    function getYoloLottery() onlyOwner public {
        address rng = getYoloRng();

        YoloLot yoloLot = new YoloLot(address(rng), yoloCoin);
        YoloRandom(rng).setConsumer(address(yoloLot));

        emit YoloLotCreated(msg.sender, address(yoloLot));
    }

    /// create the rng based on provider specified
    function getYoloRng() onlyOwner internal returns(address) {
        require( capacity > 0, "Set capcity to be > 0" );
        
        for ( uint256 i = 0; i < capacity; ++i ) {
            if ( rngs[i] == address(0x0) ) {
                address rng = createYoloRng();
                rngs[i] = rng;

                return rng;
            }
            else {
                if ( YoloRandom(rngs[i]).isAvailable() ) {
                    return rngs[i];
                }
            }
        }

        require(false, "Capacity full. Cannot request more RNGs");
        
        return address(0x0); // just to supress the warning, never hit
    }

    /// create the rng based on provider specified
    function createYoloRng() onlyOwner internal returns(address) {
        if ( rngProvider == YoloRandomProvider.Mockup ) {
            return address(new YoloRandomMockup(address(this)));
        }
        
        if ( rngProvider == YoloRandomProvider.Chainlink ) {
            // TODO: deposit Chainlink to the contract
            return address(new YoloRandomChainlink(address(this)));
        }

        require(false, "Unknow RNG provider");

        return address(0x0); // just to supress the warning, never hit
    }    
}        
