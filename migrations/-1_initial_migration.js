const Migrations = artifacts.require('Migrations');



module.exports = async (deployer, network, accounts) => {
  //console.log(accounts);
  //throw new Error();
  await deployer.deploy(Migrations);
};
