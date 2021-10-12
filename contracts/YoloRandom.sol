pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

/* \contract YoloRandomConsumer
 * \Ingroup  contracts
 * \brief    An interface that consume the random number
 * 
 * Blockchains takes time to generate the random number by block
 * Therefore it needs a call back function for the random consumer
 * to consumer the rng.
 *
 */
abstract contract YoloRandomConsumer {
    function consume(bytes32 requestId, uint256 randomness) public virtual;
}


enum YoloRandomProvider {
    Mockup,
    Chainlink
}

/* \contract YoloRandom
 * \Ingroup  contracts
 * \brief    An interface that generates the random number
 * 
 * YoloRandom takes the address of the consumer and only consumer
 * can request/get random number. This is obvious that such
 * function can be called externally and spent all our coins.
 *
 */
abstract contract YoloRandom {
    address consumer;

    address dealer;

    constructor(address dealer_)
    {
        dealer = dealer_;
    }

    modifier onlyConsumer()
    {
        require( msg.sender == consumer, "only YoloLot can execute YoloRandom");
        _;
    }

    modifier onlyDealer()
    {
        require( msg.sender == dealer);
        _;
    }

    function isAvailable() public onlyDealer view returns(bool) {
        return consumer == address(0x0);
    }    

    /// change consumer
    function setConsumer(address consumer_) public onlyDealer
    {
        consumer = consumer_;
    }

    /// notify the consumer with the generate rng
    function notifyConsumer(bytes32 requestId, uint256 randomness) internal
    {
        YoloRandomConsumer(consumer).consume(requestId, randomness);

        consumer = address(0x0);
    }

    /// submit the rng request
    function requestRandomNumber() public virtual returns (bytes32);

    /// obtain the generated rng. in case notify fails
    function getRandomNumber(bytes32 requestId) virtual external view returns (uint256);
}

/* \contract YoloRandomMockup
 * \Ingroup  contracts
 * \brief    A mock up implementation to generate the rng
 * 
 * This is for testing purpose in local in memory block chains.
 * This class emits events only for testing only.
 * Please do not do it in actual rng because you don't want to
 * broadcast your requestId or your rng :)
 *
 */
contract YoloRandomMockup is YoloRandom {

    uint256 randomness;

    constructor(address dealer_)
        YoloRandom(dealer_)
    {
    }

    event RandomNumberRequested( bytes32 );

    function requestRandomNumber() onlyConsumer public override returns (bytes32) {
        randomness = 666;
        emit RandomNumberRequested("testId");
        return "testId";
    }

    function fulfillRandomness() public {
        notifyConsumer("testId", randomness);
    }    

    function getRandomNumber(bytes32 requestId) external override view returns (uint256) {
        assert( requestId == "testId" );
        assert( randomness != 0 );
        
        return randomness;
    }
}

/* \contract YoloRandomChainlink
 * \Ingroup  contracts
 * \brief    A chainlink integration to generate the rng
 * 
 * This class implements YoloRandom with Chainlink VRF
 * to generate the rng. One must deposit chainlink tokens
 * into this address in order to submit rng requests to
 * chainlink. Also there must be enough gas for this
 * contract to call back the consume function.
 * 
 * getRandomNumber is not marked as onlyConsumer in case
 * the random number is not fed the game can still retrive
 * later for settlement purpose.
 *
 */
contract YoloRandomChainlink is YoloRandom, VRFConsumerBase {
    
    bytes32 internal keyHash;
    uint256 internal fee;

    /* this is because solidity does not have concept of key existance.
     * all keys exists with default as "null", i.e. 0
     * This is a helper struct to check if a value is actually
     * initalized or not
     */
    struct RandomResult
    {
        uint256 res;

        bool exists;
    }

    mapping(bytes32=>RandomResult) private randomResult;

    // https://docs.chain.link/docs/vrf-contracts/
    constructor(address dealer_) 
        VRFConsumerBase(
            0xf0d54349aDdcf704F77AE15b96510dEA15cb7952, // VRF Coordinator
            0x514910771AF9Ca656af840dff83E8264EcF986CA  // LINK Token
        )
        YoloRandom(dealer_)
    {
        keyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
        fee = 2 * 10 ** 18; // 2 LINK
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult[requestId] = RandomResult(randomness, true);

        notifyConsumer(requestId, randomness);
    }

    function requestRandomNumber() onlyConsumer public override returns (bytes32) {
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");
        bytes32 requestId = requestRandomness(keyHash, fee);

        return requestId;
    }

    function getRandomNumber(bytes32 requestId) external override view returns (uint256) {
        RandomResult memory res = randomResult[requestId];

        require(res.exists, "RNG not ready yet");

        return res.res;
    }
}