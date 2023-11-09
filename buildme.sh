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
    --hostname $(hostname) \
    llvm:latest bash
