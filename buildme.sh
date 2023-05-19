#!/usr/bin/env sh
podman run \
    --rm \
    -it \
    --privileged \
    --ulimit=host \
    --ipc=host \
    --cgroups=disabled \
    --pids-limit -1 \
    --name llvm \
    --security-opt label=disable \
    --userns=keep-id \
    --hostname $(hostname) \
    --mount type=tmpfs,tmpfs-size=200G,destination=/build \
    llvm:latest bash
