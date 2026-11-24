import { constants } from "starknet";
import { loadCircuit, prove } from "./prove.ts";
import { need, serve } from "./serve.ts";

const isFelt = (x: unknown): x is string =>
  typeof x === "string" &&
  /^(0x[0-9a-f]+|\d+)$/i.test(x) &&
  BigInt(x) < constants.PRIME;

const circuit = await loadCircuit(need("CIRCUIT_DIR"));

serve(
  {
    "/prove": async ({ a, b }) => {
      if (!isFelt(a) || !isFelt(b)) throw new Error("a and b must be felts");
      return { proof: await prove(circuit, { a, b }) };
    },
  },
  Number(need("SERVER_PORT")),
);
