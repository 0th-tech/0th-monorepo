// OpenZeppelin
use openzeppelin_interfaces::accounts::{ISRC6DispatcherTrait, ISRC6_ID};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};

// Snforge
use snforge_std::signature::stark_curve::StarkCurveKeyPairImpl;
use snforge_std::{start_cheat_block_timestamp_global, stop_cheat_caller_address};

// Starknet
use starknet::account::Call;

// Tests
use crate::utils::helpers::{
    EXPIRY, SESSION_PRIVKEY, TX_HASH, cheat_tx, fixture_inputs, session_key, session_signature,
};
use crate::utils::setup::{fixture_identity, setup, setup_session, src6};

#[test]
fn test_fixture_session_key() {
    let key_pair = StarkCurveKeyPairImpl::from_secret_key(SESSION_PRIVKEY);

    assert_eq!(key_pair.public_key, session_key(fixture_inputs().span()));
}

#[test]
fn test_validate() {
    let account = setup_session();

    let result = src6(account).__validate__(array![]);

    assert_eq!(result, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('invalid session', 'ENTRYPOINT_FAILED'))]
fn test_validate_unknown_session() {
    let account = setup("MockVerifier", fixture_identity());
    cheat_tx(account.contract_address, session_signature(TX_HASH).span());

    src6(account).__validate__(array![]); // (must panic)
}

#[test]
#[should_panic(expected: ('invalid session', 'ENTRYPOINT_FAILED'))]
fn test_validate_expired_session() {
    let account = setup_session();
    start_cheat_block_timestamp_global(EXPIRY);

    src6(account).__validate__(array![]); // (must panic)
}

#[test]
#[should_panic(expected: ('invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_wrong_tx_hash() {
    let account = setup_session();
    cheat_tx(account.contract_address, session_signature(TX_HASH + 1).span());

    src6(account).__validate__(array![]); // (must panic)
}

#[test]
#[should_panic(expected: ('invalid signature length', 'ENTRYPOINT_FAILED'))]
fn test_validate_signature_without_key() {
    let account = setup_session();
    cheat_tx(account.contract_address, session_signature(TX_HASH).span().slice(1, 2));

    src6(account).__validate__(array![]); // (must panic)
}

#[test]
fn test_supports_src6() {
    let account = setup("MockVerifier", fixture_identity());

    // A dapp looks the account up by this id before trusting is_valid_signature
    let src5 = ISRC5Dispatcher { contract_address: account.contract_address };

    assert!(src5.supports_interface(ISRC6_ID));
}

#[test]
fn test_is_valid_signature() {
    let account = setup_session();

    let result = src6(account).is_valid_signature(TX_HASH, session_signature(TX_HASH));

    assert_eq!(result, starknet::VALIDATED);
}

#[test]
fn test_is_valid_signature_rejected() {
    let account = setup_session();
    let signature = session_signature(TX_HASH);

    // A real signature of another hash
    assert_eq!(src6(account).is_valid_signature(TX_HASH + 1, signature.clone()), 0);

    // A plain [r, s], as wallet libraries send it
    assert_eq!(src6(account).is_valid_signature(TX_HASH, array![*signature[1], *signature[2]]), 0);

    // The clock is at the session's expiry
    start_cheat_block_timestamp_global(EXPIRY);
    assert_eq!(src6(account).is_valid_signature(TX_HASH, signature), 0);
}

#[test]
fn test_is_valid_signature_unknown_session() {
    let account = setup("MockVerifier", fixture_identity());

    // An unregistered key has expiry 0, so it fails like an expired one
    assert_eq!(src6(account).is_valid_signature(TX_HASH, session_signature(TX_HASH)), 0);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_execute_runs_calls() {
    let account = setup_session();
    let call = Call {
        to: account.contract_address,
        selector: selector!("no_such_entry_point"),
        calldata: [].span(),
    };

    src6(account).__execute__(array![call]); // (must panic)
}

#[test]
#[should_panic(expected: ('invalid caller', 'ENTRYPOINT_FAILED'))]
fn test_execute_from_contract() {
    let account = setup_session();
    stop_cheat_caller_address(account.contract_address);

    src6(account).__execute__(array![]); // (must panic)
}
