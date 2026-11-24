.PHONY: tools test clean devnet up down logs deploy demo

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

clean:
	$(MAKE) -C circuit clean
	$(MAKE) -C chains/starknet/contracts clean
	rm -f chains/starknet/deployments/devnet.env
