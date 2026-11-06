# Minimal agent-run sandbox: git + CA roots and nothing else.
# Pinned by digest so an image rebuild cannot silently change the boundary.
FROM debian:bookworm-slim@sha256:734a72b3d6142a71993b4bc580ca01d8ca687f77a2c422d96a961d3376b179bc

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# The agent binary is bind-mounted read-only at run time by evals/lib/sandbox.sh;
# it is deliberately not baked into the image.
WORKDIR /tmp
