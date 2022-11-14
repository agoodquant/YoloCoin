pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

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
    function consume(uint256 requestId, uint256[] memory randomness) public virtual;
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
    function notifyConsumer(uint256 requestId, uint256[] memory randomness) internal
    {
        YoloRandomConsumer(consumer).consume(requestId, randomness);

        consumer = address(0x0);
    }

    /// submit the rng request
    function requestRandomNumber(uint16 numRandom) public virtual returns (uint256);

    /// obtain the generated rng. in case notify fails
    function getRandomNumber(uint256 requestId) virtual external view returns (uint256[] memory);
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

    uint256[] testRandom;

    constructor(address dealer_)
        YoloRandom(dealer_)
    {
    }

    event RandomNumberRequested(uint256);

    function requestRandomNumber(uint16 numRandom) onlyConsumer public override returns (uint256) {
        require(numRandom == 1);
        if (testRandom.length != numRandom)
        {
            testRandom = new uint256[](numRandom);

            for (uint16 i = 0; i < numRandom; ++i)
            {
                testRandom[i] = 666;
            }
        }
        emit RandomNumberRequested(777);
        return 777;
    }

    function getRandomNumber(uint256 requestId) external override view returns (uint256[] memory) {
        assert(requestId == 777);
        return testRandom;
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
contract YoloRandomChainlink is YoloRandom, VRFV2WrapperConsumerBase, ConfirmedOwner {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords, uint256 payment);

    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // Address LINK - hardcoded for Goerli
    address linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;

    // address WRAPPER - hardcoded for Goerli
    address wrapperAddress = 0x708701a1DfF4f478de54383E49a627eD4852C816;

    constructor(address dealer_)
        VRFV2WrapperConsumerBase(linkAddress, wrapperAddress)
        ConfirmedOwner(dealer_)
        YoloRandom(dealer_)
    {
    }

    function requestRandomNumber(uint16 numRandom) public override returns (uint256) {
        uint256 requestId = requestRandomness(callbackGasLimit, requestConfirmations, numRandom);
        s_requests[requestId] = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomWords: new uint256[](0),
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numRandom);
        return requestId;
    }

    function getRandomNumber(uint256 requestId) external override view returns (uint256[] memory) {
        RequestStatus memory request = s_requests[requestId];

        require(request.paid > 0, 'request not found');
        require(request.fulfilled, "Chainlink random numbers not ready yet");

        return request.randomWords;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        RequestStatus memory request = s_requests[requestId];
        require(request.paid > 0, 'request not found');
        request.fulfilled = true;
        request.randomWords = randomWords;

        notifyConsumer(requestId, randomWords);
        emit RequestFulfilled(requestId, randomWords, request.paid);
    }

    /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(link.transfer(msg.sender, link.balanceOf(address(this))), 'Unable to transfer');
    }
}