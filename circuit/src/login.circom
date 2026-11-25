pragma circom 2.2.3;

template Login() {
    signal input identity;
    signal input key_hash;
    signal input iat;
    signal input session_key;
    signal input expiry;
}

component main { public [identity, key_hash, iat, session_key, expiry] } = Login();
