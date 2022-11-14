const { expect } = require("chai");

describe("YoloRandom", function () {
  it("Test a random number generator", async function () {
    const [dealer, consumer] = await ethers.getSigners();
    console.log("dealer: " + dealer.address);

    const YoloRandom = await ethers.getContractFactory("YoloRandomMockup");
    const rng = await YoloRandom.deploy(dealer.address);
    await rng.deployed();

    // set consumer
    rng.setConsumer(consumer.address);
    let consumerAccount = rng.connect(consumer);

    let rngTx = await consumerAccount.requestRandomNumber(1);
    let rngReceipt = await rngTx.wait();

    let requestId = rngReceipt.events[0].args[0];

    console.log(requestId.toNumber());
    await consumerAccount.getRandomNumber(requestId).then(x => console.log(x[0].toNumber()));
  });
});