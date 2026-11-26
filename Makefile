.PHONY: tools test typecheck fmt fmt-check clean devnet up down logs deploy demo fund e2e e2e-test

tools:
	asdf plugin add nodejs
	asdf plugin add pnpm
	asdf plugin add scarb
	asdf plugin add starknet-foundry
	asdf install
	pnpm install --frozen-lockfile

NETWORK ?= devnet
DEPLOYMENT := $(CURDIR)/chains/starknet/deployments/$(NETWORK).env
include chains/starknet/networks/$(NETWORK).env
-include $(DEPLOYMENT)
export

COMPOSE = docker compose -p 0th-$(NETWORK)

devnet:
	$(COMPOSE) up -d --wait devnet

up:
	$(MAKE) -C services/server image
	$(COMPOSE) up -d --wait server

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

deploy:
	$(MAKE) -C chains/starknet/contracts deploy

demo:
	$(MAKE) -C examples/demo dev

# Mints 10 STRK to ADDRESS, with devnet's own method
fund:
	@test "$(NETWORK)" = devnet || { echo "make fund runs on devnet only"; exit 1; }
	@test -n "$(ADDRESS)" || { echo "usage: make fund ADDRESS=0x..."; exit 1; }
	@curl -fsS $(RPC_URL) -H 'content-type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"devnet_mint","params":{"address":"$(ADDRESS)","amount":10000000000000000000,"unit":"FRI"}}'; echo

e2e:
	@test "$(NETWORK)" = devnet || { echo "make e2e runs on devnet only"; exit 1; }
	$(MAKE) down devnet deploy up
	$(MAKE) e2e-test || { $(MAKE) down; exit 1; }
	$(MAKE) down

e2e-test:
	$(MAKE) -C chains/starknet/e2e test

test:
	$(MAKE) -C circuit test
	$(MAKE) -C chains/starknet/contracts test
	$(MAKE) -C chains/starknet/sdk test
	$(MAKE) -C services/server test

typecheck:
	$(MAKE) -C circuit typecheck
	$(MAKE) -C chains/starknet/contracts typecheck
	$(MAKE) -C chains/starknet/sdk typecheck
	$(MAKE) -C chains/starknet/e2e typecheck
	$(MAKE) -C services/server typecheck
	$(MAKE) -C examples/demo typecheck

fmt:
	$(MAKE) -C circuit fmt
	$(MAKE) -C chains/starknet/contracts fmt
	$(MAKE) -C chains/starknet/sdk fmt
	$(MAKE) -C chains/starknet/e2e fmt
	$(MAKE) -C services/server fmt
	$(MAKE) -C examples/demo fmt

fmt-check:
	$(MAKE) -C circuit fmt-check
	$(MAKE) -C chains/starknet/contracts fmt-check
	$(MAKE) -C chains/starknet/sdk fmt-check
	$(MAKE) -C chains/starknet/e2e fmt-check
	$(MAKE) -C services/server fmt-check
	$(MAKE) -C examples/demo fmt-check

clean:
	$(MAKE) -C circuit clean
	$(MAKE) -C chains/starknet/contracts clean
	rm -f chains/starknet/deployments/devnet.env
