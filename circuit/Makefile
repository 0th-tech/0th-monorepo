.PHONY: image build release test typecheck fmt fmt-check clean fclean

IMAGE = 0th-circuit

image:
	docker build --platform linux/amd64 -q -t $(IMAGE) - < Dockerfile > /dev/null

RUN = docker run --rm --platform linux/amd64 --user "$$(id -u):$$(id -g)" -v "$(CURDIR)":/work $(IMAGE)

SNARKJS = pnpm exec snarkjs

target/login.r1cs target/login_js/login.wasm &: src/login.circom | image
	mkdir -p target
	$(RUN) circom src/login.circom --r1cs --wasm -o target

build: target/login.r1cs

# The 8 below allows a circuit of up to 2^8 = 256 constraints
target/pot.ptau:
	mkdir -p target
	$(SNARKJS) powersoftau new bn128 8 target/pot_0.ptau
	$(SNARKJS) powersoftau contribute target/pot_0.ptau target/pot_1.ptau -e="$$(openssl rand -hex 32)"
	$(SNARKJS) powersoftau prepare phase2 target/pot_1.ptau $@

# Whoever runs this setup could forge proofs, so its keys are for testnets only
release: target/login.r1cs target/pot.ptau
	mkdir -p release
	$(SNARKJS) groth16 setup target/login.r1cs target/pot.ptau target/login_0.zkey
	$(SNARKJS) zkey contribute target/login_0.zkey release/login.zkey -e="$$(openssl rand -hex 32)"
	$(SNARKJS) zkey export verificationkey release/login.zkey release/vk.json
	cp target/login_js/login.wasm release/
	$(SNARKJS) groth16 fullprove fixtures/input.json release/login.wasm release/login.zkey \
		release/proof.json release/public.json
	$(SNARKJS) groth16 verify release/vk.json release/public.json release/proof.json

test: build
	pnpm test

typecheck:
	pnpm run typecheck

fmt:
	pnpm run fmt

fmt-check:
	pnpm run fmt-check

clean:
	rm -rf target

fclean: clean
	docker rmi $(IMAGE) 2>/dev/null || true
