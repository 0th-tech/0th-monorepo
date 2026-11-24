import { readFile } from "node:fs/promises";
import { join } from "node:path";
import {
  CurveId,
  getGroth16CallData,
  init as initGaraga,
  parseGroth16ProofFromObject,
  parseGroth16VerifyingKeyFromObject,
} from "garaga";
import * as snarkjs from "snarkjs";

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
  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    input,
    join(circuit.dir, "login.wasm"),
    join(circuit.dir, "login.zkey"),
  );
  return toCalldata(circuit, proof, publicSignals);
}
