pragma circom 2.2.3;

template Login() {
    signal input a;
    signal input b;
    signal output c;

    c <== a * b;
}

component main = Login();
