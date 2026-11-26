import {
  Account,
  CallData,
  RpcError,
  type RpcProvider,
  Signer,
  cairo,
  hash,
  stark,
} from "starknet";
import type { Session } from "./session.ts";

export type Deployment = {
  verifierClassHash: string;
  accountClassHash: string;
};

const constructorCalldata = (deployment: Deployment, identity: bigint) =>
  CallData.compile([deployment.verifierClassHash, cairo.uint256(identity)]);

// Salt 0 and no deployer: the same address whoever deploys the account
export const accountAddress = (deployment: Deployment, identity: bigint) =>
  hash.calculateContractAddressFromHash(
    0,
    deployment.accountClassHash,
    constructorCalldata(deployment, identity),
    0,
  );

// An account holds several session keys, so the signature names the one that signed
export class SessionSigner extends Signer {
  override async signRaw(msgHash: string) {
    return [
      await this.getPubKey(),
      ...stark.signatureToHexArray(await super.signRaw(msgHash)),
    ];
  }
}

type Signed = { signature?: Parameters<typeof stark.formatSignature>[0] };

// Sends the login proof with the session's first transaction
class SessionAccount extends Account {
  #classHash: string;
  #constructorCalldata: string[];
  #unsentProof: string[] | undefined;
  #checked = false;

  constructor(provider: RpcProvider, deployment: Deployment, session: Session) {
    super({
      provider,
      address: accountAddress(deployment, session.identity),
      signer: new SessionSigner(session.privateKey),
      cairoVersion: "1",
    });
    this.#classHash = deployment.accountClassHash;
    this.#constructorCalldata = constructorCalldata(
      deployment,
      session.identity,
    );
    this.#unsentProof = session.proof;
  }

  override async execute(...[calls, details]: Parameters<Account["execute"]>) {
    if (!this.#checked) await this.#check();
    const sent = await super.execute(calls, details);
    this.#unsentProof = undefined;
    return sent;
  }

  // The fee must cover the proof check, which runs in __validate__
  override estimateFeeBulk(
    ...[invocations, details]: Parameters<Account["estimateFeeBulk"]>
  ) {
    return super.estimateFeeBulk(invocations, {
      ...details,
      skipValidate: false,
    });
  }

  override async buildInvocation(
    ...args: Parameters<Account["buildInvocation"]>
  ) {
    return this.#withProof(await super.buildInvocation(...args));
  }

  override async buildAccountDeployPayload(
    ...args: Parameters<Account["buildAccountDeployPayload"]>
  ) {
    return this.#withProof(await super.buildAccountDeployPayload(...args));
  }

  #withProof<T extends Signed>(tx: T): T {
    if (!this.#unsentProof || !tx.signature) return tx;
    return {
      ...tx,
      signature: [...stark.formatSignature(tx.signature), ...this.#unsentProof],
    };
  }

  async #check() {
    const expiry = await this.#sessionExpiry();
    if (expiry === undefined) await this.#deploy();
    else if (expiry * 1000n > BigInt(Date.now())) this.#unsentProof = undefined;
    this.#checked = true;
  }

  async #sessionExpiry() {
    const response = await this.provider
      .callContract({
        contractAddress: this.address,
        entrypoint: "get_session_expiry",
        calldata: [await this.signer.getPubKey()],
      })
      .catch((e) => {
        if (e instanceof RpcError && e.isType("CONTRACT_NOT_FOUND"))
          return undefined;
        throw e;
      });
    return response && BigInt(response[0] ?? 0);
  }

  async #deploy() {
    const { transaction_hash } = await this.deployAccount({
      classHash: this.#classHash,
      constructorCalldata: this.#constructorCalldata,
    });
    this.#unsentProof = undefined;
    // The next transaction fails until the account exists
    await this.provider.waitForTransaction(transaction_hash, {
      retryInterval: 1000,
    });
  }
}

export const sessionAccount = (
  provider: RpcProvider,
  deployment: Deployment,
  session: Session,
): Account => new SessionAccount(provider, deployment, session);
