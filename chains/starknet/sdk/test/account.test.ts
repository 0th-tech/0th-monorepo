import assert from "node:assert/strict";
import { test } from "node:test";
import { ec } from "starknet";
import { SessionSigner, accountAddress } from "../src/account.ts";

test("accountAddress gives the address an account deploys to", () => {
  const address = accountAddress(
    { verifierClassHash: "0x2", accountClassHash: "0x3" },
    5n,
  );

  // A change of this value moves every account to another address
  assert.equal(
    BigInt(address),
    0x23413d279f7622fd94059ea8660550db86ec77fe69495e12b96a90332d051e4n,
  );
});

test("SessionSigner signs as [session_key, r, s]", async () => {
  const privateKey = "0x1234567890abcdef";
  const signer = new SessionSigner(privateKey);

  const [key, r, s, ...rest] = await signer.signRaw("0x123");

  assert.equal(BigInt(key!), BigInt(ec.starkCurve.getStarkKey(privateKey)));
  const signature = new ec.starkCurve.Signature(BigInt(r!), BigInt(s!));
  assert.ok(
    ec.starkCurve.verify(
      signature,
      "0x123",
      ec.starkCurve.getPublicKey(privateKey),
    ),
  );
  assert.deepEqual(rest, []);
});
