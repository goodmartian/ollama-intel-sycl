#!/bin/bash
# Update Ollama SYCL build from upstream
# Usage: ./update.sh && sudo nixos-rebuild switch
set -euo pipefail

cd "$(dirname "$0")"

echo "=== Updating ollama submodule ==="
cd ollama && git fetch --tags && git checkout "$(git describe --tags --abbrev=0 origin/main)" && cd ..

echo "=== Applying patches ==="
./scripts/patch.sh

echo "=== Extracting dist ==="
. ollama/scripts/env.sh
rm -rf dist && mkdir -p dist

docker buildx build \
  --output type=local,dest=./dist/ \
  --platform=linux/amd64 \
  ${OLLAMA_COMMON_BUILD_ARGS} \
  --target archive \
  -f Dockerfile .

# Symlink for load_best pattern matching
ln -sf libggml-sycl.so dist/lib/ollama/libggml-sycl-intel.so

echo ""
echo "=== Done! Ollama $VERSION built ==="
echo "Run: sudo nixos-rebuild switch"
