import { RpcProvider, stark } from "starknet";

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

async function run() {
  log.textContent = "";
  try {
    const now = Math.floor(Date.now() / 1000);
    const input = {
      identity: stark.randomAddress(),
      key_hash: stark.randomAddress(),
      iat: String(now),
      session_key: stark.randomAddress(),
      expiry: String(now + 3600),
    };
    const res = await fetch(`${serverUrl}/prove`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(input),
    });
    const body = await res.json();
    if (!res.ok) throw new Error(body.error);
    say(`proof: ${body.proof.length} felts`);

    // The verifier returns 0 for Ok, the number of public values, then each value as two 128-bit halves
    const [variant, , ...halves] = await provider.callContract({
      contractAddress: verifier,
      entrypoint: "verify_groth16_proof_bn254",
      calldata: body.proof,
    });
    if (BigInt(variant!) !== 0n)
      throw new Error("the verifier rejected the proof");
    Object.entries(input).forEach(([name, sent], i) => {
      const proved =
        BigInt(halves[2 * i]!) + (BigInt(halves[2 * i + 1]!) << 128n);
      say(
        `${name}: ${proved === BigInt(sent) ? "as sent" : `${proved}, sent ${sent}`}`,
      );
    });
  } catch (e) {
    say(`error: ${e}`);
    console.error(e);
  }
}

document.getElementById("run")!.onclick = run;
