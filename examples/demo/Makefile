.PHONY: dev typecheck fmt fmt-check

export VITE_RPC_URL = $(RPC_URL)
export VITE_SERVER_URL = $(SERVER_URL)
export VITE_VERIFIER_CLASS_HASH = $(VERIFIER_CLASS_HASH)
export VITE_ACCOUNT_CLASS_HASH = $(ACCOUNT_CLASS_HASH)

dev:
	pnpm run dev

typecheck:
	pnpm run typecheck

fmt:
	pnpm run fmt

fmt-check:
	pnpm run fmt-check
