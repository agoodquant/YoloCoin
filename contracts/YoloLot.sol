// SPDX-License-Identifier: MIT
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

    address[] winners;

    uint256[] rewards;

    uint totalPool;

    address yoloDealer;

    address yoloRandom;

    uint issueDate;

    uint expiryDate;

    mapping(address=>uint) rewardsDict;

    uint256 lastRequest;

    event YoloLotWinner(address[], uint256[]);

    event YoloLotDraw();

    event YoloLotWithDraw(address, uint256);

    uint8 numBigWinners;

    uint8 numSmallWinners;

    constructor(address randomAddress, address yoloCoin) {
        yoloDealer = msg.sender;
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
        require(rewardsDict[msg.sender] > 0);
        _;
    }

    modifier onlyRNG() {
        require(yoloRandom == msg.sender);
        _;
    }

    function getExpiryDate() public view returns(uint) {
        return expiryDate;
    }

    function replay() public expire {
        require(totalPool == 0, "Cannot replay when game in progress");

        issueDate = block.timestamp;
        expiryDate = issueDate + 7 days;
        lastRequest = 0x0;

        // wipe out the players
        for ( uint256 i = 0; i < players.length; ++i)
        {
            delete pool[players[i]];
        }

        delete players;
        delete winners;
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

    /// roll the dice, anyone can roll once expired
    function roll() public expire {
        require(lastRequest == 0x0, "Can only roll once");
        uint8 totalWinners = numSmallWinners+numBigWinners;
        lastRequest = YoloRandom(yoloRandom).requestRandomNumber(totalWinners);

        emit YoloLotDraw();
    }

    /// draw the winner, used in case call back fails
    function draw() public expire {
        uint256[] memory randomness = YoloRandom(yoloRandom).getRandomNumber(lastRequest);
        drawInternal(randomness);
    }

    /// withdraw the pool token to winner
    function withdraw() public expire onlyWinner {
        withdrawFor(msg.sender);
    }

    /// withdraw all the pool tokens to winners
    function withdrawAll() public expire {
        require(winners.length > 0, "Not draw yet");
        for (uint256 i = 0; i < winners.length; ++i)
        {
            withdrawFor(winners[i]);
        }
    }

    function withdrawFor(address winner) private expire {
        uint256 reward = rewardsDict[winner];

        if (reward == 0) {
            return;
        }

        token.transferFrom(address(this), winner, reward);
        totalPool -= reward;

        delete rewardsDict[winner];

        emit YoloLotWithDraw(winner, reward);
    }

    /// view the pool size
    function viewPool() public view returns(uint) {
        return pool[msg.sender];
    }

    /// consume the rng, finalize the winner
    function consume(uint256 requestId_, uint256[] memory randomness) onlyRNG expire public override {
        require(lastRequest == requestId_);

        drawInternal(randomness);
    }

    /// draw the winners
    function drawInternal(uint256[] memory randomness) private {
        require(winners.length == 0, "Cannot draw more than once");

        uint8 totalWinners = numSmallWinners+numBigWinners;
        assert(randomness.length == totalWinners);

        uint256[] memory runPool = new uint256[](players.length);

        uint256 runSum = 0;
        for (uint256 i = 0; i < players.length; ++i)
        {
            runSum += pool[players[i]];
            runPool[i] = runSum;
        }

        // 89.7% goes to big winners
        uint256 big_reward = totalPool * 897 / (1000 * numBigWinners);
        for (uint8 i = 0; i < numBigWinners; ++i)
        {
            uint256 random_i = randomness[i] % totalPool;
            uint256 win_i = findUpperBound( runPool, random_i );

            winners.push( players[win_i] );
            rewards.push( big_reward );
        }

        // 10% goes to small winners
        uint small_reward = totalPool / (10 * numSmallWinners);
        for (uint8 i = numBigWinners; i < totalWinners; ++i)
        {
            uint256 random_i = randomness[i] % totalPool;
            uint256 win_i = findUpperBound( runPool, random_i );

            winners.push( players[win_i] );
            rewards.push( small_reward );
        }

        // 0.3% go to dealer for RNGs
        uint dealer_cut = totalPool - big_reward * numBigWinners - small_reward * numSmallWinners;
        winners.push( yoloDealer );
        rewards.push( dealer_cut );

        // iterate through the array for mapping
        for (uint8 i = 0; i < winners.length; ++i)
        {
            rewardsDict[winners[i]] = rewards[i];
        }

        emit YoloLotWinner(winners, rewards);
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

/* \contract YoloLotFactory
 * \Ingroup  contracts
 * \brief    A factory class to initiate new YoloLot contract
 *
 * Solidty will include the whole class if "new" is used.
 * Hence breaking the size of the smart contract.
 *
 * A factory method will help avoid this problem.
 */
contract YoloLotFactory
{
    function createYoloLottery(address rng, address yoloCoin) public returns(address) {
        YoloLot yoloLot = new YoloLot(rng, yoloCoin);
        return address(yoloLot);
    }
}