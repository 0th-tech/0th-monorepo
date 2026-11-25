import { readFileSync, writeFileSync } from "node:fs";
import {
  Account,
  RpcProvider,
  logger,
  type CairoAssembly,
  type CompiledSierra,
} from "starknet";

logger.setLogLevel("ERROR");

// The hash Garaga's verifier library-calls its MSM class by
const GARAGA_MSM_CLASS =
  0x396d5915ecf475aab117bb25a0272b261e9e25ffe1c0ce05a51a3f77489c89en;

function need(name: string) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
}

const deployment = process.argv[2];
if (!deployment) throw new Error("usage: node deploy.ts <deployment file>");
const provider = new RpcProvider({ nodeUrl: need("RPC_URL") });
const deployer = new Account({
  provider,
  address: need("DEPLOYER_ADDRESS"),
  signer: need("DEPLOYER_PRIVATE_KEY"),
});

const read = (path: string) =>
  JSON.parse(readFileSync(new URL(path, import.meta.url), "utf8"));

async function declare(contract: CompiledSierra, casm: CairoAssembly) {
  const { class_hash, transaction_hash } = await deployer.declareIfNot({
    contract,
    casm,
  });
  if (transaction_hash) await provider.waitForTransaction(transaction_hash);
  return class_hash;
}

// Garaga's MSM class, which Sepolia and mainnet already hold and a devnet gets from the copy in garaga/
const msm = read("garaga/msm.contract_class.json");
const msmClass = await declare(
  // The copy holds the ABI as a string, which starknet.js takes parsed
  { ...msm, abi: JSON.parse(msm.abi) },
  read("garaga/msm.compiled_contract_class.json"),
);
if (BigInt(msmClass) !== GARAGA_MSM_CLASS)
  throw new Error(`Garaga's MSM class declared as ${msmClass}`);

const verifierClass = await declare(
  read("target/release/verifier_Groth16VerifierBN254.contract_class.json"),
  read(
    "target/release/verifier_Groth16VerifierBN254.compiled_contract_class.json",
  ),
);
const { contract_address, transaction_hash } = await deployer.deployContract({
  classHash: verifierClass,
});
await provider.waitForTransaction(transaction_hash);

// Each account deploys itself, so only its class is declared here
const accountClass = await declare(
  read("target/release/account_Account.contract_class.json"),
  read("target/release/account_Account.compiled_contract_class.json"),
);

const lines = `VERIFIER=${contract_address}\nACCOUNT_CLASS_HASH=${accountClass}\n`;
writeFileSync(deployment, lines);
console.log(lines.trim());
