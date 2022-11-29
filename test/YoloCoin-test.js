const { loadFixture } = require("@ethereum-waffle/provider");
const { expect } = require("chai");
const { network } = require("hardhat");

async function deployYoloCoinContract() {
  const [bank] = await ethers.getSigners();

  // setup YoloBank
  const YoloBank = await ethers.getContractFactory("YoloBank");
  const yoloBank = await YoloBank.deploy("YoloCum");
  await yoloBank.deployed();

  // setup YoloCoin
  const YoloCoin = await ethers.getContractFactory("YoloCoin");
  const yoloCoin = await YoloCoin.attach(await yoloBank.token());

  return {yoloBank, yoloCoin};
};

describe("YoloCoin", function () {
  it("Test yolo bank and coin", async function () {
    // setup YoloBank
    const {yoloBank, yoloCoin} = await loadFixture(deployYoloCoinContract);

    console.log("bank:" + yoloBank.address);
    console.log("coin:" + yoloCoin.address);

    let decimals = await yoloCoin.decimals();
    expect(decimals).to.equal(18);

    // setup buyer
    const [bank, , account1, account2] = await ethers.getSigners();

    // ico
    // ICO at $20,000,000
    // 1,000,000,000 * x = 20,000,000
    // x = 20,000,000 / 1,0000,000,000 = 2 cent per coin
    // 1 ETH is $1,500 = 75,000 coin
    let icoPrice = 75000;
    let ownerAsAccount = yoloBank.connect(bank);
    await ownerAsAccount.launch(icoPrice, ethers.utils.parseUnits("500000000", decimals), 100);
    await ownerAsAccount.icoPrice().then( x => console.log("CurrentP rice: " + x ) );
    await ownerAsAccount.icoTarget().then( x => console.log("Current Target: " + x ) );
    await ownerAsAccount.icoEndTime().then( x => console.log("Current ICO EndTime: " + x ) );

    // buy tokens
    let runAsAccount1 = yoloBank.connect(account1);
    let runAsAccount2 = yoloBank.connect(account2);
    await runAsAccount1.buy({from:account1.address, value:ethers.utils.parseEther("1.0")});
    await runAsAccount2.buy({from:account2.address, value:ethers.utils.parseEther("2.0")});

    console.log("After buying some tokens");
    await yoloCoin.balanceOf( account1.address ).then( x => console.log("Player1 Balance: " + x ) );
    await yoloCoin.balanceOf( account2.address ).then( x => console.log("Player2 Balance: " + x ) );
    await yoloCoin.balanceOf( yoloBank.address ).then( x => console.log("Bank Reserve: " + x ) );
    await ownerAsAccount.icoTarget().then( x => console.log("Current Target: " + x ) );

    // owners extract tokens
    await ethers.provider.getBalance( bank.address ).then( x => console.log("Owner wealth prior withdrawal: " + x ) );
    await ownerAsAccount.extractEther();
    await ethers.provider.getBalance( bank.address ).then( x => console.log("Owner wealth post withdrawal: " + x ) );

    // owners set new ICO price
    expect(await runAsAccount1.icoPrice()).to.equal(75000);

    await network.provider.send("evm_increaseTime", [101]);
    await network.provider.send("evm_mine");
    await ownerAsAccount.launch(100000, 100, 3600);
    expect(await runAsAccount1.icoPrice()).to.equal(100000);

    await network.provider.send("evm_increaseTime", [3601]);
    await network.provider.send("evm_mine");
    await ownerAsAccount.launch(75000, ethers.utils.parseUnits("1000000", decimals), 10000000);
  });
});

module.exports = { deployYoloCoinContract };