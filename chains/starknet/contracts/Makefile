.PHONY: image verifier build test gas deploy clean fclean

IMAGE = 0th-contracts

image:
	docker build -q -t $(IMAGE) - < Dockerfile > /dev/null

RUN = docker run --rm --user "$$(id -u):$$(id -g)" -v "$(abspath ../../..)":/work \
	-w /work/chains/starknet/contracts $(IMAGE) bash -c

RELEASE = /work/circuit/release

verifier: image
	$(RUN) '\
		rm -rf /tmp/verifier && \
		(cd /tmp && garaga gen --system groth16 --vk $(RELEASE)/vk.json --project-name verifier) && \
		rm -f verifier/src/*.cairo && \
		cp /tmp/verifier/src/*.cairo verifier/src/ && \
		garaga calldata --system groth16 --vk $(RELEASE)/vk.json --proof $(RELEASE)/proof.json \
			--public-inputs $(RELEASE)/public.json --format snforge --output-path verifier/tests && \
		cd verifier && scarb fmt \
	'

build:
	scarb --release build

test:
	snforge test

# A keyed RPC set here goes past the public one's rate limit
export SEPOLIA_RPC_URL ?= https://api.zan.top/public/starknet-sepolia/rpc/v0_10

gas:
	snforge test --include-ignored --gas-report

deploy: build
	mkdir -p $(dir $(DEPLOYMENT))
	node deploy.ts $(DEPLOYMENT)

clean:
	rm -rf target .snfoundry_cache

fclean: clean
	docker rmi $(IMAGE) 2>/dev/null || true
