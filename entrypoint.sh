#!/bin/bash
# Docker entrypoint: setup Intel GPU driver symlinks before starting Ollama
# Required only for Docker deployment (NixOS native uses LD_LIBRARY_PATH instead)

if [ -f /run/opengl-driver-drivers/lib/libze_intel_gpu.so.1 ]; then
    ln -sf /run/opengl-driver-drivers/lib/libze_intel_gpu.so.1 /usr/lib/ollama/libze_intel_gpu.so.1
    echo "entrypoint: linked libze_intel_gpu.so.1 from host"
else
    echo "entrypoint: WARNING - libze_intel_gpu.so.1 not found (GPU may not be detected)"
fi

exec /usr/bin/ollama "$@"
