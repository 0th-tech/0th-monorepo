.PHONY: image build release test typecheck fmt fmt-check clean fclean

IMAGE = 0th-circuit

image:
	docker build --platform linux/amd64 -q -t $(IMAGE) - < Dockerfile > /dev/null

RUN = docker run --rm --platform linux/amd64 --user "$$(id -u):$$(id -g)" -v "$(CURDIR)":/work $(IMAGE)

SNARKJS = pnpm exec snarkjs

# The r1cs and both witness generators need the same -O level, or the signal order won't match
target/login.r1cs target/login_js/login.wasm target/login_cpp/login.cpp &: src/login.circom | image
	mkdir -p target
	$(RUN) circom src/login.circom --r1cs --wasm --c --O2 -o target

build: target/login.r1cs

# The 8 below allows a circuit of up to 2^8 = 256 constraints
target/pot.ptau:
	mkdir -p target
	$(SNARKJS) powersoftau new bn128 8 target/pot_0.ptau
	$(SNARKJS) powersoftau contribute target/pot_0.ptau target/pot_1.ptau -e="$$(openssl rand -hex 32)"
	$(SNARKJS) powersoftau prepare phase2 target/pot_1.ptau $@

# Whoever runs this setup could forge proofs, so its keys are for testnets only
release: target/login.r1cs target/login_cpp/login.cpp target/pot.ptau
	rm -rf release && mkdir release
	$(SNARKJS) groth16 setup target/login.r1cs target/pot.ptau target/login_0.zkey
	$(SNARKJS) zkey contribute target/login_0.zkey release/login.zkey -e="$$(openssl rand -hex 32)"
	$(SNARKJS) zkey export verificationkey release/login.zkey release/vk.json
	cd target && b2sum login.r1cs > ../release/login.r1cs.b2sum
# The binary loads <its path>.dat, so both files keep the same name
	$(RUN) make -s -C target/login_cpp
	cp target/login_cpp/login release/login-witness
	cp target/login_cpp/login.dat release/login-witness.dat
# Uses the server's witness generator, so the release tests it
	$(RUN) release/login-witness fixtures/input.json target/fixture.wtns
	$(SNARKJS) groth16 prove release/login.zkey target/fixture.wtns release/proof.json release/public.json
	$(SNARKJS) groth16 verify release/vk.json release/public.json release/proof.json

test: build
	cd target && b2sum --quiet -c ../release/login.r1cs.b2sum
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
