import { execFile } from "node:child_process";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import {
  CurveId,
  getGroth16CallData,
  init as initGaraga,
  parseGroth16ProofFromObject,
  parseGroth16VerifyingKeyFromObject,
} from "garaga";

const run = promisify(execFile);

// dir holds the release files: login.zkey, vk.json, login-witness and login-witness.dat
export type Circuit = {
  dir: string;
  verificationKey: ReturnType<typeof parseGroth16VerifyingKeyFromObject>;
};

export async function loadCircuit(dir: string): Promise<Circuit> {
  const [verificationKey] = await Promise.all([
    readFile(join(dir, "vk.json"), "utf8"),
    initGaraga(),
  ]);
  return {
    dir,
    verificationKey: parseGroth16VerifyingKeyFromObject(
      JSON.parse(verificationKey),
    ),
  };
}

export const toCalldata = (
  circuit: Circuit,
  proof: object,
  publicValues: string[],
) =>
  getGroth16CallData(
    parseGroth16ProofFromObject(proof, publicValues.map(BigInt)),
    circuit.verificationKey,
    CurveId.BN254,
  ).map(String);

export async function prove(circuit: Circuit, input: object) {
  const out = await mkdtemp(join(tmpdir(), "prove-"));
  const file = (name: string) => join(out, name);
  try {
    await writeFile(file("input.json"), JSON.stringify(input));
    // Called by full path: the binary loads its .dat from the same path
    await run(join(circuit.dir, "login-witness"), [
      file("input.json"),
      file("witness.wtns"),
    ]);
    await run("rapidsnark", [
      join(circuit.dir, "login.zkey"),
      file("witness.wtns"),
      file("proof.json"),
      file("public.json"),
    ]);
    const [proof, publicValues] = await Promise.all([
      readFile(file("proof.json"), "utf8"),
      readFile(file("public.json"), "utf8"),
    ]);
    return toCalldata(circuit, JSON.parse(proof), JSON.parse(publicValues));
  } finally {
    await rm(out, { recursive: true, force: true });
  }
}
