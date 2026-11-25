// Project
use account::account::IAccountDispatcher;

// OpenZeppelin
use openzeppelin_interfaces::accounts::{ISRC6Dispatcher, ISRC6DispatcherTrait};

// Snforge
use snforge_std::start_cheat_block_timestamp_global;

// Tests
use crate::utils::helpers::{
    EXPIRY, IDENTITY_INPUT, TX_HASH, cheat_tx, deploy_contract, fixture_inputs, login_signature,
    mock_proof, session_signature,
};

pub fn setup(verifier: ByteArray, identity_hash: u256) -> IAccountDispatcher {
    // The clock starts one day before the fixture expires
    start_cheat_block_timestamp_global(EXPIRY - 24 * 3600);

    let verifier_address = deploy_contract(verifier, array![]);

    let mut calldata = array![];
    Serde::serialize(@verifier_address, ref calldata);
    Serde::serialize(@identity_hash, ref calldata);
    IAccountDispatcher { contract_address: deploy_contract("Account", calldata) }
}

/// Deploys an account holding the fixture's session, then signs the next transactions with it
pub fn setup_session() -> IAccountDispatcher {
    let account = setup("MockVerifier", fixture_identity());
    let proof = mock_proof(fixture_inputs().span());
    cheat_tx(account.contract_address, login_signature(TX_HASH, proof.span()).span());
    src6(account).__validate__(array![]);

    cheat_tx(account.contract_address, session_signature(TX_HASH).span());
    account
}

pub fn fixture_identity() -> u256 {
    *fixture_inputs()[IDENTITY_INPUT]
}

/// The account's SRC6 entry points: __validate__, __execute__ and is_valid_signature
pub fn src6(account: IAccountDispatcher) -> ISRC6Dispatcher {
    ISRC6Dispatcher { contract_address: account.contract_address }
}
