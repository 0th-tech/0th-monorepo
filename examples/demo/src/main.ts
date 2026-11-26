import { accountAddress, newSession, sessionAccount } from "@0th/starknet";
import { CallData, RpcProvider, cairo, stark, uint256 } from "starknet";

// Vite inlines these at build time, so a missing one is undefined in the bundle
function need(name: string) {
  const value = import.meta.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
}

const provider = new RpcProvider({ nodeUrl: need("VITE_RPC_URL") });
const serverUrl = need("VITE_SERVER_URL");
const deployment = {
  verifierClassHash: need("VITE_VERIFIER_CLASS_HASH"),
  accountClassHash: need("VITE_ACCOUNT_CLASS_HASH"),
};

const STRK =
  "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d";

// Kept across reloads, so every click is a new session on the same account
const IDENTITY = "0th.demo.identity";
const identity = BigInt(
  localStorage.getItem(IDENTITY) ?? stark.randomAddress(),
);
localStorage.setItem(IDENTITY, String(identity));
const address = accountAddress(deployment, identity);

const log = document.getElementById("log")!;
const say = (line: string) => (log.textContent += line + "\n");
const seconds = (since: number) =>
  `${((performance.now() - since) / 1000).toFixed(1)}s`;

async function balance() {
  const [low, high] = await provider.callContract({
    contractAddress: STRK,
    entrypoint: "balance_of",
    calldata: [address],
  });
  return uint256.uint256ToBN({ low: low!, high: high! });
}

async function run() {
  log.textContent = "";
  try {
    // The account pays for its own deploy and transactions
    if ((await balance()) === 0n) {
      say(`send STRK to ${address}, then run again`);
      return;
    }

    let since = performance.now();
    const session = await newSession(serverUrl, identity);
    say(`session key proved in ${seconds(since)}`);

    since = performance.now();
    const { transaction_hash } = await sessionAccount(
      provider,
      deployment,
      session,
    ).execute({
      contractAddress: STRK,
      entrypoint: "transfer",
      calldata: CallData.compile([address, cairo.uint256(1)]),
    });
    await provider.waitForTransaction(transaction_hash, {
      retryInterval: 1000,
    });
    say(`transfer ${transaction_hash} accepted in ${seconds(since)}`);
  } catch (e) {
    say(`error: ${e}`);
    console.error(e);
  }
}

document.getElementById("run")!.onclick = run;
document.getElementById("account")!.textContent = `account ${address}`;
