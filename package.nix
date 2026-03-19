{
  lib,
  stdenv,
  autoPatchelfHook,
  makeWrapper,
  addDriverRunpath,
  intel-compute-runtime,
  intel-gmmlib,
  ocl-icd,
  src,
}:
stdenv.mkDerivation {
  pname = "ollama-sycl";
  version = "0.18.2";

  inherit src;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [stdenv.cc.cc.lib];

  # Bundled oneAPI SYCL runtime libs — not in nixpkgs
  autoPatchelfIgnoreMissingDeps = ["*"];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/ollama
    cp bin/ollama $out/bin/
    cp lib/ollama/* $out/lib/ollama/

    # ggml load_best() requires libggml-<name>-<variant>.so pattern
    ln -sf libggml-sycl.so $out/lib/ollama/libggml-sycl-intel.so

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/ollama \
      --suffix LD_LIBRARY_PATH : "$out/lib/ollama" \
      --suffix LD_LIBRARY_PATH : "${addDriverRunpath.driverLink}/lib" \
      --suffix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
        intel-compute-runtime.drivers
        intel-gmmlib
        ocl-icd
        stdenv.cc.cc.lib
      ]}" \
      --suffix LD_LIBRARY_PATH : "/run/current-system/sw/share/nix-ld/lib" \
      --set OCL_ICD_VENDORS "${addDriverRunpath.driverLink}/etc/OpenCL/vendors" \
      --set ZES_ENABLE_SYSMAN "1"
  '';

  meta = {
    description = "Ollama with Intel SYCL backend for Arc GPUs";
    homepage = "https://github.com/goodmartian/ollama-intel-sycl";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux"];
    mainProgram = "ollama";
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
