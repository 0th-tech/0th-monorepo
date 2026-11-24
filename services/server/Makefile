.PHONY: image test fclean

IMAGE = 0th-server

# The image holds the circuit's release, so it builds from the repo's root
image:
	docker build -f Dockerfile -t $(IMAGE) ../..

test:
	pnpm test

fclean:
	docker rmi $(IMAGE) 2>/dev/null || true
