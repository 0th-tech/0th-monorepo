// The snarkjs calls the tests make. @types/snarkjs types a witness as a file name only, where
// snarkjs also takes { type: "mem" } and keeps the witness in that object
declare module "snarkjs" {
  type Witness = string | { type: "mem" };

  export const wtns: {
    calculate(input: object, wasm: string, witness: Witness): Promise<void>;
    exportJson(witness: Witness): Promise<bigint[]>;
    check(r1cs: string, witness: Witness): Promise<boolean>;
  };
}
