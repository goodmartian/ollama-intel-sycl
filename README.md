# Ollama for Intel GPU

Custom build of [Ollama](https://github.com/ollama/ollama) with optimized support for Intel GPUs using SYCL backend.

## Supported Models

This build is fully compatible with **Ollama v0.17.7** and supports:

- **GPT-OSS 20B** - Open-source GPT model
- **Qwen3 Series** - Supports the newest Qwen3.5 models
- **Ministral-3** - Mistral AI's latest compact model
- **LFM-2 Series** - Liquid AI's high-performance compact model
- **And most models supported by Ollama** - All models compatible with standard Ollama will work with this Intel GPU-optimized build

## Integrations

- **OpenClaw** - Supports [OpenClaw](https://docs.ollama.com/integrations/openclaw) for agentic tool use, TUI interface, and messaging app connections.


## Version Information

- **Ollama Base Version**: v0.17.7 (commit: `9b0c7cc7`)
- **Supported Backends**: CPU (multi-variant), SYCL (Intel GPU)

## Features

- ✅ **Intel GPU Support**: Full SYCL backend integration for Intel Arc, Iris Xe, and integrated GPUs
- ✅ **Intel oneAPI Integration**: Leverages Intel oneDNN, MKL, and TBB for optimized performance
- ✅ **F16 & DNN Acceleration**: Enabled SYCL F16 and DNN optimizations for faster inference
- ✅ **Multi-Architecture CPU Support**: Includes optimized variants (x64, SSE4.2, AVX, AVX2, AVX512, AVX-VNNI)
- ✅ **Docker Build**: Containerized build process for reproducible builds

## Prerequisites

### Build Requirements

- **Docker** or **Podman** (for containerized builds)
- **Git** with submodule support
- **Intel oneAPI Base Toolkit** (included in Docker image)

### Runtime Requirements

- **Intel GPU Drivers**: 
  - Linux: Intel Compute Runtime for OpenCL
  - Minimum driver version: See [Intel GPU documentation](https://www.intel.com/content/www/us/en/developer/articles/tool/oneapi-standalone-components.html)
- **Ubuntu 24.04** or compatible Linux distribution (for final Docker image)

## Project Structure

```
ollama-for-intel-gpu/
├── CMakeLists.txt              # Main CMake configuration
├── CMakePresets.json           # CMake presets for CPU and SYCL builds
├── Dockerfile                  # Multi-stage Docker build
├── Dockerfile.patcher          # Patcher environment
├── Makefile.sync               # Sync and patch logic
├── README.md                   # This file
├── scripts/
│   ├── build_linux.sh          # Linux build script
│   └── patch.sh                # Patch & Sync backend update script
├── patches/                    # Custom .patch files
└── ollama/                     # Ollama submodule (don't edit directly!)
```

## Building

### Using the Build Script

```bash
# Clone the repository with submodules
git clone --recursive https://github.com/your-repo/ollama-for-intel-gpu.git
cd ollama-for-intel-gpu

# Apply patches and sync (Required before building)
./scripts/patch.sh

# Build using Podman/Docker
./scripts/build_linux.sh
```

## Patch Management

This project uses a patch-based workflow to maintain custom changes without directly modifying submodules. **Do not edit files in `ollama/` directly.**

### Applying Patches

To apply all registered patches and sync the source code:

```bash
./scripts/patch.sh
```

### Creating New Patches

1.  Modify code in `ollama/` for testing.
2.  Generate a patch file using `git diff`:
    ```bash
    git -C ollama/ vendor/ > patches/your-fix.patch
    ```
3.  Register the patch in `Makefile.sync`.
4.  Run `./scripts/patch.sh` to verify and sync.

> [!IMPORTANT]
> Any direct changes to submodules will be overwritten when running the sync process. Always use `.patch` files for permanent changes.

### Build Output

The build process creates:
- `dist/bin/ollama` - Ollama binary
- `dist/lib/ollama/` - Shared libraries including:
  - `libggml-sycl.so` - SYCL backend
  - `libggml-base.so` - Base GGML library
  - CPU variant libraries (alderlake, haswell, skylakex, etc.)
  - Intel oneAPI runtime libraries

### Docker Build Process

The build uses a multi-stage Dockerfile:

1. **base-amd64/arm64**: Base image with GCC toolset
2. **build**: Compiles Ollama Go binary
3. **cpu**: Builds CPU backend with GCC 11
4. **sycl-build**: Builds SYCL backend with Intel oneAPI compilers (icx/icpx)
5. **Final image**: Ubuntu 24.04 with all binaries and libraries

## Usage

### Running Ollama

```bash
# Start the Ollama server
./dist/bin/ollama serve

# In another terminal, list available models
./dist/bin/ollama list

# Run a model
./dist/bin/ollama run hf.co/unsloth/gpt-oss-20b-GGUF:latest
```

### Environment Variables

- `LD_LIBRARY_PATH`: Set to `/usr/lib/ollama` in Docker (automatically configured)
- `OLLAMA_HOST`: Server host and port (default: `0.0.0.0:11434`)

### GPU Detection

The SYCL backend will automatically detect available Intel GPUs. You can verify GPU usage by checking the Ollama server logs during model loading.

## CMake Presets

### CPU Preset
```bash
cmake --preset 'CPU'
cmake --build --preset 'CPU'
```

### SYCL_INTEL Preset
```bash
cmake --preset 'SYCL_INTEL'
cmake --build --preset 'SYCL_INTEL'
```

Configuration:
- Compiler: Intel oneAPI icx/icpx
- SYCL Target: INTEL
- DNN: Enabled (oneDNN)
- F16: Enabled (half-precision)

## Updating GGML SYCL Backend

To update the GGML SYCL backend to the latest version from [llama.cpp](https://github.com/ggml-org/llama.cpp):

```bash
# Run the update script
python3 scripts/update_ggml_sycl.py
```

This script will:
- Fetch the latest SYCL backend code from llama.cpp master branch
- Compare SHA hashes to detect changes
- Backup existing files before updating
- Download and install updated files
- Provide a detailed report of changes

**Note**: After updating, rebuild the project to incorporate the changes:
```bash
./scripts/build_linux.sh
```


## Removed Features

The following features have been removed from this build:

- ❌ **Vulkan Backend**: Removed to focus on SYCL optimization

## Troubleshooting

### Library Not Found Errors

If you encounter library loading errors:
```bash
# Check library dependencies
ldd dist/lib/ollama/libggml-sycl.so

# Verify Intel oneAPI runtime libraries are present
ls -la dist/lib/ollama/*.so*
```

### GPU Not Detected

1. Verify Intel GPU drivers are installed:
   ```bash
   clinfo  # Check OpenCL devices
   ```

2. Check Ollama server logs for SYCL initialization messages

3. Ensure the `LD_LIBRARY_PATH` includes oneAPI runtime libraries

## Contributing

Contributions are welcome! Please ensure:
- All builds pass successfully
- SYCL backend tests are run on Intel GPU hardware
- Documentation is updated for any new features

## License

This project inherits the license from the upstream [Ollama project](https://github.com/ollama/ollama).

## Acknowledgments

- [Ollama](https://github.com/ollama/ollama) - Original project
- [Intel oneAPI](https://www.intel.com/content/www/us/en/developer/tools/oneapi/overview.html) - SYCL toolkit and libraries
- [GGML](https://github.com/ggerganov/ggml) - Machine learning tensor library

## References

- [Intel GPU Drivers](https://www.intel.com/content/www/us/en/developer/articles/tool/intel-graphics-compute-runtime-for-opencl-driver.html)
- [oneAPI Documentation](https://www.intel.com/content/www/us/en/docs/oneapi/programming-guide/current/overview.html)
- [SYCL Specification](https://www.khronos.org/sycl/)
