pragma solidity ^0.8.0;

import "./YoloCoin.sol";
import "./YoloRandom.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

    uint totalPool;

    address yoloRandom;

    uint issueDate;

    uint expiryDate;

    address winner;

    bytes32 lastRequest;

    event YoloLotWinner(address, address);

    event YoloLotDraw(address);

    constructor(address randomAddress, address yoloCoin) {
        yoloRandom = randomAddress;
        token = IERC20(yoloCoin);

        issueDate = block.timestamp;
        expiryDate = issueDate + 7 days;
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
        require( winner != address(0x0) ) ;
        require( winner == msg.sender ) ;
        _;
    }

    modifier onlyRNG() {
        require( yoloRandom == msg.sender ) ;
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

        pool[msg.sender] += amount;

        totalPool += amount;
    }

    /// draw the winner, anyone can draw once expired
    function draw() public expire {
        require(lastRequest == 0x0, "Can only draw once");
        lastRequest = YoloRandom(yoloRandom).requestRandomNumber();

        emit YoloLotDraw(msg.sender);
    }

    /// confirm the winner, used in case call back fails
    function confirm() public expire {
        uint256 randomness = YoloRandom(yoloRandom).getRandomNumber(lastRequest);
        finalize(randomness);
    }

    /// reward the pool token to winners
    function reward() public expire onlyWinner {
        token.transferFrom(address(this), msg.sender, totalPool);
    }

    /// view the pool size
    function viewPool() public view returns(uint) {
        return pool[msg.sender];
    }

    /// consume the rng, finalize the winner
    function consume(bytes32 requestId_, uint256 randomness) onlyRNG expire public override {
        require(lastRequest == requestId_);

        finalize(randomness);
    }

    /// finalize the winner
    function finalize(uint256 randomness) private {
        // Todo: code up the rng logic as uniform dist here
    }    
}