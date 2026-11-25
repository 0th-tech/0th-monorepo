import { RpcProvider } from "starknet";

// Vite inlines import.meta.env at build time, so an unset variable is undefined in the bundle
function need(name: string) {
  const value = import.meta.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
}

const provider = new RpcProvider({ nodeUrl: need("VITE_RPC_URL") });
const serverUrl = need("VITE_SERVER_URL");
const verifier = need("VITE_VERIFIER");

const log = document.getElementById("log")!;
const say = (line: string) => (log.textContent += line + "\n");

const randomFactor = () => BigInt(1 + Math.floor(Math.random() * 1000));

async function run() {
  log.textContent = "";
  try {
    const a = randomFactor();
    const b = randomFactor();
    const res = await fetch(`${serverUrl}/prove`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ a: String(a), b: String(b) }),
    });
    const body = await res.json();
    if (!res.ok) throw new Error(body.error);
    say(`proof of ${a} * ${b} = ${a * b}: ${body.proof.length} felts`);

    // The verifier returns 0 for Ok, then the number of public values, then c as two 128-bit halves
    const [variant, , low, high] = await provider.callContract({
      contractAddress: verifier,
      entrypoint: "verify_groth16_proof_bn254",
      calldata: body.proof,
    });
    if (BigInt(variant!) !== 0n)
      throw new Error("the verifier rejected the proof");
    const c = BigInt(low!) + (BigInt(high!) << 128n);
    say(`verifier on chain: valid, public value c = ${c}`);
  } catch (e) {
    say(`error: ${e}`);
    console.error(e);
  }
}

document.getElementById("run")!.onclick = run;
