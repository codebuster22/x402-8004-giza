# Stage 1: pull Foundry toolchain (forge, cast, anvil, chisel)
FROM ghcr.io/foundry-rs/foundry:latest AS foundry

# Stage 2: runtime with Bun, Node, Git, SSH
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    curl git ssh-client build-essential pkg-config libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Node.js LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Copy forge/cast from Foundry stage
COPY --from=foundry /usr/local/bin/forge /usr/local/bin/forge
COPY --from=foundry /usr/local/bin/cast /usr/local/bin/cast

# Claude CLI
RUN npm install -g @anthropic-ai/claude

# Sensible git defaults; overridden via environment at runtime
ARG GIT_USER_NAME="Claude Code"
ARG GIT_USER_EMAIL="claude@local.dev"
RUN git config --global user.name "$GIT_USER_NAME" && \
    git config --global user.email "$GIT_USER_EMAIL" && \
    git config --global core.safecrlf false && \
    git config --global pull.rebase false

WORKDIR /workspace
CMD ["claude","--dangerously-skip-permissions"]
