const Nft = artifacts.require('GrabCoinClub');



module.exports = async (deployer) => {
  await deployer.deploy(Nft);
};
