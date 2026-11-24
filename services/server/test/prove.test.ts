import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { loadCircuit, toCalldata } from "../src/prove.ts";

const ROOT = new URL("../../../", import.meta.url);
const read = (path: string) => readFileSync(new URL(path, ROOT), "utf8");

test("toCalldata gives the calldata the contracts' tests verify, for the release's proof", async () => {
  const circuit = await loadCircuit(new URL("circuit/release", ROOT).pathname);

  const calldata = toCalldata(
    circuit,
    JSON.parse(read("circuit/release/proof.json")),
    JSON.parse(read("circuit/release/public.json")),
  );

  // Garaga's CLI writes the calldata without the Span length its npm package leads with
  const cli = read(
    "chains/starknet/contracts/verifier/tests/proof_calldata.txt",
  )
    .trim()
    .split("\n")
    .map((felt) => String(BigInt(felt)));
  assert.deepEqual(calldata, [String(cli.length), ...cli]);
});
