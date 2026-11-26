import assert from "node:assert/strict";
import { test } from "node:test";
import { accountAddress, newSession, sessionAccount } from "@0th/starknet";
import {
  CallData,
  RpcProvider,
  cairo,
  ec,
  logger,
  stark,
  type Account,
} from "starknet";

logger.setLogLevel("ERROR");

function need(name: string) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
}

const rpcUrl = need("RPC_URL");
const serverUrl = need("SERVER_URL");
const provider = new RpcProvider({ nodeUrl: rpcUrl });
const deployment = {
  verifierClassHash: need("VERIFIER_CLASS_HASH"),
  accountClassHash: need("ACCOUNT_CLASS_HASH"),
};

const STRK =
  "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d";

const mint = (address: string) =>
  fetch(rpcUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "devnet_mint",
      params: { address, amount: 10e18, unit: "FRI" },
    }),
  });

/// Sends one STRK unit from the account to itself, and returns the signature it carried
async function transfer(account: Account) {
  const { transaction_hash } = await account.execute({
    contractAddress: STRK,
    entrypoint: "transfer",
    calldata: CallData.compile([account.address, cairo.uint256(1)]),
  });
  await provider.waitForTransaction(transaction_hash, { retryInterval: 500 });
  const tx = await provider.getTransactionByHash(transaction_hash);
  assert.ok("signature" in tx);
  return tx.signature;
}

const expiry = async (address: string, privateKey: string) => {
  const [value] = await provider.callContract({
    contractAddress: address,
    entrypoint: "get_session_expiry",
    calldata: [ec.starkCurve.getStarkKey(privateKey)],
  });
  return BigInt(value!);
};

test("a login proof deploys the account, and a second login registers inside a transfer", async () => {
  const identity = BigInt(stark.randomAddress());
  const address = accountAddress(deployment, identity);
  await mint(address);

  // The first transfer deploys the account, which registers the session from the proof
  const first = await newSession(serverUrl, identity);
  const firstAccount = sessionAccount(provider, deployment, first);
  assert.equal((await transfer(firstAccount)).length, 3);
  assert.equal(
    BigInt(await provider.getClassHashAt(address)),
    BigInt(deployment.accountClassHash),
  );
  assert.equal((await transfer(firstAccount)).length, 3);

  // On an existing account, the next session's proof goes with its first transfer
  const second = await newSession(serverUrl, identity);
  const secondAccount = sessionAccount(provider, deployment, second);
  assert.ok((await transfer(secondAccount)).length > 3);
  assert.equal((await transfer(secondAccount)).length, 3);

  assert.equal(await expiry(address, first.privateKey), first.expiry);
  assert.equal(await expiry(address, second.privateKey), second.expiry);
});
