const { loadFixture } = require("@ethereum-waffle/provider");
const { expect } = require("chai");
const { deployYoloDealerContract } = require("./YoloDealer-test");

describe("YoloLot", function () {
  it("Test yolo lottery", async function () {
    // setup dealer, bank, and ERC20 tokens
    const {yoloDealer, yoloBank, yoloCoin} = await loadFixture(deployYoloDealerContract);

    // setup new lottery
    let yoloLotTx = await yoloDealer.getYoloLottery();
    let yoloLotReceipt = await yoloLotTx.wait();
    let lotAddress = yoloLotReceipt.events[0].args[1];

    const YoloLot = await ethers.getContractFactory("YoloLot");
    const yoloLot = await YoloLot.attach(lotAddress);

    // setup player
    const [, , player1, player2] = await ethers.getSigners();
    let bankAccount1 = yoloBank.connect(player1);
    let bankAccount2 = yoloBank.connect(player2);
    await bankAccount1.buy({from:player1.address, value:ethers.utils.parseEther("1.0")});
    await bankAccount2.buy({from:player2.address, value:ethers.utils.parseEther("2.0")});

    // play!
    let decimals = await yoloCoin.decimals();
    let gameAccount1 = yoloLot.connect(player1);
    let gameAccount2 = yoloLot.connect(player2);

    let tokenAsAccount1 = yoloCoin.connect(player1);
    let tokenAsAccount2 = yoloCoin.connect(player2);

    await tokenAsAccount1.increaseAllowance(yoloLot.address, ethers.utils.parseUnits("10", decimals));
    await tokenAsAccount2.increaseAllowance(yoloLot.address, ethers.utils.parseUnits("20", decimals));

    // balance of YoloCoin before deposit
    await yoloCoin.balanceOf( player1.address ).then( x => console.log("Player1 Balance Before Deposit: " + x ) );
    await yoloCoin.balanceOf( player2.address ).then( x => console.log("Player2 Balance Before Deposit: " + x ) );
    await yoloCoin.balanceOf( yoloDealer.address ).then( x => console.log("Dealer Balance Before Deposit: " + x ) );
    await yoloCoin.balanceOf( lotAddress ).then( x => console.log("YoloLot Balance Before Deposit: " + x ) );

    await gameAccount1.enter(ethers.utils.parseUnits("1.0", decimals));
    await gameAccount2.enter(ethers.utils.parseUnits("2.0", decimals));

    await gameAccount1.viewPool().then( x => console.log("Player1 Pool Size: " + x ) );
    await gameAccount2.viewPool().then( x => console.log("Player2 Pool Size: " + x ) );
    await gameAccount1.totalPool().then( x => console.log("Total Pool Size: " + x) );

    // balance of YoloCoin after deposit, before draw
    await yoloCoin.balanceOf( player1.address ).then( x => console.log("Player1 Balance After Deposit: " + x ) );
    await yoloCoin.balanceOf( player2.address ).then( x => console.log("Player2 Balance After Deposit: " + x ) );
    await yoloCoin.balanceOf( yoloDealer.address ).then( x => console.log("Dealer Balance After Deposit: " + x ) );
    await yoloCoin.balanceOf( lotAddress ).then( x => console.log("YoloLot Balance After Deposit: " + x ) );

    // after 7 days
    await network.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]);
    await network.provider.send("evm_mine");

    console.log( "Roll the dice and draw the winners" );
    await gameAccount1.roll();
    await gameAccount1.draw();

    let winners = await gameAccount1.getWinners();
    console.log(winners[0]);
    winners[1].forEach( x => console.log( x.toString() ) );

    console.log( "Player1 withdraw" );
    await gameAccount1.withdraw();

    await yoloCoin.balanceOf( player1.address ).then( x => console.log("Player1 Balance After Player1 Withdraw: " + x ) );
    await yoloCoin.balanceOf( player2.address ).then( x => console.log("Player2 Balance After Player1 Withdraw: " + x ) );
    await yoloCoin.balanceOf( yoloDealer.address ).then( x => console.log("Dealer Balance After Player1 Withdraw: " + x ) );
    await yoloCoin.balanceOf( lotAddress ).then( x => console.log("YoloLot Balance After Player1 Withdraw: " + x ) );

    console.log( "Withdraw all" );
    await gameAccount1.withdrawAll();
    await yoloCoin.balanceOf( player1.address ).then( x => console.log("Player1 Balance After WithdrawAll: " + x ) );
    await yoloCoin.balanceOf( player2.address ).then( x => console.log("Player2 Balance After WithdrawAll: " + x ) );
    await yoloCoin.balanceOf( yoloDealer.address ).then( x => console.log("Dealer Balance After WithdrawAll: " + x ) );
    await yoloCoin.balanceOf( lotAddress ).then( x => console.log("YoloLot Balance After WithdrawAll: " + x ) );
  });
});