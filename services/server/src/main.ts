import { loadCircuit, prove } from "./prove.ts";
import { need, serve } from "./serve.ts";

// The witness generator reduces a value modulo this order without an error, so a larger value would be proved as another number
const BN254_ORDER =
  21888242871839275222246405745257275088548364400416034343698204186575808495617n;

const isField = (x: unknown): x is string =>
  typeof x === "string" &&
  /^(0x[0-9a-f]+|\d+)$/i.test(x) &&
  BigInt(x) < BN254_ORDER;

const circuit = await loadCircuit(need("CIRCUIT_DIR"));

serve(
  {
    "/prove": async ({ identity, key_hash, iat, session_key, expiry }) => {
      const input = { identity, key_hash, iat, session_key, expiry };
      if (!Object.values(input).every(isField))
        throw new Error(
          "identity, key_hash, iat, session_key and expiry must be BN254 field elements",
        );
      return { proof: await prove(circuit, input) };
    },
  },
  Number(need("SERVER_PORT")),
);
