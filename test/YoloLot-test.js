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

    await gameAccount1.enter(ethers.utils.parseUnits("1.0", decimals));
    await gameAccount2.enter(ethers.utils.parseUnits("2.0", decimals));

    await gameAccount1.viewPool().then( x => console.log("Player1 Pool Size: " + x ) );
    await gameAccount2.viewPool().then( x => console.log("Player2 Pool Size: " + x ) );
  });
});