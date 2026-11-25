.PHONY: tools test typecheck fmt fmt-check clean devnet up down logs deploy demo

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

test:
	$(MAKE) -C circuit test
	$(MAKE) -C chains/starknet/contracts test
	$(MAKE) -C services/server test

typecheck:
	$(MAKE) -C circuit typecheck
	$(MAKE) -C chains/starknet/contracts typecheck
	$(MAKE) -C services/server typecheck
	$(MAKE) -C examples/demo typecheck

fmt:
	$(MAKE) -C circuit fmt
	$(MAKE) -C chains/starknet/contracts fmt
	$(MAKE) -C services/server fmt
	$(MAKE) -C examples/demo fmt

fmt-check:
	$(MAKE) -C circuit fmt-check
	$(MAKE) -C chains/starknet/contracts fmt-check
	$(MAKE) -C services/server fmt-check
	$(MAKE) -C examples/demo fmt-check

clean:
	$(MAKE) -C circuit clean
	$(MAKE) -C chains/starknet/contracts clean
	rm -f chains/starknet/deployments/devnet.env
