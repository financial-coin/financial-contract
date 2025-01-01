// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const { network: { config } } = require("hardhat");

module.exports = buildModule("V1", (m) => {
  const owner = m.getAccount(0);

  const impl = m.contract("Entry", [], { id: "implementation" });
  const data = m.encodeFunctionCall(impl, "initialize", [owner]);
  const proxy = m.contract("ERC1967Proxy", [impl, data]);
  const entry = m.contractAt("Entry", proxy);

  const fundName = config.chainId === 1 ? "FundUsual" : "FundETH";
  const fund = m.contract(fundName);
  m.call(entry, "registerFund", [fund]);

  return { proxy, entry, fund };
});