import assert from "node:assert/strict";
import { after, test } from "node:test";
import * as snarkjs from "snarkjs";
import input from "../fixtures/input.json" with { type: "json" };
import publicValues from "../release/public.json" with { type: "json" };

const WASM = new URL("../target/login_js/login.wasm", import.meta.url).pathname;
const R1CS = new URL("../target/login.r1cs", import.meta.url).pathname;

// snarkjs keeps the curve's worker threads alive until they are terminated
after(async () => {
  await (
    globalThis as { curve_bn128?: { terminate(): Promise<void> } }
  ).curve_bn128?.terminate();
});

test("the circuit proves the fixture input to the release's public values", async () => {
  const wtns = { type: "mem" } as const;
  await snarkjs.wtns.calculate(input, WASM, wtns);

  const values = (await snarkjs.wtns.exportJson(wtns))
    .slice(1, 1 + publicValues.length)
    .map(String);
  assert.deepEqual(values, publicValues);
  assert.ok(await snarkjs.wtns.check(R1CS, wtns));
});
