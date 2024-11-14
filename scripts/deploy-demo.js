const { ethers, upgrades } = require("hardhat");

async function main() {
  console.log("Deploying SpendingDemo contract...");

  // Get the contract factory
  const SpendingDemo = await ethers.getContractFactory("SpendingDemo");

  // Get the deployer's address
  const [deployer] = await ethers.getSigners();
  
  // Deploy the contract as a UUPS proxy
  const spendingDemo = await upgrades.deployProxy(
    SpendingDemo,
    [deployer.address],
    { kind: "uups" }
  );

  // Wait for the deployment to be confirmed
  await spendingDemo.waitForDeployment();

  const owner = await spendingDemo.owner();
  console.log("Owner:", owner);

  const spendingDemoAddress = await spendingDemo.getAddress();
  console.log("SpendingDemo deployed to:", spendingDemoAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
