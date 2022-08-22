require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require('hardhat-abi-exporter');
require('hardhat-contract-sizer');

require("hardhat-gas-trackooor");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
    },
    mumbai: {
      url: "https://matic-mumbai.chainstacklabs.com",
      // url: "https://rpc-mainnet.maticvigil.com/",
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  solidity: {    
    compilers: [
      {
        version: "0.6.12",
      },
      {
        version: "0.8.4",
        settings: {},
      },
      {
        version: "0.8.13",
        settings: {
          // optimizer: {
          //   enabled: true,
          //   runs: 200
          // }
        },
      },
    ], 
  },
  mocha: {
    timeout: 300000
  },
  abiExporter: {
    path: './abi',
    clear: true,
    flat: true,
    except: ['openzeppelin', './interfaces', "./libraries", "./access", "./utils", "./security"]
  },
  // contractSizer: {
  //   alphaSort: true,
  //   disambiguatePaths: false,
  //   runOnCompile: true,
  //   strict: false,
  //   only: [''],
  // }
};
