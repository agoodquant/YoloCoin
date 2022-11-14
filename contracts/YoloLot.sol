pragma solidity ^0.8.0;

import "./YoloCoin.sol";
import "./YoloRandom.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/* \contract YoloLot
 * \Ingroup  contracts
 * \brief    A smart contract for lottery in YoloCoin
 *
 * This class allows players to enter the lottery pool
 * by depositing YoloCoin.
 *
 * The contract only accepts deposit prior to expiry.
 * After expiry (only), anyone can draw for the winner.
 *
 * Winner takes all with 1% of the fee goes to the
 * YoloCoin maintainer.
 *
 */
contract YoloLot is YoloRandomConsumer {

    IERC20 token;

    mapping(address=>uint) pool;

    address[] players;

    uint totalPool;

    address yoloRandom;

    uint issueDate;

    uint expiryDate;

    mapping(address=>uint) winners;

    uint256 lastRequest;

    event YoloLotWinner(address);

    event YoloLotDraw();

    uint8 numBigWinners;

    uint8 numSmallWinners;

    constructor(address randomAddress, address yoloCoin) {
        yoloRandom = randomAddress;
        token = IERC20(yoloCoin);

        issueDate = block.timestamp;
        expiryDate = issueDate + 7 days;

        numBigWinners = 1;
        numSmallWinners = 5;
    }

    modifier notExpire() {
        require(block.timestamp < expiryDate);
        _;
    }

    modifier expire() {
        require(block.timestamp >= expiryDate);
        _;
    }

    modifier onlyWinner() {
        require(winners[msg.sender] > 0);
        _;
    }

    modifier onlyRNG() {
        require(yoloRandom == msg.sender) ;
        _;
    }

    function getExpiryDate() public view returns(uint) {
        return expiryDate;
    }

    /// enter the pool with tokens deposited
    function enter(uint amount) public notExpire {
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= amount, "Check the token allowance");
        token.transferFrom(msg.sender, address(this), amount);

        if (pool[msg.sender] == 0)
        {
            players.push(msg.sender);
        }

        pool[msg.sender] += amount;

        totalPool += amount;
    }

    /// draw the winner, anyone can draw once expired
    function draw() public expire {
        require(lastRequest == 0x0, "Can only draw once");
        uint8 totalWinners = numSmallWinners+numBigWinners;
        lastRequest = YoloRandom(yoloRandom).requestRandomNumber(totalWinners);

        emit YoloLotDraw();
    }

    /// confirm the winner, used in case call back fails
    function confirm() public expire {
        uint256[] memory randomness = YoloRandom(yoloRandom).getRandomNumber(lastRequest);
        finalize(randomness);
    }

    /// withdraw the pool token to winners
    function withdraw() public expire onlyWinner {
        token.transferFrom(address(this), msg.sender, winners[msg.sender]);
    }

    /// view the pool size
    function viewPool() public view returns(uint) {
        return pool[msg.sender];
    }

    /// consume the rng, finalize the winner
    function consume(uint256 requestId_, uint256[] memory randomness) onlyRNG expire public override {
        require(lastRequest == requestId_);

        finalize(randomness);
    }

    /// finalize the winner
    function finalize(uint256[] memory randomness) private {
        uint8 totalWinners = numSmallWinners+numBigWinners;
        assert(randomness.length == totalWinners);

        uint256[] memory runPool = new uint256[](players.length);

        uint256 runSum = 0;
        for ( uint256 i = 0; i < players.length; ++i)
        {
            runSum += pool[players[i]];
            runPool[i] = runSum;
        }

        uint256 reward_i = totalPool * 9 / (10 * numBigWinners);
        for(uint8 i = 0; i < numBigWinners; ++i)
        {
            uint256 random_i = randomness[i] % totalPool;
            uint256 win_i = findUpperBound( runPool, random_i );
            winners[players[win_i]] = reward_i;
        }

        reward_i = totalPool / (10 * numSmallWinners);
        for(uint8 i = numBigWinners; i < totalWinners; ++i)
        {
            uint256 random_i = randomness[i] % totalPool;
            uint256 win_i = findUpperBound( runPool, random_i );
            winners[players[win_i]] = reward_i;
        }
    }

    // copy-paste implementation from openzeppline due to no memory signature availability
    function findUpperBound(uint256[] memory array, uint256 element) private pure returns (uint256) {
        if (array.length == 0) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = Math.average(low, high);

            // Note that mid will always be strictly less than high (i.e. it will be a valid array index)
            // because Math.average rounds down (it does integer division with truncation).
            if (array[mid] > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
        if (low > 0 && array[low - 1] == element) {
            return low - 1;
        } else {
            return low;
        }
    }
}