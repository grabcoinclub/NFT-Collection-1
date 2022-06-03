const Token = artifacts.require('GrabClub');



module.exports = async (deployer) => {
  await deployer.deploy(Token);
};
