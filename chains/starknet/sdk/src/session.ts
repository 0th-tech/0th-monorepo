import { ec, encode } from "starknet";
import { prove } from "./server.ts";

const HOUR = 3600;
const MAX_SESSION = 30 * 24 * HOUR;

export type Session = {
  // Hash of the user's id obtained from the login provider, the dapp's OAuth client id, and a salt
  identity: bigint;
  privateKey: string;
  expiry: bigint;
  proof: string[];
};

export async function newSession(
  serverUrl: string,
  identity: bigint,
  // One hour of margin: the block's clock can be behind the browser's
  sessionLength = MAX_SESSION - HOUR,
): Promise<Session> {
  if (!(sessionLength > 0 && sessionLength < MAX_SESSION))
    throw new Error("sessionLength must be above 0 and under 30 days");

  const privateKey = encode.addHexPrefix(
    encode.buf2hex(ec.starkCurve.utils.randomPrivateKey()),
  );
  const now = Math.floor(Date.now() / 1000);
  const expiry = BigInt(now + sessionLength);
  const proof = await prove(serverUrl, {
    identity: String(identity),
    key_hash: "0",
    iat: String(now),
    session_key: String(BigInt(ec.starkCurve.getStarkKey(privateKey))),
    expiry: String(expiry),
  });
  return { identity, privateKey, expiry, proof };
}
