# Ollama for Intel GPU (SYCL)

Fork of [0deep/ollama-for-intel-gpu](https://github.com/0deep/ollama-for-intel-gpu) with fixes that make the SYCL backend actually work.

## What this fixes

Upstream builds `libggml-sycl.so` but Ollama never loads it because:

1. `ggml_backend_score` symbol is missing — `load_best()` silently skips the library
2. `GGML_BACKEND_DL` not set in CMake SYCL preset — library compiles without plugin registration
3. `libur_adapter_level_zero.so.0` not bundled — SYCL can't talk to the GPU via Level Zero

This fork adds one line to `ggml-sycl.cpp`, two lines to `CMakePresets.json`, and bundles the missing library.

## Install

### Docker

```bash
git clone --recursive https://github.com/goodmartian/ollama-intel-sycl.git
cd ollama-intel-sycl
./scripts/patch.sh
docker compose up -d
```

### NixOS

```nix
# flake.nix
inputs.ollama-sycl.url = "github:goodmartian/ollama-intel-sycl";

# configuration.nix
imports = [ inputs.ollama-sycl.nixosModules.default ];
services.ollama-sycl.enable = true;
```

You need `intel-compute-runtime` in `hardware.graphics.extraPackages`.

### Binary

Grab the tarball from [Releases](../../releases):

```bash
tar xzf ollama-sycl-linux-amd64.tar.gz
LD_LIBRARY_PATH="./lib/ollama" ./bin/ollama serve
```

## Build

Requires Docker.

```bash
git clone --recursive https://github.com/goodmartian/ollama-intel-sycl.git
cd ollama-intel-sycl
./scripts/patch.sh
./update.sh
```

Output goes to `dist/`.

## NixOS module options

```nix
services.ollama-sycl = {
  enable = true;
  host = "127.0.0.1";       # default
  port = 11434;              # default
  home = "/var/lib/ollama";  # default
  openFirewall = false;      # default
  environmentVariables = {}; # extra env vars
};
```

## Known issues

- Flash attention produces garbage on Arrow Lake Xe2 iGPU — disabled by default (`OLLAMA_FLASH_ATTENTION=0`)
- K-quants (Q4_K_M etc.) crash or run 45% slower than Q4_0 on Xe2 — use Q4_0
- Vulkan backend gives wrong output on Arrow Lake for models >3B — use SYCL

## Tested on

- ASUS Zenbook 14, Intel Core Ultra 9 285H, Arc Pro 130T/140T iGPU
- NixOS unstable, kernel 6.19.6
- Ollama 0.18.2, oneAPI 2025.3

Token generation: ~35-45 t/s (qwen2.5:0.5b, Q4_0).

## License

MIT, same as [Ollama](https://github.com/ollama/ollama/blob/main/LICENSE).
