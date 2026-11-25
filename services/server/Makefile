.PHONY: image test typecheck fmt fmt-check fclean

IMAGE = 0th-server

image:
	docker build -f Dockerfile -t $(IMAGE) ../..

test:
	pnpm test

typecheck:
	pnpm run typecheck

fmt:
	pnpm run fmt

fmt-check:
	pnpm run fmt-check

fclean:
	docker rmi $(IMAGE) 2>/dev/null || true
