const { expect } = require("chai");

describe("SimpleCharity", function () {
  it("Test a simple chairy contract", async function () {
    const [owner, account1, account2] = await ethers.getSigners();
    console.log("owner: " + owner.address);
    console.log("donor 1: " + account1.address);
    console.log("donor 2: " + account2.address);
    const SimpleCharity = await ethers.getContractFactory("SimpleCharity");
    const goFundMe = await SimpleCharity.deploy(owner.address);
    await goFundMe.deployed();

    // display beneficial party
    await goFundMe.getReceiver().then(x => console.log("reciver: " + x ));

    // deposit donations to the contract
    let runAsAccount1 = goFundMe.connect(account1);
    let runAsAccount2 = goFundMe.connect(account2);

    await runAsAccount1.deposit({from:account1.address, value:ethers.utils.parseEther("1.0")});
    await runAsAccount2.deposit({from:account2.address, value:ethers.utils.parseEther("2.0")});
    
    // display top donators
    let [top10Address, top10Amounts] = await goFundMe.getTopDonator();

    await runAsAccount1.getDonation().then(x => console.log("account1 donation: " + x ));
    await runAsAccount2.getDonation().then(x => console.log("account2 donation: " + x ));
    console.log(top10Address);
    console.log(top10Amounts);

    // withdraw the fund, you can try replace the following call by runAsAccount1
    // the contract implementation assure that only the owner of the contract can withdraw
    // otherwise throw error.
    await ethers.provider.getBalance( owner.address ).then( x => console.log("Owner wealth prior withdrawal: " + x ) ); 
    await ethers.provider.getBalance( goFundMe.address ).then( x => console.log("Avaiable Fund Prior withdrawal: " + x ) );
    await goFundMe.withdraw( {from:owner.address} );
    await ethers.provider.getBalance( owner.address ).then( x => console.log("Owner wealth post withdrawal: " + x ) );
    await ethers.provider.getBalance( goFundMe.address ).then( x => console.log("Avaiable Fund Post withdrawal: " + x ) );
  });
});
