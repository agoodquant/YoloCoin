const { loadFixture } = require("@ethereum-waffle/provider");
const { expect } = require("chai");

async function deployYoloCoinContract() {
  const [bank] = await ethers.getSigners();

  // setup YoloBank
  const YoloBank = await ethers.getContractFactory("YoloBank");
  const yoloBank = await YoloBank.deploy("YoloCum");
  await yoloBank.deployed();

  // setup YoloCoin
  const YoloCoin = await ethers.getContractFactory("YoloCoin");
  const yoloCoin = await YoloCoin.attach(yoloBank.token());

  return {yoloBank, yoloCoin};
};

describe("YoloCoin", function () {
  it("Test yolo dealer and lottery", async function () {
    // setup YoloBank
    const {yoloBank, yoloCoin} = await loadFixture(deployYoloCoinContract);

    console.log("bank:" + yoloBank.address);
    console.log("coin:" + yoloCoin.address);

    let decimals = await yoloCoin.decimals();
    console.log("Decimals: " + decimals);

    // setup buyer
    const [, , account1, account2] = await ethers.getSigners();

    // buy tokens
    let runAsAccount1 = yoloBank.connect(account1);
    let runAsAccount2 = yoloBank.connect(account2);
    await runAsAccount1.buy({from:account1.address, value:ethers.utils.parseEther("1.0")});
    await runAsAccount2.buy({from:account2.address, value:ethers.utils.parseEther("2.0")});

    console.log("After buying some tokens");
    await yoloCoin.balanceOf( account1.address ).then( x => console.log("Player1 Balance: " + x ) );
    await yoloCoin.balanceOf( account2.address ).then( x => console.log("Player2 Balance: " + x ) );
    await yoloCoin.balanceOf( yoloBank.address ).then( x => console.log("Bank Reserve: " + x ) );

    // sell tokens
    let tokenAsAccount1 = yoloCoin.connect(account1);
    await tokenAsAccount1.increaseAllowance(yoloBank.address, ethers.utils.parseUnits("0.6", decimals));
    await runAsAccount1.sell(ethers.utils.parseUnits("0.5", decimals));

    let tokenAsAccount2 = yoloCoin.connect(account2);
    await tokenAsAccount2.increaseAllowance(yoloBank.address, ethers.utils.parseUnits("0.6", decimals));
    await runAsAccount2.sell(ethers.utils.parseUnits("0.5", decimals));

    console.log("After selling some tokens");
    await yoloCoin.balanceOf( account1.address ).then( x => console.log("Player1 Balance: " + x ) );
    await yoloCoin.balanceOf( account2.address ).then( x => console.log("Player2 Balance: " + x ) );
    await yoloCoin.balanceOf( yoloBank.address ).then( x => console.log("Bank Reserve: " + x ) );
  });
});

module.exports = { deployYoloCoinContract };