// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/* \contract YoloCoin
 * \Ingroup  contracts
 * \brief    An ERC20 token used for YoloLottery
 *
 * In order to enter the YoloLot pool, one needs to depost
 * ERC20 tokens.
 *
 * This class inherits the ERC20 implementation of
 * @openzeppelin.
 *
 * YoloCoin incentisize miners to include transactions into
 * their block verfiication by auto minting reward, hence
 * creating liqudity for the lottery.
 */
contract YoloCoin is ERC20 {

    constructor(string memory symbol)
        ERC20( symbol, symbol )
    {
        /// 1 billion tokens
        _mint(msg.sender,  (10 ** 9) * (10 ** decimals()));
    }

    function _rewardMiner() internal {
        _mint(block.coinbase, 1000);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        _rewardMiner();
        super._transfer(from, to, amount);
    }
}

/* \contract YoloBank
 * \Ingroup  contracts
 * \brief    Bank to purchase YoloCoin
 *
 * Through YoloBank player can purchase YoloCoins.
 * Initial coin offering is in ETH/Wei.
 */
contract YoloBank is Ownable {
    IERC20 public token;

    /// represented as divisor against ETH
    uint256 icoPrice;

    /// circulation of token released
    uint256 icoTarget;

    /// ico end time
    uint256 icoEndTime;

    event Bought(uint256 amount);

    event LaunchICO(uint256 icoPrice, uint256 icoTarget, uint256 icoEndTime);

    modifier notExpire() {
        require(block.timestamp <= icoEndTime, "Please wait for next ICO");
        _;
    }

    modifier expire() {
        require(block.timestamp > icoEndTime, "Existing ICO not finsihed yet");
        _;
    }

    constructor(string memory symbol) {
        token = new YoloCoin(symbol);

        // avoid multiple directional call
        uint256 totalSupply = token.totalSupply();

        // owner get 15%
        token.transfer(msg.sender, totalSupply * 3 / 20);
    }

    function getCurrentPrice() public notExpire view returns(uint256) {
        return icoPrice;
    }

    function getCurrentTarget() public notExpire view returns(uint256) {
        return icoTarget;
    }

    function getCurrentEndTime() public view returns(uint256) {
        return icoEndTime;
    }

    function launch(uint256 price, uint256 target, uint256 icoPeriod) public onlyOwner expire {
        require(price > 0, "Set an ICO price");
        require(target > 0, "Set an ICO target");

        uint256 balance = token.balanceOf(address(this));
        require(target <= balance, "Not enough tokens in the bank for ICO target");

        icoPrice = price;
        icoTarget = target;
        icoEndTime = block.timestamp + icoPeriod;

        emit LaunchICO(icoPrice, icoTarget, icoEndTime);
    }

    function buy() payable public notExpire {
        uint256 amount = msg.value;
        require(amount > 0, "You need to send some ether");

        uint256 tokensToBuy = amount * icoPrice;
        require(tokensToBuy <= icoTarget, "Amount to buy exceed ICO target. Try buying less tokens");

        uint256 balance = token.balanceOf(address(this));
        require(tokensToBuy <= balance, "Not enough tokens in the bank.");

        token.transfer(msg.sender, tokensToBuy);
        icoTarget -= tokensToBuy;
        emit Bought(tokensToBuy);
    }

    function extractEther() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}