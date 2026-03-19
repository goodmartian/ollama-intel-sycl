# vim: filetype=dockerfile

ARG FLAVOR=${TARGETARCH}
ARG PARALLEL=8

ARG CMAKEVERSION=3.31.2

# We require gcc v10 minimum.  v10.3 has regressions, so the rockylinux 8.5 AppStream has the latest compatible version
FROM --platform=linux/amd64 almalinux:8 AS base-amd64
RUN yum install -y yum-utils epel-release \
    && yum-config-manager --add-repo https://dl.rockylinux.org/vault/rocky/8.5/AppStream/\$basearch/os/ \
    && rpm --import https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-Rocky-8 \
    && dnf install -y yum-utils ccache gcc-toolset-10-gcc-10.2.1-8.2.el8 gcc-toolset-10-gcc-c++-10.2.1-8.2.el8 gcc-toolset-10-binutils-2.35-11.el8 \
    && dnf install -y ccache 
ENV PATH=/opt/rh/gcc-toolset-10/root/usr/bin:$PATH

FROM --platform=linux/arm64 almalinux:8 AS base-arm64
# install epel-release for ccache
RUN yum install -y yum-utils epel-release \
    && dnf install -y clang ccache 
ENV CC=clang CXX=clang++

FROM base-${TARGETARCH} AS base
ARG CMAKEVERSION
RUN curl -fsSL https://github.com/Kitware/CMake/releases/download/v${CMAKEVERSION}/cmake-${CMAKEVERSION}-linux-$(uname -m).tar.gz | tar xz -C /usr/local --strip-components 1
ENV LDFLAGS=-s

FROM base AS build
WORKDIR /go/src/github.com/ollama/ollama
COPY ollama/go.mod ollama/go.sum .
RUN curl -fsSL https://golang.org/dl/go$(awk '/^go/ { print $2 }' go.mod).linux-$(case $(uname -m) in x86_64) echo amd64 ;; aarch64) echo arm64 ;; esac).tar.gz | tar xz -C /usr/local
ENV PATH=/usr/local/go/bin:$PATH
RUN go mod download
COPY ollama/ .
ARG GOFLAGS="'-ldflags=-w -s'"
ENV CGO_ENABLED=1
ARG CGO_CFLAGS
ARG CGO_CXXFLAGS
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -trimpath -buildmode=pie -o /bin/ollama .

FROM base AS cpu
RUN dnf install -y gcc-toolset-11-gcc gcc-toolset-11-gcc-c++
ENV PATH=/opt/rh/gcc-toolset-11/root/usr/bin:$PATH
ARG PARALLEL
COPY CMakeLists.txt CMakePresets.json .
COPY ollama/ml/backend/ggml/ggml ml/backend/ggml/ggml
RUN --mount=type=cache,target=/root/.ccache \
    cmake --preset 'CPU' \
    && cmake --build --parallel ${PARALLEL} --preset 'CPU' \
    && cmake --install build --component CPU --strip --parallel ${PARALLEL}

FROM intel/oneapi-basekit:latest AS sycl-build
ARG CMAKEVERSION
RUN apt-get update \
    && apt-get install -y curl ccache patchelf \
    && curl -fsSL https://github.com/Kitware/CMake/releases/download/v${CMAKEVERSION}/cmake-${CMAKEVERSION}-linux-$(uname -m).tar.gz | tar xz -C /usr/local --strip-components 1
COPY CMakeLists.txt CMakePresets.json .
COPY ollama/ml/backend/ggml/ggml ml/backend/ggml/ggml
COPY ollama/llama/vendor/ggml/src/ggml-sycl ml/backend/ggml/ggml/src/ggml-sycl
# Add ggml_backend_score for DL plugin registration (required by load_best)
RUN printf '\nGGML_BACKEND_DL_SCORE_IMPL([]() -> int { return 100; })\n' >> ml/backend/ggml/ggml/src/ggml-sycl/ggml-sycl.cpp
ARG PARALLEL
RUN --mount=type=cache,target=/root/.ccache \
    cmake --preset 'SYCL_INTEL' \
    && cmake --build --parallel ${PARALLEL} --preset 'SYCL_INTEL' \
    && cmake --install build --component SYCL --strip --parallel ${PARALLEL}
