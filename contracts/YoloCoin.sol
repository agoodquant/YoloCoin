pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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
contract YoloBank {
    IERC20 public token;

    /// represented as divisor against ETH
    uint256 icoPrice;

    event Bought(uint256 amount);

    event Sold(uint256 amount);

    constructor(string memory symbol) {
        token = new YoloCoin(symbol);
        icoPrice = 10 ** 4;

        // gennesis get 10%
        token.transfer(msg.sender, token.totalSupply() / 10);
    }

    function buy() payable public {
        uint256 amount = msg.value;
        uint256 balance = token.balanceOf(address(this));
        require(amount > 0, "You need to send some ether");
        require(amount <= balance, "Not enough tokens in bank");
        token.transfer(msg.sender, amount * icoPrice);
        emit Bought(amount);
    }

    function sell(uint256 amount) public {
        require(amount > 0, "You need to sell at least some tokens");
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance > amount, "Check the balance of your tokens");
        token.transferFrom(msg.sender, address(this), amount);
        payable(msg.sender).transfer(amount / icoPrice);
        emit Sold(amount);
    }
}