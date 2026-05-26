# Devcontainer for ml-reentry-mlir.
#
# Base: NVIDIA CUDA 13.0 devel on Ubuntu 24.04. The host's NVIDIA driver
# (Windows R581.57) reports CUDA 13.0 support, so we pin to the 13.0.x series.
# Newer 13.x toolkits exist (13.1.x, 13.2.x) but may require a newer driver.
# Bump this tag — and update internal-docs/repo-setup-plan.md — if the host
# driver is updated.
FROM nvidia/cuda:13.0.3-devel-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

# ---------- System packages ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build toolchain
    clang \
    lld \
    cmake \
    ninja-build \
    ccache \
    pkg-config \
    git \
    # Python (3.12 on noble)
    python3 \
    python3-dev \
    python3-venv \
    # MLIR build deps
    zlib1g-dev \
    libtinfo-dev \
    libxml2-dev \
    libedit-dev \
    # Supporting utilities
    curl \
    ca-certificates \
    gnupg \
    sudo \
    unzip \
    less \
    procps \
    openssh-client \
    # Debug
    gdb \
    lldb \
    # Process manager for entrypoint signals (used by VS Code dev container)
    locales \
    # Dev utils
    vim \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ---------- User setup ----------
# Base CUDA image is root-only. Create a vscode user matching the WSL host
# UID 1000 so bind mounts have correct ownership. If a user with UID/GID 1000
# already exists (e.g., 'ubuntu' on noble), reuse it by renaming.
RUN if id -u ${USER_UID} >/dev/null 2>&1; then \
        existing_user=$(id -un ${USER_UID}); \
        if [ "$existing_user" != "${USERNAME}" ]; then \
            usermod -l ${USERNAME} -d /home/${USERNAME} -m ${existing_user}; \
            groupmod -n ${USERNAME} $(id -gn ${USER_UID}); \
        fi; \
    else \
        groupadd --gid ${USER_GID} ${USERNAME} && \
        useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME}; \
    fi \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# ---------- uv (Python package manager) ----------
USER ${USERNAME}
WORKDIR /home/${USERNAME}
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH=/home/${USERNAME}/.local/bin:${PATH}

# ---------- Cache and venv layout ----------
# Everything project-cacheable lives on /x/cache so it survives image rebuilds
# and is shared across git worktrees.
ENV UV_PROJECT_ENVIRONMENT=/x/cache/venv
ENV UV_CACHE_DIR=/x/cache/uv-cache
ENV CCACHE_DIR=/x/cache/ccache
ENV CCACHE_MAXSIZE=20G
ENV CMAKE_GENERATOR=Ninja
# /x/cache/venv/bin precedes the system path so `python` / `gnnc` resolve
# correctly after `uv sync`.
ENV PATH=/x/cache/venv/bin:${PATH}

# Project-scoped env vars consumed by harness scripts and Python code.
# Do NOT hardcode /x/data or /x/cache in source files; read these instead.
ENV GNNC_CACHE_DIR=/x/cache
ENV GNNC_DATA_DIR=/x/data
# Will be populated by tools/build-llvm.sh and tools/build-torch-mlir.sh.
ENV LLVM_BUILD=/x/cache/build/llvm
ENV TORCH_MLIR_BUILD=/x/cache/build/torch-mlir

WORKDIR /x/workspace
