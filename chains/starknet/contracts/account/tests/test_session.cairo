// Project
use account::account::Account::{Event, SessionRegistered};
use account::account::{IAccountDispatcherTrait, MAX_SESSION};

// OpenZeppelin
use openzeppelin_interfaces::accounts::ISRC6DispatcherTrait;

// Snforge
use snforge_std::signature::stark_curve::{StarkCurveKeyPairImpl, StarkCurveSignerImpl};
use snforge_std::{EventSpyAssertionsTrait, spy_events, start_cheat_block_timestamp_global};

// Tests
use crate::utils::helpers::{
    EXPIRY, IDeployValidatorDispatcher, IDeployValidatorDispatcherTrait, PROOF_POINTS_FELTS,
    SESSION_KEY_INPUT, SESSION_PRIVKEY, TX_HASH, cheat_tx, fixture_inputs, load_proof,
    login_signature, mock_proof, session_key,
};
use crate::utils::setup::{fixture_identity, setup, src6};

#[test]
fn test_validate_registers_session() {
    let account = setup("MockVerifier", fixture_identity());
    let inputs = fixture_inputs();
    let proof = mock_proof(inputs.span());
    cheat_tx(account.contract_address, login_signature(TX_HASH, proof.span()).span());
    let mut spy = spy_events();

    let result = src6(account).__validate__(array![]);

    assert_eq!(result, starknet::VALIDATED);
    let session_key = session_key(inputs.span());
    assert_eq!(account.get_session_expiry(session_key), EXPIRY);
    let event = SessionRegistered { session_key, expiry: EXPIRY };
    spy.assert_emitted(@array![(account.contract_address, Event::SessionRegistered(event))]);
}

#[test]
fn test_validate_deploy_registers_session() {
    let account = setup("MockVerifier", fixture_identity());
    let inputs = fixture_inputs();
    let proof = mock_proof(inputs.span());
    cheat_tx(account.contract_address, login_signature(TX_HASH, proof.span()).span());
    let deploy = IDeployValidatorDispatcher { contract_address: account.contract_address };

    let result = deploy.__validate_deploy__(0, 0, 0.try_into().unwrap(), fixture_identity());

    assert_eq!(result, starknet::VALIDATED);
    assert_eq!(account.get_session_expiry(session_key(inputs.span())), EXPIRY);
}

#[test]
#[should_panic(expected: ('invalid proof', 'ENTRYPOINT_FAILED'))]
fn test_validate_rejected_proof() {
    let account = setup("MockVerifierRejecting", fixture_identity());
    let proof = mock_proof(fixture_inputs().span());
    cheat_tx(account.contract_address, login_signature(TX_HASH, proof.span()).span());

    src6(account).__validate__(array![]); // (must panic)
}

#[test]
#[should_panic(expected: ('wrong identity', 'ENTRYPOINT_FAILED'))]
fn test_validate_wrong_identity() {
    // A real proof, but for another user's account
    let account = setup("MockVerifier", fixture_identity() + 1);
    let proof = mock_proof(fixture_inputs().span());
    cheat_tx(account.contract_address, login_signature(TX_HASH, proof.span()).span());

    src6(account).__validate__(array![]); // (must panic)
}

#[test]
#[should_panic(expected: ('wrong session key', 'ENTRYPOINT_FAILED'))]
fn test_validate_proof_for_another_key() {
    let account = setup("MockVerifier", fixture_identity());
    let other = StarkCurveKeyPairImpl::from_secret_key(SESSION_PRIVKEY + 1);
    let (r, s) = other.sign(TX_HASH).unwrap();
    let mut signature = array![other.public_key, r, s];
    signature.append_span(mock_proof(fixture_inputs().span()).span());
    cheat_tx(account.contract_address, signature.span());

    src6(account).__validate__(array![]); // (must panic)
}

#[test]
#[should_panic(expected: ('invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_proof_without_its_key() {
    let account = setup("MockVerifier", fixture_identity());
    let proof = mock_proof(fixture_inputs().span());

    // The proof is read off another transaction, but its session key signs no other hash
    cheat_tx(account.contract_address, login_signature(TX_HASH + 1, proof.span()).span());

    src6(account).__validate__(array![]); // (must panic)
}

#[test]
#[should_panic(expected: ('session expired', 'ENTRYPOINT_FAILED'))]
fn test_validate_expired_proof() {
    let account = setup("MockVerifier", fixture_identity());
    let proof = mock_proof(fixture_inputs().span());
    cheat_tx(account.contract_address, login_signature(TX_HASH, proof.span()).span());

    // The clock is at the session's expiry
    start_cheat_block_timestamp_global(EXPIRY);

    src6(account).__validate__(array![]); // (must panic)
}

#[test]
#[should_panic(expected: ('session too long', 'ENTRYPOINT_FAILED'))]
fn test_validate_session_too_long() {
    let account = setup("MockVerifier", fixture_identity());
    let proof = mock_proof(fixture_inputs().span());
    cheat_tx(account.contract_address, login_signature(TX_HASH, proof.span()).span());

    // The clock is one second too early, so the session is longer than MAX_SESSION
    start_cheat_block_timestamp_global(EXPIRY - MAX_SESSION - 1);

    src6(account).__validate__(array![]); // (must panic)
}

#[test]
#[should_panic(expected: ('session already registered', 'ENTRYPOINT_FAILED'))]
fn test_validate_replay() {
    let account = setup("MockVerifier", fixture_identity());
    let proof = mock_proof(fixture_inputs().span());
    cheat_tx(account.contract_address, login_signature(TX_HASH, proof.span()).span());
    src6(account).__validate__(array![]);

    src6(account).__validate__(array![]); // (must panic)
}

#[test]
#[ignore]
#[fork("SEPOLIA")]
fn test_validate_real_proof() {
    let account = setup("Groth16VerifierBN254", fixture_identity());
    let proof = load_proof();
    cheat_tx(account.contract_address, login_signature(TX_HASH, proof.span()).span());

    src6(account).__validate__(array![]);

    assert_eq!(account.get_session_expiry(session_key(fixture_inputs().span())), EXPIRY);
}

// Garaga's MSM class panics in its hint check before the verifier can return an error
#[test]
#[ignore]
#[fork("SEPOLIA")]
#[should_panic(
    expected: (
        'Wrong GLV/FakeGLV decomposition',
        'ENTRYPOINT_FAILED',
        'ENTRYPOINT_FAILED',
        'ENTRYPOINT_FAILED',
    ),
)]
fn test_validate_real_proof_tampered_session_key() {
    let account = setup("Groth16VerifierBN254", fixture_identity());
    let proof = load_proof();

    // Session key 2 replaces the real one (its low half 2, its high half 0), the rest is unchanged
    let low = PROOF_POINTS_FELTS + 1 + 2 * SESSION_KEY_INPUT;
    let mut tampered = array![];
    for i in 0..proof.len() {
        tampered.append(if i == low {
            2
        } else if i == low + 1 {
            0
        } else {
            *proof[i]
        });
    }
    cheat_tx(account.contract_address, login_signature(TX_HASH, tampered.span()).span());

    src6(account).__validate__(array![]); // (must panic)
}
