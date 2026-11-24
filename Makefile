.PHONY: tools fixtures proof verifier test gas clean fclean

PYTHON_VERSION = 3.12.14
GARAGA_VERSION = 1.1.0
BB_VERSION = 3.0.0-nightly.20251104
BBUP = https://raw.githubusercontent.com/AztecProtocol/aztec-packages/78cb76e3b1914a398233939b5fb801b58a9a222a/barretenberg/bbup/bbup
export PATH := $(CURDIR)/.venv/bin:$(PATH)

SYSTEM = ultra_keccak_zk_honk
VERIFIER = contracts/verifier
# garaga gen writes a whole Scarb project, we only keep its sources
GEN = circuit/target/verifier

tools:
	asdf plugin add nodejs
	asdf plugin add pnpm
	asdf plugin add uv
	asdf plugin add scarb
	asdf plugin add starknet-foundry
	asdf plugin add noir https://github.com/444nt000/asdf-noir.git
	asdf install
	test "$$(.venv/bin/python --version 2>/dev/null)" = "Python $(PYTHON_VERSION)" || \
		uv venv --clear --python $(PYTHON_VERSION) .venv
	uv pip install --python .venv garaga==$(GARAGA_VERSION) fastecdsa==3.0.1
	test "$$(.venv/bin/bb --version 2>/dev/null)" = $(BB_VERSION) || \
		curl -fsSL $(BBUP) | BB_PATH=$(CURDIR)/.venv/bin bash -s -- -v $(BB_VERSION) --no-modify-path

fixtures:
	cd circuit && pnpm install --frozen-lockfile && node scripts/fixture.ts && nargo fmt

proof:
	cd circuit && nargo compile && nargo execute witness
	cd circuit && bb write_vk -s ultra_honk --oracle_hash keccak -b target/login.json -o target/
	cd circuit && bb prove -s ultra_honk --oracle_hash keccak -b target/login.json -w target/witness.gz -o target/

verifier: proof
	rm -rf $(GEN)
	cd circuit/target && garaga gen --system $(SYSTEM) --vk vk --project-name verifier
	rm -f $(VERIFIER)/src/*.cairo
	cp $(GEN)/src/*.cairo $(VERIFIER)/src/
	cp $(GEN)/tests/test_contract.cairo $(VERIFIER)/tests/
	garaga calldata --system $(SYSTEM) --vk circuit/target/vk --proof circuit/target/proof \
		--public-inputs circuit/target/public_inputs --format snforge --output-path $(VERIFIER)/tests
	cd $(VERIFIER) && scarb fmt

test:
	cd circuit && nargo test
	cd contracts && snforge test

gas:
	cd contracts && snforge test --gas-report --exact \
		account_tests::test_register_session::test_register_session_real_proof

clean:
	rm -rf circuit/target contracts/target contracts/.snfoundry_cache

fclean: clean
	rm -rf .venv circuit/node_modules
