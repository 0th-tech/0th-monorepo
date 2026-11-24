use snforge_std::fs::{FileTrait, read_txt};
use snforge_std::{DeclareResultTrait, declare};
use verifier::groth16_verifier::{
    IGroth16VerifierBN254DispatcherTrait, IGroth16VerifierBN254LibraryDispatcher,
};

// The test forks Sepolia for Garaga's MSM class, so it runs on request only, through make gas
#[test]
#[ignore]
#[fork("SEPOLIA")]
fn test_verify_release_proof() {
    let class_hash = *declare("Groth16VerifierBN254").unwrap().contract_class().class_hash;
    let verifier = IGroth16VerifierBN254LibraryDispatcher { class_hash };
    let calldata = read_txt(@FileTrait::new("tests/proof_calldata.txt")).span();

    assert!(verifier.verify_groth16_proof_bn254(calldata).is_ok());
}
