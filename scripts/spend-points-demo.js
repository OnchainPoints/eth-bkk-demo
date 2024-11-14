const { ethers } = require("hardhat");
const readline = require('readline');

// Create readline interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Promisify readline question
const question = (query) => new Promise((resolve) => rl.question(query, resolve));

async function main() {
  // Get contract addresses via prompt
  const onchainPointsAddress = await question("Enter OnchainPoints contract address: ");
  const spendingDemoAddress = await question("Enter SpendingDemo contract address: ");
  
  if (!onchainPointsAddress || !spendingDemoAddress) {
    rl.close();
    throw new Error("Both contract addresses are required");
  }

  // Get signers
  const [owner, user] = await ethers.getSigners();
  
  // Get contract factories
  const SpendingDemo = await ethers.getContractFactory("SpendingDemo");
  // Get contract instances
  const spendingDemo = SpendingDemo.attach(spendingDemoAddress);

  // Update OnchainPoints address in SpendingDemo
  console.log("Updating OnchainPoints address in SpendingDemo...");
  await spendingDemo.updateOnchainPointsAddress(onchainPointsAddress);

  // Prepare spending request
  const amount = ethers.parseEther("1");
  const deadline = Math.floor(Date.now() / 1000) + 3600;
  const nonce = ethers.hexlify(ethers.randomBytes(32));

  // Prepare EIP-712 signature
  const domain = {
    name: "OnchainPointsContract",
    version: "0.1",
    chainId: (await ethers.provider.getNetwork()).chainId,
    verifyingContract: onchainPointsAddress
  };

  const types = {
    Request: [
      { name: "deadline", type: "uint256" },
      { name: "nonce", type: "string" },
      { name: "amount", type: "uint256" }
    ]
  };

  const value = {
    deadline: deadline,
    nonce: nonce,
    amount: amount
  };

  // Sign the request
  console.log("Signing the request...");
  const signature = await user.signTypedData(domain, types, value);

  // Spend tokens using signature
  console.log("Spending tokens...");
  const tx = await spendingDemo.spendTokensWithSignature(
    {
      deadline: deadline,
      nonce: nonce,
      amount: amount
    },
    signature
  );

  // Wait for transaction to be mined
  const receipt = await tx.wait();
  console.log("Transaction successful! Receipt:", receipt.hash);

  // Check updated balances
  const userBalance = await spendingDemo.userBalance(user.address);
  console.log("User balance:", userBalance.toString());
}

main()
  .then(() => {
    rl.close();
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    rl.close();
    process.exit(1);
  });
