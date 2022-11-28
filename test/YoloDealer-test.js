const { loadFixture } = require("@ethereum-waffle/provider");
const { expect } = require("chai");
const { deployYoloCoinContract } = require("./YoloCoin-test");

async function deployYoloDealerContract() {
  const [, dealer] = await ethers.getSigners();

  // setup IRC20 token
  const {yoloBank, yoloCoin} = await loadFixture(deployYoloCoinContract);

  // setup dealer
  const YoloDealer = await ethers.getContractFactory("YoloDealer");
  const yoloDealer = await YoloDealer.deploy();
  await yoloDealer.deployed();

  const YoloRNG = await ethers.getContractFactory("YoloRandomFactory");
  const yoloRNG = await YoloRNG.deploy();
  await yoloRNG.deployed();

  const YoloLot = await ethers.getContractFactory("YoloLotFactory");
  const yoloLot = await YoloLot.deploy();
  await yoloLot.deployed();

  await yoloDealer.setYoloLot(yoloLot.address);
  await yoloDealer.setRandomProvider(0, yoloRNG.address);
  await yoloDealer.setRNGCapacity(2, true);
  await yoloDealer.setYoloCoin(yoloCoin.address);

  return {yoloDealer, yoloBank, yoloCoin};
};

describe("YoloDealer", function () {
  it("Test yolo dealer", async function () {
    // setup dealer
    const {yoloDealer} = await loadFixture(deployYoloDealerContract);
    console.log("dealer: " + yoloDealer.address);
  });
});

module.exports = { deployYoloDealerContract };