#[starknet::interface]
pub trait IAccount<TContractState> {
    fn get_session_expiry(self: @TContractState, session_key: felt252) -> u64;
}

// Longest session a proof may ask for (30 days)
pub const MAX_SESSION: u64 = 30 * 24 * 3600;

#[starknet::contract(account)]
pub mod Account {
    // Core
    use core::num::traits::Zero;

    // OpenZeppelin
    use openzeppelin_account::utils::{is_tx_version_valid, is_valid_stark_signature};
    use openzeppelin_interfaces::accounts::ISRC6_ID;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_utils::execution::execute_calls;

    // Starknet
    use starknet::account::Call;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, get_block_timestamp, get_caller_address, get_tx_info};

    // Verifier
    use verifier::groth16_verifier::{
        IGroth16VerifierBN254DispatcherTrait, IGroth16VerifierBN254LibraryDispatcher,
    };
    use super::MAX_SESSION;

    // The login proof's public values, in order: identity, key hash, iat, session key, expiry
    const IDENTITY_INPUT: usize = 0;
    const SESSION_KEY_INPUT: usize = 3;
    const EXPIRY_INPUT: usize = 4;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        verifier_class: ClassHash,
        identity_hash: u256, // H(iss, aud, sub, salt), BN254 field element
        sessions: Map<felt252, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        SessionRegistered: SessionRegistered,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct SessionRegistered {
        #[key]
        pub session_key: felt252,
        pub expiry: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, verifier_class: ClassHash, identity_hash: u256) {
        self.src5.register_interface(ISRC6_ID);

        self.verifier_class.write(verifier_class);
        self.identity_hash.write(identity_hash);
    }

    #[abi(embed_v0)]
    impl AccountImpl of super::IAccount<ContractState> {
        fn get_session_expiry(self: @ContractState, session_key: felt252) -> u64 {
            self.sessions.read(session_key)
        }
    }

    #[external(v0)]
    fn __validate__(ref self: ContractState, calls: Array<Call>) -> felt252 {
        validate_transaction(ref self)
    }

    // The account deploys itself, paid from its own balance, and registers its first session
    #[external(v0)]
    fn __validate_deploy__(
        ref self: ContractState,
        class_hash: felt252,
        contract_address_salt: felt252,
        verifier_class: ClassHash,
        identity_hash: u256,
    ) -> felt252 {
        validate_transaction(ref self)
    }

    #[external(v0)]
    fn is_valid_signature(
        self: @ContractState, hash: felt252, signature: Array<felt252>,
    ) -> felt252 {
        let signature = signature.span();
        let valid = signature.len() == 3
            && live_session(self, *signature[0])
            && signed_by_session(hash, signature);
        if valid {
            starknet::VALIDATED
        } else {
            0
        }
    }

    #[external(v0)]
    fn __execute__(self: @ContractState, calls: Array<Call>) {
        assert(get_caller_address().is_zero(), 'invalid caller');
        assert(is_tx_version_valid(), 'invalid tx version');

        execute_calls(calls.span());
    }

    // A session's first transaction signs [session_key, r, s, proof]; the proof registers the key.
    // The session's other transactions sign [session_key, r, s].
    fn validate_transaction(ref self: ContractState) -> felt252 {
        let tx_info = get_tx_info().unbox();
        let signature = tx_info.signature;
        assert(signature.len() >= 3, 'invalid signature length');
        let session_key = *signature[0];
        if signature.len() > 3 {
            register_session(ref self, session_key, signature.slice(3, signature.len() - 3));
        }
        assert(live_session(@self, session_key), 'invalid session');
        assert(signed_by_session(tx_info.transaction_hash, signature), 'invalid signature');
        starknet::VALIDATED
    }

    // Runs in validation, before any fee is charged, so a false proof costs nothing
    fn register_session(ref self: ContractState, session_key: felt252, proof: Span<felt252>) {
        // Validation may not call another contract, so the verifier's code runs as a library call
        let inputs = IGroth16VerifierBN254LibraryDispatcher {
            class_hash: self.verifier_class.read(),
        }
            .verify_groth16_proof_bn254(proof)
            .expect('invalid proof');

        assert(*inputs[IDENTITY_INPUT] == self.identity_hash.read(), 'wrong identity');
        assert(*inputs[SESSION_KEY_INPUT] == session_key.into(), 'wrong session key');

        // An expiry past u64 is past any block time plus MAX_SESSION
        let expiry: u64 = (*inputs[EXPIRY_INPUT]).try_into().expect('session too long');
        let now = get_block_timestamp();
        assert(expiry > now, 'session expired');
        assert(expiry <= now + MAX_SESSION, 'session too long');

        // A session key registers once, so its proof cannot set its expiry again
        assert(self.sessions.read(session_key) == 0, 'session already registered');

        self.sessions.write(session_key, expiry);
        self.emit(SessionRegistered { session_key, expiry });
    }

    // An unknown key reads as expiry 0, so it fails like an expired one
    fn live_session(self: @ContractState, session_key: felt252) -> bool {
        get_block_timestamp() < self.sessions.read(session_key)
    }

    fn signed_by_session(hash: felt252, signature: Span<felt252>) -> bool {
        is_valid_stark_signature(hash, *signature[0], signature.slice(1, 2))
    }
}
