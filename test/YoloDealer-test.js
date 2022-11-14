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

  await yoloDealer.setRandomProvider(0);
  await yoloDealer.setRNGCapacity(2, true);
  await yoloDealer.setYoloCoin(yoloCoin.address);

  return {yoloDealer, yoloBank, yoloCoin};
};

describe("YoloDealer", function () {
  it("Test yolo dealer and lottery", async function () {
    // setup dealer
    const {yoloDealer} = await loadFixture(deployYoloDealerContract);
    console.log("dealer: " + yoloDealer.address);
  });
});

module.exports = { deployYoloDealerContract };