# Copy Intel oneAPI runtime libraries required by libggml-sycl.so (based on ldd analysis)
# Essential libraries identified from ldd output
RUN mkdir -p /build/lib/ollama && \
    # Compiler runtime libraries (required)
    cp -L /opt/intel/oneapi/compiler/latest/lib/libsycl.so.8 /build/lib/ollama/ && \
    cp -L /opt/intel/oneapi/compiler/latest/lib/libimf.so /build/lib/ollama/ && \
    cp -L /opt/intel/oneapi/compiler/latest/lib/libsvml.so /build/lib/ollama/ && \
    cp -L /opt/intel/oneapi/compiler/latest/lib/libirng.so /build/lib/ollama/ && \
    cp -L /opt/intel/oneapi/compiler/latest/lib/libintlc.so.5 /build/lib/ollama/ && \
    cp -L /opt/intel/oneapi/compiler/latest/lib/libur_adapter_opencl.so.0 /build/lib/ollama/ && \
    cp -L /opt/intel/oneapi/compiler/latest/lib/libur_adapter_level_zero.so.0 /build/lib/ollama/ && \
    cp -L /opt/intel/oneapi/compiler/latest/lib/libur_loader.so.0 /build/lib/ollama/ && \
    cp -L /opt/intel/oneapi/compiler/latest/lib/libze_loader.so.1 /build/lib/ollama/ 2>/dev/null || true && \
    # DNNL (Deep Neural Network Library)
    cp -L /opt/intel/oneapi/dnnl/latest/lib/libdnnl.so.3 /build/lib/ollama/ && \
    # TBB (Threading Building Blocks)
    cp -L /opt/intel/oneapi/tbb/latest/lib/intel64/gcc4.8/libtbb.so.12 /build/lib/ollama/ && \
    # MKL libraries for BLAS support
    cp -L /opt/intel/oneapi/mkl/latest/lib/libmkl_sycl_blas.so.5 /build/lib/ollama/ && \
    cp -L /opt/intel/oneapi/mkl/latest/lib/libmkl_intel_ilp64.so.2 /build/lib/ollama/ && \
    cp -L /opt/intel/oneapi/mkl/latest/lib/libmkl_tbb_thread.so.2 /build/lib/ollama/ && \
    cp -L /opt/intel/oneapi/mkl/latest/lib/libmkl_core.so.2 /build/lib/ollama/ && \
    # Optional: Additional runtime libraries
    cp -L /opt/intel/oneapi/compiler/latest/lib/libhwloc.so.15 /build/lib/ollama/ 2>/dev/null || true && \
    cp -L /opt/intel/oneapi/compiler/latest/lib/libiomp5.so /build/lib/ollama/ 2>/dev/null || true && \
    cp -L /opt/intel/oneapi/umf/latest/lib/libumf.so.1 /build/lib/ollama/ 2>/dev/null || true
# Set RPATH to $ORIGIN so libraries are found in the same directory
RUN for lib in /build/lib/ollama/*.so*; do \
    if [ -f "$lib" ] && [ ! -L "$lib" ]; then \
    patchelf --set-rpath '$ORIGIN' "$lib" 2>/dev/null || true; \
    fi; \
    done

FROM --platform=linux/amd64 scratch AS amd64
COPY --from=cpu dist/lib/ollama /lib/ollama/
COPY --from=sycl-build /build/lib/ollama /lib/ollama/
COPY --from=build /bin/ollama /bin/ollama

FROM --platform=linux/arm64 scratch AS arm64
COPY --from=cpu dist/lib/ollama /lib/ollama/
COPY --from=sycl-build /build/lib/ollama /lib/ollama/
COPY --from=build /bin/ollama /bin/ollama

FROM ${TARGETARCH} AS archive
ARG FLAVOR

FROM ubuntu:24.04
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        ocl-icd-libopencl1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
COPY --from=archive /bin /usr/bin
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
COPY --from=archive /lib/ollama /usr/lib/ollama
ENV LD_LIBRARY_PATH=/usr/lib/ollama
ENV OLLAMA_HOST=0.0.0.0:11434
EXPOSE 11434
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["serve"]
