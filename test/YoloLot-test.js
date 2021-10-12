const { expect } = require("chai");

describe("YoloLot", function () {
  it("Test a lottery contract", async function () {
    const [dealer] = await ethers.getSigners();
    console.log("dealer: " + dealer.address);

    const YoloCoin = await ethers.getContractFactory("YoloCoin");
    const coin = await YoloCoin.deploy("YoloCoin");


    // const YoloLot = await ethers.getContractFactory("YoloLot");
    // const lot = await YoloLot.deploy(dealer.address);
    // await lot.deployed();

  });
});