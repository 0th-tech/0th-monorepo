// The snarkjs call the server makes
declare module "snarkjs" {
  export const groth16: {
    fullProve(
      input: object,
      wasm: string,
      zkey: string,
    ): Promise<{ proof: object; publicSignals: string[] }>;
  };
}
