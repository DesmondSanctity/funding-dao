// migrations/2_funding_dao_migration.js
const FundingDao = artifacts.require("FundingDao");

module.exports = function (deployer) {
  deployer.deploy(FundingDao);
};